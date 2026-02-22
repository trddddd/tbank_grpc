# Configuration

Конфигурация задаётся через `TbankGrpc.configure` или при создании клиента.

## Поля конфигурации

- `token` — API-токен (обязателен)
- `app_name` — имя приложения (обязательно)
- `sandbox` — `true` для песочницы
- `endpoint` — явный адрес `host:port` (nil = авто по sandbox: production или sandbox)
- `timeout` — таймаут запросов (сек)
- `thread_pool_size` — размер worker-пула для callback в stream event loop
- `stream_metrics_enabled` — включить сбор stream-метрик (`false` по умолчанию)
- `retry_attempts` — число повторных попыток
- `enable_retries` — включение gRPC retry policy для unary RPC
- `log_level` — уровень логов (`:debug`, `:info`, `:warn`, `:error`), по умолчанию stdlib Logger в $stdout
- `cert_path` — путь к SSL-сертификату (nil = системные)
- `channel_pool_size` — размер пула каналов
- `deadline_overrides` — переопределение дедлайнов по service/method
- `stream_idle_timeout` — порог «тишины» (сек): если дольше не было событий по стриму, watchdog инициирует reconnect. `nil` — watchdog не запускается.
- `stream_watchdog_interval_sec` — период проверки watchdog (сек). По умолчанию 5.
- keepalive/connection: `keepalive_time_ms`, `keepalive_timeout_ms`, `max_connection_idle_ms`, `max_connection_age_ms` — см. [Переподключение и keepalive](#переподключение-и-keepalive).

## Пример

```ruby
TbankGrpc.configure do |config|
  config.token = ENV["TBANK_TOKEN"]
  config.app_name = "trddddd.tbank_grpc"
  config.sandbox = false
  config.timeout = 30
  config.retry_attempts = 3
  config.log_level = :info
  config.thread_pool_size = 8
  config.stream_metrics_enabled = true
  config.stream_idle_timeout = 25
  config.stream_watchdog_interval_sec = 5
  config.deadline_overrides = {
    # Для stream RPC по умолчанию deadline не выставляется.
    # При необходимости можно задать вручную:
    "MarketDataStreamService/MarketDataStream" => 600,
    "MarketDataStreamService/MarketDataServerSideStream" => 600
  }
end
```

## Endpoints

По умолчанию (при `config.endpoint == nil`):
- С TLS (серты T-Bank): production `invest-public-api.tbank.ru:443`, sandbox `sandbox-invest-public-api.tbank.ru:443`
- В режиме `insecure: true`: production `invest-public-api.tinkoff.ru:443`, sandbox `sandbox-invest-public-api.tinkoff.ru:443`

Переключение по `config.sandbox`. Явный `config.endpoint` перекрывает выбор (например `localhost:50051`). Формат: `host:port`.

## Deadline Overrides и стриминг

`deadline_overrides` поддерживает ключи:
- полное имя метода: `"Service/Method"`
- имя сервиса: `"Service"`

Примеры:
- `"InstrumentsService/GetInstrumentBy"` — точечный override
- `"InstrumentsService"` — общий override для сервиса

Для `MarketDataStreamService` (bidirectional и server-side stream) в текущей реализации дедлайн **не задаётся автоматически**.
Дедлайн будет применён только если явно указан в `deadline_overrides` для:
- `"MarketDataStreamService/MarketDataStream"`
- `"MarketDataStreamService/MarketDataServerSideStream"`

## Переподключение и keepalive

При разрыве сети стрим переподключается автоматически. Скорость обнаружения обрыва зависит от двух механизмов:

1. **Watchdog** — если дольше `stream_idle_timeout` секунд не было ни одного события (в т.ч. ping), выполняется `force_reconnect`. Проверка раз в `stream_watchdog_interval_sec` сек. Дефолты в коде канала: при заданном `stream_idle_timeout` часто используют 25 и 5 сек — в худшем случае до переподключения ~30 сек.
2. **gRPC keepalive** — клиент периодически шлёт TCP keepalive; при мёртвом соединении следующий keepalive падает с ошибкой, gRPC возвращает `UNAVAILABLE`, цикл listen делает reconnect. В геме по умолчанию: `keepalive_time_ms = 60_000` (раз в 60 сек), `keepalive_timeout_ms = 10_000`.

Примечание: `ChannelManager#reset` всегда глобален для конкретного экземпляра manager. В текущем `Client` stream-сервисы получают выделенные экземпляры `ChannelManager`, чтобы reconnect одного стрима не закрывал каналы unary-сервисов и других stream-сервисов.

Чтобы переподключение происходило быстрее (порядка 5–15 сек):

```ruby
TbankGrpc.configure do |c|
  # Быстрее считать «тишину» обрывом (убедитесь, что ping по стриму не реже этого интервала)
  c.stream_idle_timeout = 10
  c.stream_watchdog_interval_sec = 2

  # Чаще слать keepalive — раньше обнаружится мёртвое соединение
  c.keepalive_time_ms = 5_000      # пинг каждые 5 сек (дефолт в геме 60_000)
  c.keepalive_timeout_ms = 2_000  # считать обрыв, если за 2 сек нет ответа
end
```

Подробнее: [Market Data Streaming — Reconnect и Watchdog](market_data_streaming.md#reconnect-и-watchdog).

## Метрики стриминга

По умолчанию сбор stream-метрик отключён (`stream_metrics_enabled = false`).

- `client.stream_metrics` и `client.stream_event_stats(...)` всегда возвращают Hash стабильного формата.
- При отключённых метриках возвращается zero-shape: те же ключи, но нулевые/пустые значения.
