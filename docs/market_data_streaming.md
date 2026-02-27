# Market Data Streaming

Единая документация по стримингу рыночных данных в `tbank_grpc`: публичный API, рабочие сценарии, ограничения и важные нюансы поведения.

## Источники истины

- Proto: `proto/marketdata.proto`
- T-Bank docs:
  - <https://developer.tbank.ru/invest/services/quotes/head-marketdata>
  - <https://developer.tbank.ru/invest/services/quotes/marketdata>
  - <https://developer.tbank.ru/invest/services/quotes/faq_marketdata>
  - <https://developer.tbank.ru/invest/services/quotes/limits>

## Режимы стриминга

Есть два режима:

- **Bidirectional (`MarketDataStream`)**
  - долгоживущее соединение;
  - можно динамически делать `subscribe_*`, `unsubscribe_*`, `send_ping`, `my_subscriptions`;
  - есть reconnect, watchdog и восстановление подписок.
- **Server-side (`MarketDataServerSideStream`)**
  - одноразовый stream по параметрам одного запроса;
  - без reconnect и runtime-управления подписками;
  - удобен для простого чтения потока «запросил и слушаешь».

## Публичный API

Через клиент:

- `client.market_data_stream`
- `client.stream_orderbook`
- `client.stream_candles`
- `client.stream_trades`
- `client.stream_info`
- `client.stream_last_price`
- `client.listen_to_stream_async`
- `client.listen_to_stream`
- `client.stop_stream`
- `client.stream_metrics`
- `client.stream_event_stats(event_type)`

Через сервис `client.market_data_stream`:

- подписки/отписки: `subscribe_orderbook`, `subscribe_candles`, `subscribe_trades`, `subscribe_info`, `subscribe_last_price` и соответствующие `unsubscribe_*`
- `my_subscriptions` (`get_my_subscriptions` — alias)
- `send_ping`, `set_ping_delay`
- `listen`, `listen_async`, `stop_async`, `stop`, `force_reconnect`
- `on(event_type, as: :proto | :model | nil, &block)`
- `market_data_server_side_stream(as: :proto | :model, **subscription_params, &block)` — параметры: `candles:`, `orderbooks:`, `trades:`, `info:`, `last_prices:` (массивы параметров подписок), опционально `ping_delay_ms:`
- `stats`, `metrics`, `event_stats(event_type)`
- `current_subscriptions`

## Callback payload: `:proto` vs `:model`

По умолчанию (`as:` не указан):

- `:model` для `:candle`, `:orderbook`, `:trade`, `:trading_status`, `:last_price`, `:open_interest`
- `:proto` для `:ping`, `:subscription_status`

`as: :proto`:

- поддерживается для всех событий

`as: :model`:

- поддерживается только для `:candle`, `:orderbook`, `:trade`, `:trading_status`, `:last_price`, `:open_interest`
- `on(:ping, as: :model)` и `on(:subscription_status, as: :model)` выбрасывают `InvalidArgumentError`

Нюанс server-side режима с `as: :model`:

- `ping` и `subscription_status` не конвертируются в модель и пропускаются
- это штатное поведение, не ошибка

## GetMySubscriptions и контроль активности

Запрос активных подписок делается через `my_subscriptions` (или `get_my_subscriptions`) и обрабатывается асинхронно в `on(:subscription_status, as: :proto)`.

Рекомендуемый цикл контроля:

1. Храните локальное состояние подписок (`current_subscriptions` или свой storage).
2. Периодически отправляйте `my_subscriptions`.
3. Сравнивайте ответ сервера с локальным состоянием.
4. При расхождениях дозапрашивайте недостающие подписки; если активных подписок не видно совсем, перезапускайте stream и восстанавливайте подписки из локального состояния.

## Лимиты и guard-правила

- лимит подписок: `300` на соединение
- лимит мутаций подписок: `100` запросов в минуту

Идемпотентность:

- повторный `subscribe_*` с теми же параметрами — no-op (лишний запрос не отправляется)
- `unsubscribe_*` для отсутствующей подписки — no-op
- при старте stream дубли подписок отсеиваются

Нюанс:

- `info` не учитывается в клиентском лимите `300`
- если сервер вернул `SUBSCRIPTION_STATUS_LIMIT_IS_EXCEEDED`, обрабатывайте это в `:subscription_status`

## Reconnect и watchdog (bidirectional)

**Явный `client.reconnect`.** Если вызывается `client.reconnect` (например после `client.close`), клиент останавливает активный market_data stream, закрывает каналы и обнуляет кэш сервисов (`@market_data_stream = nil`). Активные итерации по стриму (listen/listen_async) при этом обрываются — канал закрыт. После reconnect нужно заново подписаться и запустить стрим (`subscribe_*` + `listen` / `listen_async`). Внутренний reconnect (ниже) этого не делает — там переподключается тот же экземпляр сервиса.

- stream работает циклом `listen`
- при транспортных ошибках выполняется reconnect
- стратегия: exponential backoff + jitter (`0.5..1.5`), по умолчанию до 5 попыток подряд
- активные подписки хранятся и отправляются заново после reconnect

Watchdog:

- следит за `last_event_at` (включая ping)
- при idle дольше `stream_idle_timeout` вызывает `force_reconnect`
- проверяет idle раз в `stream_watchdog_interval_sec`
- `force_reconnect` вызывает `ChannelManager#reset`; сервис не останавливается, listen-цикл сам переподключается

Важно:

- `GRPC::PermissionDenied` и `GRPC::Unauthenticated` не ведут к reconnect — stream останавливается
- при превышении лимита попыток reconnect из `listen` выбрасывается `TbankGrpc::Streaming::Core::Runtime::ReconnectionError`

## Как ускорить обнаружение обрыва

Время реакции обычно определяется тремя факторами:

1. `stream_idle_timeout`
2. `stream_watchdog_interval_sec`
3. gRPC keepalive (`keepalive_time_ms`, `keepalive_timeout_ms`)

Чтобы reconnect происходил быстрее:

- уменьшите `stream_idle_timeout` (например, 10 или 5 сек)
- уменьшите `stream_watchdog_interval_sec` (например, 2 сек)
- уменьшите keepalive-параметры (например, `keepalive_time_ms: 5000`, `keepalive_timeout_ms: 2000`)
- убедитесь, что ping по стриму приходит не реже выбранного `stream_idle_timeout` (`set_ping_delay`)

См. [Configuration — Переподключение и keepalive](configuration.md#переподключение-и-keepalive).

## Ошибки и повторные попытки

В listen loop:

- `GRPC::Unavailable`, `GRPC::DeadlineExceeded`, `GRPC::Internal` -> reconnect
- `GRPC::ResourceExhausted` -> краткая пауза и reconnect
- `GRPC::Cancelled` -> reconnect/завершение по состоянию цикла
- `GRPC::PermissionDenied`, `GRPC::Unauthenticated` -> остановка stream

После auth-ошибок:

- обновите токен/конфиг
- запустите listen заново

## Deadline для stream RPC

По умолчанию deadline берётся из `Grpc::DeadlineResolver::DEFAULT_DEADLINES`: для `MarketDataStreamService` — 90 сек (для `MarketDataStream` и `MarketDataServerSideStream`). Переопределить можно через `config.deadline_overrides` (ключ — `"MarketDataStreamService/MarketDataStream"` или `"MarketDataStreamService/MarketDataServerSideStream"`, значение — секунды).

## Метрики и диагностика

- `client.stream_metrics` возвращает снимок: `metrics`, `subscriptions`, `reconnects`, `last_event_at`, `listening`, `async_status`
- `client.stream_event_stats(event_type)` возвращает статистику по типу события
- latency считается end-to-end: от постановки события в очередь до завершения callback
- включение: `stream_metrics_enabled` (по умолчанию `false`)
- при выключенных метриках используется тот же `Metrics` с `enabled: false`; контракт ответа стабилен (нулевые/пустые значения)

## EventLoop: генерации и остановка

- **Одна активная генерация.** При `start()` создаётся рантайм с очередями и пулом воркеров. Повторный `start()` без `stop()` возвращает тот же поток; новая генерация — только после `stop()` и следующего `start()`.

- **Остановка по сигналу.** В `stop()` в очередь кладётся `STOP_SIGNAL`; потоки выходят из цикла при его получении. Ожидание завершения потоков ограничено таймаутом (по умолчанию 5 сек); при превышении остановка считается выполненной, но «зависшие» потоки могут ещё работать.
- **Зачем generation.** Номер эпохи (`generation`) нужен, чтобы потоки от предыдущего запуска (например, не успевшие выйти по таймауту) не обрабатывали события и не писали в очереди нового рантайма. При рестарте в середине `process_event` проверка `runtime_active?(generation)` прерывает цикл — оставшиеся колбеки по этому событию не ставятся в очередь.
- **Потери при stop/start (в т.ч. reconnect).** Очереди не дренируются: события, оставшиеся в главной очереди после вставки `STOP_SIGNAL`, не обрабатываются; часть колбеков по одному событию может не выполниться, если воркеры получат `STOP_SIGNAL` раньше своих задач.

**Почему drain не реализован?** В проде обычно используют Bidirectional для живых дашбордов и ботов, Server-side — для простых или разовых сценариев; обычный stop достаточен, drain имеет смысл только если явно нужна гарантия «ни одного потерянного события» при остановке. Пока лично в таком требовании не нуждался :)

## Ключевые нюансы, которые часто путают

- После **`client.reconnect`** market_data stream обнуляется; активный listen обрывается — подписки и listen нужно запускать заново (см. раздел «Reconnect и watchdog»).
- В bidirectional режиме запросы подписок и `my_subscriptions` уходят через внутреннюю очередь: это асинхронная отправка, не мгновенный RPC-ответ.
- В `stats[:reconnects]` учитываются попытки reconnect в listen-цикле; это не то же самое, что «число успешных переподключений».
- `EventLoop` выполняет callback'и в пуле потоков: порядок завершения callback'ов не гарантирован.
- При медленных callback'ах очередь может расти; это видно по `queue_depth`/`worker_queue_depth` в метриках.
- При reconnect (stop/start loop) возможна потеря части событий, уже попавших в очереди EventLoop; см. раздел «EventLoop: генерации и остановка».
- Для server-side stream подписки задаются одним вызовом с ключами `candles:`, `orderbooks:`, `trades:`, `info:`, `last_prices:` (каждый — массив хешей с параметрами). По всему запросу общие поля `waiting_close`, `candle_source_type`, `trade_source`, `with_open_interest` — смешивать разные значения внутри одного запроса нельзя, иначе `InvalidArgumentError`.
- Для стримов используется отдельный `ChannelManager` относительно unary API, поэтому reconnect стрима не должен сбрасывать обычные unary-вызовы.
