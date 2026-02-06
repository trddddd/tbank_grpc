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

TODO: ## 4) SSL

По умолчанию используются системные сертификаты. Либо через `cert_path` в конфигурации (см. [configuration.md](configuration.md)).
