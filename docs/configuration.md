# Configuration

Конфигурация задаётся через `TbankGrpc.configure` или при создании клиента.

## Поля конфигурации

- `token` — API-токен (обязателен)
- `app_name` — имя приложения (обязательно)
- `sandbox` — `true` для песочницы
- `endpoint` — явный адрес `host:port` (nil = авто по sandbox: production или sandbox)
- `timeout` — таймаут запросов (сек)
- `retry_attempts` — число повторных попыток
- `log_level` — уровень логов (`:debug`, `:info`, `:warn`, `:error`), по умолчанию stdlib Logger в $stdout
- `cert_path` — путь к SSL-сертификату (nil = системные)
- `channel_pool_size` — размер пула каналов
- keepalive/connection: `keepalive_time_ms`, `keepalive_timeout_ms`, `min_time_between_pings_ms`, `max_connection_idle_ms`, `max_connection_age_ms`, `client_idle_timeout_ms`

## Пример

```ruby
TbankGrpc.configure do |config|
  config.token = ENV["TBANK_TOKEN"]
  config.app_name = "my_app"
  config.sandbox = false
  config.timeout = 30
  config.retry_attempts = 3
  config.log_level = :info
end
```

## Endpoints

По умолчанию (при `config.endpoint == nil`):
- Production: `invest-public-api.tbank.ru:443`
- Sandbox: `sandbox-invest-public-api.tbank.ru:443`

Переключение по `config.sandbox`. Явный `config.endpoint` перекрывает выбор (например `localhost:50051` или legacy `invest-public-api.tinkoff.ru:443`). Формат: `host:port`.
