# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.3] - 2026-02-27

### Added
- Ленивая константа `TbankGrpc::CONTRACT_V1` — единая точка входа к модулю контракта API (proto)
- `Streaming::Operations::Responses::ResponseConverter` — конвертация ответов операционных стримов (portfolio/positions/operations) в доменные модели
- `ModelMapper#convert_response(response, format:)` — унифицированный метод конвертации для market data server-side stream
- Стриминг операций: `OperationsStreamService`, `Streaming::Operations::ServerStreamService`, фасад в `Client`
- Модели стрима операций: `Models::Operations::OperationData`, `Models::Operations::PositionData`
- `Money.from_grpc_or_zero(proto, default_currency)` — возвращает Money из proto или нулевую сумму в заданной валюте при отсутствии proto

### Changed
- Базовые streaming-классы и market_data server/bidi — доработки для переиспользования в operations stream
- Убрано дублирование `type_module`: метод удалён из базовых стрим-классов, везде используется `TbankGrpc::CONTRACT_V1` напрямую
- `Operations::ServerStreamService` — логика конвертации вынесена из сервиса в `ResponseConverter`; `converter:` теперь лямбда через `@response_converter`
- `MarketData::ServerStreamService` — `converter:` переключён на `@model_mapper.convert_response`; метод `convert_response` удалён из `RequestBuilder` (SRP)

## [0.2.2] - 2026-02-27

### Added
- **OperationsService** (unary): портфель, позиции, операции (`Client#operations`) — GetPortfolio, GetPositions, GetOperations, GetOperationsByCursor
- Модели операций: `Models::Operations::Portfolio`, `PortfolioPosition`, `Positions`
- Модель `Models::Operations::Operation` для операций (GetOperations): id, type, state, date, payment, price, trades и др.

### Changed
- Клиент: фасад `Client#operations` для OperationsService
- Документация: README, market_data_streaming
- Money: доработки value object при использовании в операциях

## [0.2.1] - 2026-02-26

### Added
- Example bot `liquidity_analyzer` — анализ ликвидности по стакану (orderbook streaming, отчёт, CLI)

## [0.2.0] - 2026-02-22

### Added
- `Grpc::MethodName.full_name(stub, rpc_method)` — модуль в `grpc/method_name.rb` для формирования строки "ServiceName/MethodName" из gRPC stub и имени метода (deadline, логи, rate limit)
- `Normalizers::AccountIdNormalizer` — normalize_single / normalize_list (strip, required, uniq); используется в UsersService#get_margin_attributes
- `Normalizers::TickerNormalizer` — normalize(value) → to_s.strip.upcase; используется в InstrumentClassMethods и InstrumentsHelper
- `Normalizers::StreamNameNormalizer` — normalize(value, default: 'stream'); используется в ListenLoop
- `Normalizers::PayloadFormatNormalizer` — normalize(format) → :proto или :model; используется в BaseServerStreamService
- `Converters::UnitsNano` — общая схема units + nano/1e9 (to_f, to_decimal, from_decimal); Quotation и Money делегируют ему числовые преобразования
- Новый streaming API: `MarketDataStreamService` (bidirectional + server-side) и фасадные методы в `Client` (`stream_orderbook`, `stream_candles`, `stream_trades`, `stream_info`, `stream_last_price`, `listen_to_stream*`, `stream_metrics`)
- Новая инфраструктура стриминга: `Streaming::Core::Dispatch::EventLoop`, `Runtime::{AsyncListener, ReconnectionStrategy, StreamWatchdog}`, `Session::ListenLoop`, `Observability::Metrics`
- Новый слой подписок/роутинга: `Streaming::MarketData::Subscriptions::{Manager, Registry, MutationLimiter, ParamsNormalizer, RequestFactory}` и `Responses::{EventRouter, ModelMapper}`
- Новые модели рыночного стриминга: `Models::MarketData::{Trade, TradingStatus, OpenInterest}`
- Базовые классы по типам RPC: `Services::Unary::BaseUnaryService`, `Services::Streaming::{BaseBidiStreamService, BaseServerStreamService}`
- Конвертер `Converters::CandleInterval` (канонизация алиасов, включая `CANDLE_INTERVAL_1_HOUR`)
- Документация по стримингу: `docs/market_data_streaming.md`, расширения в `README.md` и `docs/configuration.md`
- Большой пакет тестов для streaming-слоя, `MarketDataStreamService`, `OrderBook` и `Instrument`

### Changed
- Streaming: полное имя RPC для дедлайна выводится из stub + rpc_method; константы и параметр `method_full_name` убраны; в обоих базах добавлен fallback на `Grpc::DeadlineResolver::DEFAULT_DEADLINES` по имени сервиса; unary и streaming используют `Grpc::MethodName.full_name` вместо дублирования логики
- **Breaking:** `DeadlineResolver` и `TrackingId` перенесены в слой `grpc/`: теперь `TbankGrpc::Grpc::DeadlineResolver` и `TbankGrpc::Grpc::TrackingId`; старые пути удалены
- `Converters::Money.to_decimal` задокументирован как публичный API (BigDecimal для точных расчётов)
- Quotation и Money используют UnitsNano для to_f/to_decimal/decimal_to_pb, остаются только обёртки и тип proto
- Извлечение tracking_id унифицировано: ErrorHandler и Interceptors::Logging используют `TrackingId.extract`; дублирующий ErrorHandler.extract_tracking_id удалён
- **Breaking:** версия Ruby повышена до `>= 3.2.0` (`tbank_grpc.gemspec`), RuboCop target обновлён до 3.2 ради Data.define
- **Breaking:** `Services::BaseService` удалён, unary-сервисы переведены на `Services::Unary::BaseUnaryService`
- **Breaking:** `CandleCollection#to_a(precision:)` заменён на `serialize_candles(precision:)` (избежание конфликта с `Enumerable#to_a`)
- **Breaking:** value objects `Money` и `Quotation` переведены на `Data.define`; `Models::Core::ValueObjects::Base` удалён
- Клиент разделяет channel manager для unary и stream lifecycle (изоляция reconnect), добавлены thread-safe lazy-init сервисов и явное закрытие всех stream managers при `close/reconnect`
- `Configuration` расширена stream-параметрами (`thread_pool_size`, `stream_idle_timeout`, `stream_watchdog_interval_sec`, `stream_metrics_enabled`) и прокидывает их в `to_h`
- `ChannelManager`: отдельные insecure endpoints (legacy `tinkoff.ru`), расширенные structured-логи, `reset(source:, reason:)` с явной семантикой глобального reset для manager instance
- `BaseModel`/DSL сериализации: `to_h(precision:)` теперь строится по реестру `serializable_attr`; улучшена обработка protobuf repeated/map и вложенных объектов в `Serializable`
- Модель `OrderBook` получила расширенные расчетные/display helper-методы (`best_*_price_*`, `spread_s`, `mid_price`, `spread_bps` через mid), а сериализация стала более явной
- Модель `Instrument` вынесла классовую логику в `Concerns::InstrumentClassMethods` (кэш моделей, определение типа по proto, fallback mapping)
- Набор instrument/unary методов унифицирован на `execute_rpc` вместо ручного `handle_request/call_rpc` в каждом методе
- `ProtoLoader`/`DeadlineResolver`/`ProtobufToHash` переведены на `self.*` API вместо `module_function` для единообразия
- Metrics/Observability: один класс `Core::Observability::Metrics` с `enabled:`; при `enabled: false` методы `track_*` работают как no-op и возвращается zero-shape статистика
- Streaming internals: `EventRouter` и Subscription Manager упрощены (единый `emit_event`, меньше промежуточных делегатов)

### Fixed
- Обработка `GRPC::PermissionDenied` и `GRPC::Unauthenticated` в listen loop (корректная остановка stream без бесконечных reconnect)
- Обработка `GRPC::Internal` в stream-цикле и стабилизация reconnect path без аварийного падения `listen`
- Исправлен off-by-one в reconnect attempts: backoff начинается с `attempt=1`
- Счетчики reconnect/consecutive_failures в listen loop приведены к ожидаемой семантике
- Устранён риск потери `STOP_SIGNAL` в worker loop при исключениях внутри callback-обработки

## [0.1.4] - 2026-02-17

### Added
- BaseModel#attributes — алиас к to_h (удобство, ожидания из Rails/ActiveModel)
- CandleCollection#to_a(precision: nil) — опциональный precision для сериализации свечей
- UsersService и модели аккаунтов: account, margin_attributes, user_info
- MarketDataService и подсервисы: candles_and_order_books, prices_and_statuses; модели: candle, candle_collection, last_price, order_book

### Changed
- Клиент: подключение UsersService и MarketDataService
- Facade: методы для доступа к Users и Market Data
- ChannelManager: get_channel → channel, get_endpoint → endpoint (приватный)
- Configuration: logger только через attr_writer
- Rubocop: TargetRubyVersion 3.0, метрики ClassLength/MethodLength/AbcSize/Cyclomatic/PerceivedComplexity, отключены Style/Documentation и DocumentDynamicEvalDefinition
- Value objects (Money, Quotation, UnitsNano): инициализация через super, единообразный validate!
- Dev-зависимости перенесены из gemspec в Gemfile с версиями
- Именование параметров: pb → proto, короткие имена → полные (op → operation и т.д.)
- CandlesAndOrderBooks: маппинг интервалов вынесен в константу INTERVAL_MAP
- BaseService: убран избыточный rescue GRPC::BadStatus в call_rpc

### Fixed
- Формирование сообщения ошибки в ErrorHandler (текст + код)

## [0.1.3] - 2026-02-17

### Added
- Базовый RPC-слой: BaseService, error_handler, deadline_resolver, rate_limit_handler, response, tracking_id
- Конвертеры: constants, enum, money, quotation, timestamp
- Модели: assets, instruments (bond, coupon, dividend, future, share и др.), schedules, value objects (money, quotation, units_nano), serialization/pretty_print
- InstrumentsService и подсервисы: assets, corporate_actions, derivatives, listings, lookup, schedules
- Хелперы: facade, instruments_helper, market_data_helper; proto_loader, formatters (inspectable_value)
- CI: workflow proto_check; документация yard в docs/yard.md

### Changed
- Клиент и точка входа: подключение InstrumentsService, загрузка proto
- Proto-файлы (сгенерированные), README, Rakefile

## [0.1.2] - 2026-02-17

### Added
- Proto-файлы контрактов T-Bank Invest API в `proto/`, сгенерированные `*_pb.rb` в `lib/tbank_grpc/proto/`
- Rake-задачи: `download_proto`, `compile_proto`, `clean_proto`, `autoupdate_proto`
- Документация по SSL-сертификатам: `docs/ssl_certificates.md`
- Перехватчики `Logging`, `Metadata` (вместо отдельных Auth/AppName/LoggingInterceptor)
- В конфигурации: опции `cert_path`, `insecure` для SSL
- В `bin/console`: предзагрузка сертификата из `certs/ca_bundle.crt`, хелпер `use_certs!`, `at_exit` с закрытием клиента

### Changed
- `Configuration`: добавлены SSL-опции (`cert_path`, `insecure`), учёт в `to_h`
- `ChannelManager`: рефакторинг работы с каналами — вынесение создания канала в `build_credentials`, `build_channel_args`, `retry_config`; создание через `ChannelCredentials` (системные или из файла), поддержка `insecure`; единая настройка keepalive, размера сообщений, retry
- `Client`: сбор перехватчиков через `Interceptors::Metadata` и `Interceptors::Logging` вместо удалённых Auth/AppName/LoggingInterceptor
- Структура перехватчиков (interceptors/logging.rb, interceptors/metadata.rb)
- `docs/setup.md`: актуальные шаги по proto (загрузка через rake, компиляция, требование grpc-tools)

### Removed
- Отдельные перехватчики: Auth, AppName, LoggingInterceptor

## [0.1.1] - 2026-02-06

### Added
- `TbankGrpc::Configuration`, `TbankGrpc.configure`, глобальный логгер
- `TbankGrpc::Client`, `ChannelManager`, `LoggingInterceptor`
- Перехватчики: Auth, AppName, Logging (включая server_streamer и bidi_streamer)
- Классы ошибок и маппинг gRPC-кодов: `Error.from_grpc_error`, `GRPC_CODE_MAP`
- Конфигурируемый endpoint (tbank.ru / tinkoff.ru, валидация host:port)
- Документация: `docs/setup.md`, `docs/configuration.md`
- Базовые тесты: configuration, client, channel_manager, errors
- Консоль на pry, зависимость logger для Ruby 4+
- Базовая настройка gRPC канала

### Changed
- Логгер: только stdlib `Logger`, обёртка `LoggerWrapper`, уровни `:debug`/`:info`/`:warn`/`:error`
- ChannelManager: проверка `channel_ready?` по `ConnectivityStates::IDLE`/`READY`, graceful shutdown при close

### Fixed
- Синтаксис `close`: rescue/ensure обёрнуты в begin для ветки с одним каналом

## [0.1.0] - 2026-02-06

### Added
- Базовая структура gem: lib/, proto/, spec/
- Неймспейс TbankGrpc
- Конфигурационные файлы: gemspec, Gemfile, Rakefile, .rspec
- Metadata в gemspec (homepage_uri, source_code_uri, changelog_uri, bug_tracker_uri)
- Зависимости: grpc (~> 1.60), google-protobuf (~> 3.24), zeitwerk (~> 2.6)
- Поддержка Ruby >= 3.0.0
