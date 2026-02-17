[![Gem Version](https://img.shields.io/gem/v/tbank_grpc.svg)](https://rubygems.org/gems/tbank_grpc)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Proto check](https://github.com/trddddd/tbank_grpc/actions/workflows/proto_check.yml/badge.svg)](https://github.com/trddddd/tbank_grpc/actions/workflows/proto_check.yml)

> [!WARNING]
> Это не production-ready решение. Использование — на свой страх и риск :)

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

## InstrumentsService

Сервис инструментов: поиск по FIGI/тикеру, списки акций/облигаций/фьючерсов, расписания, купоны, дивиденды, активы. Доступ: `client.instruments`.

**Поиск и получение по идентификатору** — `id_type`: `:figi`, `:ticker`, `:uid`. При `id_type: :ticker` API требует `class_code` (класс инструмента на бирже, например акции TQBR, облигации TQOB, фьючерсы SPBFUT):

```ruby
ins = client.instruments.get_instrument_by(id_type: :figi, id: "BBG004730N88")
ins = client.instruments.share_by(id_type: :ticker, id: "SBER", class_code: "TQBR")
ins = client.instruments.bond_by(id_type: :ticker, id: "SU26238RMFS4", class_code: "TQOB")
ins = client.instruments.future_by(id_type: :ticker, id: "SiZ4", class_code: "SPBFUT")
```

**Поиск по строке** (тикер, название). `instrument_kind` — тип из enum InstrumentType: `:futures`, `:share`, `:bond`, `:instrument_type_futures` и т.д. (не `instrument_kind_*`):

```ruby
list = client.instruments.find_instrument(query: "Сбер", api_trade_available_flag: true)
list = client.instruments.find_instrument(query: "Сбер", instrument_kind: :futures)
# list — массив Models::Instruments::InstrumentShort
```

**Списки инструментов** (опционально: `instrument_status`, `instrument_exchange` — символы из enum или числа):

```ruby
all_shares = client.instruments.shares
bonds = client.instruments.bonds(instrument_status: :instrument_status_base)
futures = client.instruments.futures
```

**Расписания торгов** (`exchange` — код площадки, например `"MOEX"`):

```ruby
schedules = client.instruments.trading_schedules(
  exchange: "MOEX",
  from: Time.now,
  to: Time.now + 7 * 24 * 3600
)
```

**Корпоративные действия** (облигация/акция по `instrument_id` — FIGI или UID):

```ruby
ins = client.instruments.bond_by(id_type: :ticker, id: "SU26238RMFS4", class_code: "TQOB")
coupons = client.instruments.get_bond_coupons(instrument_id: ins.instrument_uid, from: "2024-01-01", to: "2025-12-31")
nkds = client.instruments.get_accrued_interests(instrument_id: ins.instrument_uid, from: Time.now - 365*24*3600)

ins = client.instruments.share_by(id_type: :ticker, id: "SBER", class_code: "TQBR")
dividends = client.instruments.get_dividends(instrument_id: ins.instrument_uid, from: "2024-01-01")
```

**Фьючерс: маржа** (инструмент можем получить через lookup или напрямую если знаем instrument_id):

```ruby
list = client.instruments.find_instrument(query: "Сбер", instrument_kind: :futures)
future = list.first
margin = client.instruments.get_futures_margin(instrument_id: future.uid)
```

**Активы** — данные по эмитенту (активу). В API это два разных UID: **instrument_uid** (бумага) и **asset_uid** (эмитент/актив). Для `get_asset_by` / `get_asset_fundamentals` нужен именно `asset_uid` из инструмента. Пример по Сбербанку:

```ruby
# Инструмент (акция Сбера) и UID актива
asset_uid = sber.asset_uid

# Полное описание актива (тип, название, валюта, инструменты и т.д.)
asset = client.instruments.get_asset_by(id: asset_uid)

# Фундаментальные показатели (капитализация, P/E, выручка и т.д.)
fundamentals = client.instruments.get_asset_fundamentals(assets: asset_uid)
# или несколько активов: assets: [sber.asset_uid, another_share.asset_uid]

# Даты выхода отчётности эмитента (по FIGI/UID инструмента)
reports = client.instruments.get_asset_reports(
  instrument_id: sber.figi,
  from: "2024-01-01",
  to: "2025-12-31"
)
```

Во всех методах опция `return_metadata: true` возвращает `TbankGrpc::Response` (data + metadata: tracking_id, ratelimit и т.д.) вместо модели/массива. Ошибки API — `TbankGrpc::Error` и подклассы.

Подробнее: [Setup](docs/setup.md), [Configuration](docs/configuration.md). Документация API (YARD): `bundle exec rake doc`, просмотр — `bundle exec yard server` ([docs/yard.md](docs/yard.md)).