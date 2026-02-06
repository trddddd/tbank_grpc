# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
