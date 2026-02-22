# YARD — документация API

В проекте используется [YARD](https://yardoc.org/) для генерации документации по публичному API гема.

## Установка

YARD подключается как dev-зависимость. После `bundle install` доступны команды ниже.

## Генерация HTML

Из корня репозитория:

```bash
bundle exec rake doc
```

или напрямую:

```bash
bundle exec yard doc
```

Результат: каталог `doc/` с HTML. Конфигурация — в [.yardopts](../.yardopts): обрабатывается `lib/**/*.rb`, исключается `lib/tbank_grpc/proto/`, приватные методы по умолчанию не попадают в док.

В YARD попадает **только** то, что сгенерировано из Ruby-кода в `lib/`. Каталог `docs/` (setup, configuration, ssl_certificates и т.д.) в вывод YARD не входит — это проектная документация для репозитория и GitHub.

Практически полезные точки входа в текущем API:
- `TbankGrpc::Client` (включая stream helper-методы)
- `TbankGrpc::Services::MarketDataStreamService` (callbacks, listen lifecycle, server-side stream)
- `TbankGrpc::Services::Unary::BaseUnaryService`, `TbankGrpc::Services::Streaming::BaseServerStreamService`, `TbankGrpc::Services::Streaming::BaseBidiStreamService` (базовые абстракции по типам RPC)
- `TbankGrpc::Streaming::Core::Dispatch::EventLoop`, `TbankGrpc::Streaming::MarketData::Subscriptions::Manager`, `TbankGrpc::Streaming::Core::Observability::Metrics` (внутренняя streaming инфраструктура)

## Просмотр в браузере (live server)

```bash
bundle exec yard server
```

Откроется локальный сервер (по умолчанию http://localhost:8808). Удобно для навигации по классам и методам.

## Как писать комментарии в стиле YARD

Над методом/классом пишется комментарий с тегами:

- **`@param`** — параметр: имя, тип в квадратных скобках, описание.
- **`@return`** — тип и описание возвращаемого значения (несколько типов через запятую: `[Integer, nil]`).
- **`@raise`** — исключения, которые может выбросить метод.
- **`@example`** — пример вызова (можно несколько).
- **`@!attribute [rw] name`** — для динамических атрибутов (например `attr_accessor`), `[r]` только чтение, `[rw]` чтение/запись.

Пример:

```ruby
# Суммирует элементы массива после приведения к Integer.
#
# @param numbers [Array<String, Integer>] массив чисел или строк. По умолчанию [].
# @return [Integer] сумма. Пустой массив => 0.
# @raise [TypeError] если элемент не удаётся привести к целому.
#
# @example
#   add(numbers: [1, 2, 3]) # => 6
def add(numbers: [])
  numbers.map(&:to_i).inject(0, :+)
rescue StandardError => e
  raise TypeError, "Failed: #{e.message}"
end
```

Документировать приватные методы в коде: `# @private` над методом. Включить их в вывод: `yard doc --private`. Исключить даже с тегом: `yard doc --no-private` (по умолчанию в нашем `.yardopts` используется `--no-private`).

## Полезные ссылки

- [YARD](https://yardoc.org/)
- [Теги YARD](https://rubydoc.info/gems/yard/file/docs/Tags.md)
