# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.4] - 2026-02-17

### Added
- BaseModel#attributes — алиас к to_h (удобство, ожидания из Rails/ActiveModel)
- CandleCollection#to_a(precision: nil) — опциональный precision для сериализации свечей
- UsersService и модели аккаунтов: account, margin_attributes, user_info
- MarketDataService и подсервисы: candles_and_order_books, prices_and_statuses; модели: candle, candle_collection, last_price, order_book

### Changed
- Клиент: подключение UsersService и MarketDataService
- Facade: методы для доступа к Users и Market Data

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
