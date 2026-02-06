[![Gem Version](https://img.shields.io/gem/v/tbank_grpc.svg)](https://rubygems.org/gems/tbank_grpc)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> [!WARNING]
> Это не production-ready решение, а личная библиотека, которую я использую в для своих нужд. Использование — на свой страх и риск.

Ruby-клиент для [T-Bank Invest API](https://developer.tbank.ru/invest/api). Обертка над gRPC API для алгоритмической торговли, доступа к рыночным данным и управления портфелем.

## Быстрый старт

```ruby
# Gemfile
gem 'tbank_grpc'
```

```ruby
TbankGrpc.configure do |config|
  config.token = ENV["TBANK_TOKEN"]
  config.app_name = "my_app"
  config.sandbox = false
end

client = TbankGrpc::Client.new
client.close
```

Подробнее: [Setup](docs/setup.md), [Configuration](docs/configuration.md).