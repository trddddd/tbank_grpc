# SSL-сертификаты (CERTIFICATE_VERIFY_FAILED)

API T-Bank использует сертификаты **НУЦ Минцифры РФ**. Они не входят в доверенные по умолчанию в большинстве ОС — при подключении к `tbank.ru` возникает `CERTIFICATE_VERIFY_FAILED`.

**Важно:** опция `insecure` для API T-Bank **не подходит**. Сервер на 443 принимает только TLS; при подключении без TLS соединение закрывается («Socket closed»). Нужны либо системные сертификаты с НУЦ, либо `cert_path`.

## Решения

### 1. Установка сертификатов НУЦ в систему (рекомендуется)

После установки гем работает с настройками по умолчанию (без `cert_path`).

**Конвертация .cer → .crt:** если `openssl x509 -inform DER` выдаёт «Could not find certificate», файлы уже в PEM — используйте без `-inform DER`:

```bash
openssl x509 -in russian_trusted_root_ca.cer -out russian_trusted_root_ca.crt
openssl x509 -in russian_trusted_sub_ca.cer -out russian_trusted_sub_ca.crt
```

**macOS:**

```bash
wget https://gu-st.ru/content/Other/doc/russian_trusted_root_ca.cer
wget https://gu-st.ru/content/Other/doc/russian_trusted_sub_ca.cer

# конвертация (DER или PEM — см. выше)
openssl x509 -inform DER -in russian_trusted_root_ca.cer -out russian_trusted_root_ca.crt
openssl x509 -inform DER -in russian_trusted_sub_ca.cer -out russian_trusted_sub_ca.crt

sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain russian_trusted_root_ca.crt
sudo security add-trusted-cert -d -r trustAsRoot -k /Library/Keychains/System.keychain russian_trusted_sub_ca.crt
```

**Linux (Ubuntu/Debian):**

```bash
wget https://gu-st.ru/content/Other/doc/russian_trusted_root_ca.cer
wget https://gu-st.ru/content/Other/doc/russian_trusted_sub_ca.cer

openssl x509 -inform DER -in russian_trusted_root_ca.cer -out russian_trusted_root_ca.crt
openssl x509 -inform DER -in russian_trusted_sub_ca.cer -out russian_trusted_sub_ca.crt

sudo mkdir -p /usr/local/share/ca-certificates/extra
sudo cp russian_trusted_root_ca.crt /usr/local/share/ca-certificates/extra/
sudo cp russian_trusted_sub_ca.crt /usr/local/share/ca-certificates/extra/
sudo update-ca-certificates
```

### 2. Опция cert_path

Файл с PEM-сертификатами (например, корневые НУЦ или bundle системных + НУЦ):

```ruby
TbankGrpc.configure do |config|
  config.cert_path = '/path/to/ca_bundle.crt'
end
```

**Консоль гема (`bin/console`):** положите `russian_trusted_root_ca.cer` и `russian_trusted_sub_ca.cer` в папку `certs/` (в корне репозитория, сама папка в .gitignore). Конвертируйте в .crt (см. блок про конвертацию выше), затем соберите bundle:

```bash
cd certs
cat russian_trusted_root_ca.crt russian_trusted_sub_ca.crt > ca_bundle.crt
```

При наличии `certs/ca_bundle.crt` консоль подхватит его автоматически.
