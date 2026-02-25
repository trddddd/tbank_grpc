# Liquidity Analyzer Bot (tbank_grpc)

Сбор стакана, расчёт спреда и проскальзывания (BPS), отчёт по ликвидности. Два режима: **один отчёт** (polling по интервалу) и **watch** (стрим стакана через MarketDataStream).

Использует гем **tbank_grpc** (T-Bank Invest API).

## Типы инструментов

Бот резолвит инструмент так: при **--figi** — `get_by_figi`; при **--class-code** — `get_by_ticker(ticker, class_code)`; иначе — `get_by_ticker_any_class(ticker)` (поиск по всем классам). В run.rb передаётся **тикер из API**, не условное обозначение:

- **Акции:** тикер бумаги (SBER, GAZP, YNDX) — можно без `--class-code`.
- **Фьючерсы:** биржевой тикер из API (например SiH6 для Si-3.26), не «Si-3.26». Указать `--class-code=SPBFUT` или использовать `--figi`.
- **Облигации:** полный тикер из API (например SU26238RMFS4 для ОФЗ 26238). Указать `--class-code=TQOB` или `--figi`.

## Структура

```
liquidity_analyzer/
  run.rb              # точка входа: Boot → ConfigLoader, TbankGrpc.configure, Runner
  lib/
    config.rb         # OptionParser, DEFAULTS, apply_env!, Settings, grpc_options
    runner.rb         # оркестрация; Session (polling) или watch (stream_orderbook + on(:orderbook) + listen)
    session.rb        # polling: get_order_book, OrderbookProcessor → SpreadStats
    calculator.rb     # walk-the-book, slippage BPS, VWAP (Calculator.slippage)
    stats.rb          # SpreadStats (RingBuffer), SlidingWindow, NumericStats
    report.rb         # ReportFormatter (stats, money_to_entry, window_size, stream_metrics)
    orderbook_processor.rb  # process(orderbook, stats) → Calculator + add_sample
  README.md
```

## ENV и SSL

- **TBANK_TOKEN** — обязательно.
- **TBANK_INSECURE** = `1` — подключение без сертов. В отчёте выводится пометка INSECURE.
- **TBANK_SANDBOX** — при наличии переменной: `1` = sandbox, иначе production. По умолчанию (если не задана) sandbox=true из DEFAULTS.
- **TBANK_LOG_LEVEL** — уровень лога (например `debug`); при отсутствии — дефолт из config.

**app_name** захардкожен (`trddddd.tbank_grpc`). Серты: при отсутствии insecure бот ищет `certs/ca_bundle.crt` в текущей директории, в корне гема и в корне репо; при неудаче `cert_path` не задаётся. ENV **TBANK_CERT_PATH** не используется (путь к сертам ищется автоматически).

## Запуск

Из **корня гема** `tbank_grpc` (задай **TBANK_TOKEN**):

```bash
bundle exec ruby -I lib example_bots/liquidity_analyzer/run.rb SBER
bundle exec ruby -I lib example_bots/liquidity_analyzer/run.rb SBER 0              # один снимок
bundle exec ruby -I lib example_bots/liquidity_analyzer/run.rb --watch SBER        # стрим
bundle exec ruby -I lib example_bots/liquidity_analyzer/run.rb --figi=BBG004730N88 0 1000000
```

Фьючерс/облигация — тикер из API + класс (или FIGI):

```bash
bundle exec ruby -I lib example_bots/liquidity_analyzer/run.rb SiH6 --class-code=SPBFUT 0 500000
bundle exec ruby -I lib example_bots/liquidity_analyzer/run.rb SU26238RMFS4 --class-code=TQOB 0 1000000
```

### Как найти тикер/FIGI (консоль)

Бот использует `helpers.instruments.get_by_ticker_any_class(ticker)` или `get_by_ticker(ticker, class_code)` / `get_by_figi`. В run.rb передаётся **ticker из API** (для фьючерса SiH6, не «Si-3.26»). Найти его:

```ruby
require 'tbank_grpc'
client = TbankGrpc::Client.new

# Поиск по строке — в ответе ticker/figi/class_code для подстановки в run.rb
client.instruments.find_instrument(query: "Si-3.26").each { |i| p [i.ticker, i.figi, i.class_code] }
# => ["SiH6", "FUTSI0326000", "SPBFUT"]

client.instruments.find_instrument(query: "SU26238").each { |i| p [i.ticker, i.figi, i.class_code] }
# => ["SU26238RMFS4", "BBG011FJ4HS6", "TQOB"]

# Списки: client.instruments.futures, .bonds (у каждого .data.instruments)
# Полный инструмент по FIGI: client.helpers.instruments.get_by_figi("BBG004730N88")
# По тикеру+классу: client.helpers.instruments.get_by_ticker("SiH6", class_code: "SPBFUT")
```

## Порядок аргументов

- **Один отчёт:** `run.rb TICKER [minutes] [money] [interval_sec] [depth]` (minutes=0 — один снимок)
- **Watch:** `run.rb --watch TICKER [money] [depth]`
- **По FIGI:** `run.rb --figi=FIGI [minutes] [money] [interval_sec] [depth]`
- **С классом:** `run.rb TICKER --class-code=SPBFUT` (фьючерсы) или `--class-code=TQOB` (облигации)

Флаги: `-w`/`--watch`, `--figi=FIGI`, `--class-code=CODE`. Дефолты: minutes 5, money 1_000_000, interval 5, depth 20. Polling ограничен 60 мин (max_duration_sec); в watch обновление отчёта раз в 1 с (render_throttle_sec). Глубина стакана depth ограничена 1..50 (MAX_DEPTH в config).

## Интерпретация отчёта

**Режим (баннер)** — SANDBOX или PRODUCTION. INSECURE — подключение без сертификата.

**BPS (basis points):** 1 BPS = 0.01% от суммы сделки. Для суммы входа отчёт показывает примерные потери в рублях.

**Критерии ликвидности** (по медиане проскальзывания):
- &lt; 5 BPS — отлично, низкие издержки для алго
- 5–20 BPS — хорошо, активная торговля
- 20–50 BPS — средне
- 50–100 BPS — плохо
- &gt; 100 BPS — крайне плохо

**По каждой бумаге:**
- **LONG** — проскальзывание при **покупке** (вход в лонг): на сколько BPS выше лучшей цены ты проходишь стакан на заданную сумму.
- **SHORT** — при **продаже** (вход в шорт): на сколько BPS ниже лучшей цены получаешь.
- **СРЕДНИЙ импакт (both)** — усреднённое по обоим направлениям; по нему даётся общая оценка ликвидности.

**Блок MICROSTRUCTURE** (есть в режиме watch при включённом окне, по умолчанию 100 сэмплов):
- **Окно** — последние N снимков стакана; по каждому считались slippage long/short.
- **Медиана** — типичное значение: в половине сэмплов издержки лучше, в половине хуже.
- **90% перцентиль** — в 90% случаев проскальзывание не хуже этого; в 10% бывают пики (хуже ликвидность). Если 90% ≈ медиане — хвостов почти нет.
- **Волатильность (σ)** — стандартное отклонение BPS по окну: насколько стабильны издержки от снимка к снимку.
  - **σ long / σ short** — волатильность издержек отдельно при покупке и при продаже. Низкие значения = предсказуемые издержки по направлению.
  - **σ both** — по объединённой выборке (long + short); обычно выше, т.к. long и short имеют разные уровни (асимметрия стакана), а не из‑за скачков.
