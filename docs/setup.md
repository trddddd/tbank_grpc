# Setup

## 1) Установка зависимостей

```bash
cd /path/to/tbank_grpc
bundle install
```

TODO: ## 2) Загрузка proto-контрактов

```bash
bin/setup_proto
```

Полный список файлов для ручной загрузки (репозиторий T-Bank Invest API):

```bash
mkdir -p proto/tbank/invest/v1
curl -o proto/tbank/invest/v1/common.proto ...
```

TODO: ## 3) Компиляция proto

```bash
bundle exec rake compile_proto
```

## 4) SSL-сертификаты

API T-Bank использует сертификаты НУЦ Минцифры РФ; без них возможна ошибка `CERTIFICATE_VERIFY_FAILED`. По умолчанию гем использует системные сертификаты; при необходимости задайте `cert_path` в конфигурации (см. [configuration.md](configuration.md)).

Подробно: установка НУЦ в систему, сборка `ca_bundle.crt`, использование в `bin/console` — [ssl_certificates.md](ssl_certificates.md).
