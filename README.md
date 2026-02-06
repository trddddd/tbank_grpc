[![Gem Version](https://img.shields.io/gem/v/tbank_grpc.svg)](https://rubygems.org/gems/tbank_grpc)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

> [!WARNING]
> Это не production-ready решение, а личная библиотека, которую я использую в для своих ботов. Использование — на свой страх и риск.

Ruby-клиент для [T-Bank Invest API](https://developer.tbank.ru/invest/api). Обертка над gRPC API для алгоритмической торговли, доступа к рыночным данным и управления портфелем.

## Быстрый старт

```ruby
# Gemfile
gem 'tbank_grpc'
```

```ruby
client = TbankGrpc::Client.new(
  token: ENV["TBANK_TOKEN"],
  app_name: "my_app",
  sandbox: false
)

# Пример: свечи
candles = client.market_data.get_candles(
  instrument_id: "BBG004730N88",
  from: Time.now - 1.day,
  to: Time.now,
  interval: :CANDLE_INTERVAL_HOUR
)
```
