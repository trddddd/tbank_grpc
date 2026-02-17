# Setup

## 1) Установка зависимостей

```bash
cd /path/to/tbank_grpc
bundle install
```

## 2) Proto-контракты

Исходники `.proto` уже лежат в `proto/` (репозиторий [invest-contracts](https://opensource.tbank.ru/invest/invest-contracts)). Чтобы обновить их с сервера T-Bank:

```bash
bundle exec rake download_proto
```

## 3) Компиляция proto

Нужен компилятор `grpc_tools_ruby_protoc` (пакет `grpc-tools`). Результат — Ruby-классы в `lib/tbank_grpc/proto/`.

```bash
gem install grpc-tools   # если ещё не установлен
bundle exec rake compile_proto
```

Всё одной командой (очистка сгенерированных файлов, загрузка proto, компиляция): `bundle exec rake autoupdate_proto`.

## 4) SSL-сертификаты

API T-Bank использует сертификаты НУЦ Минцифры РФ; без них возможна ошибка `CERTIFICATE_VERIFY_FAILED`. По умолчанию гем использует системные сертификаты; при необходимости задайте `cert_path` в конфигурации (см. [configuration.md](configuration.md)).

Подробно: установка НУЦ в систему, сборка `ca_bundle.crt`, использование в `bin/console` — [ssl_certificates.md](ssl_certificates.md).
