[![Gem Version](https://img.shields.io/gem/v/tbank_grpc.svg)](https://rubygems.org/gems/tbank_grpc)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Proto check](https://github.com/trddddd/tbank_grpc/actions/workflows/proto_check.yml/badge.svg)](https://github.com/trddddd/tbank_grpc/actions/workflows/proto_check.yml)

> [!WARNING]
> Это не production-ready решение. Использование — на свой страх и риск :)

Ruby-клиент для [T-Bank Invest API](https://developer.tbank.ru/invest/intro/intro). Обертка над gRPC API для алгоритмической торговли, доступа к рыночным данным и управления портфелем.

## Быстрый старт

```ruby
# Gemfile
gem 'tbank_grpc'
```

```ruby
TbankGrpc.configure do |config|
  config.token = ENV["TBANK_TOKEN"]
  config.app_name = "trddddd.tbank_grpc"
  config.sandbox = false
  # По умолчанию false; включайте при необходимости наблюдаемости.
  config.stream_metrics_enabled = true
end

client = TbankGrpc::Client.new
client.close
```

## UsersService

Счета, информация о пользователе, маржинальные показатели. Доступ: `client.users`.

```ruby
# Список счетов (опционально status: :open, :closed, :new, :all)
accounts = client.users.get_accounts
accounts = client.users.get_accounts(status: :open)

# Информация о пользователе (qualifications, tariff и т.д.)
info = client.users.get_info

# Маржинальные показатели по счёту
margin = client.users.get_margin_attributes(account_id: accounts.first.id)
```

## MarketDataService

Свечи, стакан, последние цены. Доступ: `client.market_data`.

```ruby
# Исторические свечи (instrument_id — FIGI, UID или ticker)
candles = client.market_data.get_candles(
  instrument_id: "BBG004730N88",
  from: Time.now - 7*24*3600,
  to: Time.now,
  interval: :CANDLE_INTERVAL_DAY
)
# candles — Models::MarketData::CandleCollection
# Сериализация: candles.to_h — Hash с ключом candles (массив Hash); candles.serialize_candles(precision: :big_decimal) — массив Hash свечей с BigDecimal
# Аналогично candles.to_h(precision: :big_decimal) и отдельная свеча candle.to_h(precision: :decimal)

# Стакан по инструменту (глубина 1–50)
order_book = client.market_data.get_order_book(instrument_id: "BBG004730N88", depth: 20)

# В модели стакана есть 2 представления цен:
# 1) domain-level (точный формат Quotation):
q = order_book.bids.first[:price]     # => Core::ValueObjects::Quotation
# 2) числовой формат для расчётов:
px = order_book.bid_prices.first      # => BigDecimal

# Для удобного вывода в консоль/UI используйте display-хелперы:
puts "bid=#{order_book.best_bid_price_s} ask=#{order_book.best_ask_price_s} spread=#{order_book.spread_s}"

# Последние цены по одному или нескольким инструментам
prices = client.market_data.get_last_prices(instrument_id: "BBG004730N88")
prices = client.market_data.get_last_prices(instrument_id: ["BBG004730N88", "BBG0047315D0"])
# prices — массив Models::MarketData::LastPrice
```

**Хелпер** — параллельная загрузка стаканов по нескольким инструментам (один RPC на инструмент):

```ruby
order_books = client.helpers.market_data.get_multiple_orderbooks(
  ["BBG004730N88", "BBG0047315D0"],
  depth: 10
)
```

## Market Data Streaming

Bidirectional-стрим рыночных данных: подписки на стакан, свечи, последние цены, сделки, торговый статус, открытый интерес. Доступ: `client.market_data_stream` или фасадные методы `client.stream_*`.
Подробно по ограничениям, реконнекту, payload-форматам и архитектурным нюансам: [docs/market_data_streaming.md](docs/market_data_streaming.md).
Внутренняя реализация стриминга разложена по `TbankGrpc::Streaming::Core::*` и `TbankGrpc::Streaming::MarketData::*` (это не публичный API).

**Подписки** (перед запуском цикла):

```ruby
# Стакан (глубина 1–50)
client.stream_orderbook(instrument_id: "BBG004730N88", depth: 20)

# Свечи в реальном времени
client.stream_candles(instrument_id: "BBG004730N88", interval: :CANDLE_INTERVAL_1_MIN)

# Сделки и последние сделки
client.stream_trades("BBG004730N88", trade_source: :TRADE_SOURCE_ALL)
# Фьючерс: с открытым интересом (события :trade и :open_interest)
client.stream_trades("FUTSI12345678", trade_source: :TRADE_SOURCE_ALL, with_open_interest: true)

# Торговый статус и последняя цена
client.stream_info("BBG004730N88")
client.stream_last_price("BBG004730N88")
```

**Обработка событий** — `on(event_type, as: :proto | :model, &block)`. Типы: `:candle`, `:orderbook`, `:trade`, `:trading_status`, `:last_price`, `:open_interest` (для моделей), плюс `:ping`, `:subscription_status` (только proto):

```ruby
client.market_data_stream.on(:trade, as: :model) { |trade| puts trade.to_h }
client.market_data_stream.on(:last_price, as: :model) { |lp| puts lp.price }
# при with_open_interest: true в stream_trades:
client.market_data_stream.on(:open_interest, as: :model) { |oi| puts oi.open_interest }

# Для orderbook/model можно использовать display-хелперы OrderBook:
client.market_data_stream.on(:orderbook, as: :model) do |ob|
  next unless ob.best_bid && ob.best_ask

  puts "[#{ob.time&.strftime('%H:%M:%S')}] " \
       "bid #{ob.best_bid_price_s} x #{ob.bid_quantities.first} | " \
       "ask #{ob.best_ask_price_s} x #{ob.ask_quantities.first} " \
       "spread #{ob.spread_s}"
end
```

**Запуск**: синхронный блокирующий цикл или асинхронный в фоне:

```ruby
# Синхронно (блокирует до stop_stream / Ctrl+C)
client.listen_to_stream

# Асинхронно
client.listen_to_stream_async
# ... позже
client.stop_stream
```

**Пример в консоли (IRB)** — подписки, события, запрос своих подписок (GetMySubscriptions), смена подписок без переподключения:

```ruby
# 1) Подписки (можно добавлять до и во время работы стрима)
client.stream_last_price("BBG004730N88")   # SBER
client.stream_orderbook(instrument_id: "BBG004730N88", depth: 10)

# 2) Обработчики событий
client.market_data_stream.on(:last_price, as: :model) { |lp| puts "last_price #{lp.instrument_uid} => #{lp.price}" }
client.market_data_stream.on(:orderbook, as: :model) do |ob|
  puts "orderbook #{ob.instrument_uid} bid=#{ob.best_bid_price_s} ask=#{ob.best_ask_price_s}"
end
# Ответы на GetMySubscriptions приходят как subscription_status (печать без шумного proto.inspect)
client.market_data_stream.on(:subscription_status, as: :proto) do |h|
  r = h[:response]
  puts "subscription_status: type=#{h[:type]} tracking_id=#{r.tracking_id}"
end

# 3) Запуск стрима (асинхронно)
client.listen_to_stream_async

# 4) Запрос списка активных подписок с сервера — запрос уходит в тот же стрим
client.market_data_stream.my_subscriptions
# В консоли появятся subscription_status по каждому типу подписок (orderbook, last_price, ...)
# Локальное состояние подписок (без запроса к серверу): client.market_data_stream.current_subscriptions

# 5) Подписки можно менять «на лету» — запросы уйдут в тот же стрим, без переподключения
client.stream_candles(instrument_id: "BBG004730N88", interval: :CANDLE_INTERVAL_1_MIN)
client.market_data_stream.on(:candle, as: :model) { |c| puts "candle #{c.close}" }

# Остановка
client.stop_stream
client.close
```

**Метрики**:
- `client.stream_metrics` — счётчики событий, подписки, реконнекты
- `client.stream_event_stats(:trade)` — статистика по типу события
- сбор метрик управляется `config.stream_metrics_enabled` (по умолчанию `false`)
- при отключении метрик оба метода возвращают zero-shape (тот же формат Hash, нулевые/пустые значения)

Важные нюансы:
- `as: :model` в `on(...)` поддерживается только для `:candle`, `:orderbook`, `:trade`, `:trading_status`, `:last_price`, `:open_interest`.
- В server-side stream (`market_data_server_side_stream(as: :model)`) payload `ping` и `subscription_status` пропускаются, stream не падает.
- Клиентский guard лимитов: `300` подписок на соединение (в библиотеке `info` не учитывается) и `100` мутаций/мин.
- Для stream RPC по умолчанию deadline не выставляется; при необходимости задаётся через `config.deadline_overrides`.
- `GRPC::PermissionDenied` / `GRPC::Unauthenticated` останавливают stream: после обновления токена запустите listen заново.

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
sber = client.instruments.get_instrument_by(id_type: :figi, id: "BBG004730N88")
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

> [!NOTE]
> **Модели и вывод в консоли**  
> В консоли (inspect / pretty_print) у моделей показываются только **часть полей** — выбранные для краткого отображения. Все поля: **`to_h`** или **`attributes`**. Для свечей и стакана: `to_h(precision: :big_decimal)`; у коллекции свечей также `serialize_candles(precision: :big_decimal)` — цены (open, high, low, close и т.д.) в виде **BigDecimal** вместо Float.

Подробнее: [Setup](docs/setup.md), [Configuration](docs/configuration.md), [Market Data Streaming](docs/market_data_streaming.md). 

Документация API (YARD): `bundle exec rake doc`, просмотр — `bundle exec yard server` ([docs/yard.md](docs/yard.md)).
