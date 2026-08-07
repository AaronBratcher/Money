# Money Architecture

Money represents monetary amounts as a fixed-point `Int` rather than a `Double`, so
arithmetic (summing line items, splitting totals, storing in a database) never
accumulates floating-point rounding error. A `Money` value pairs that `Int` with a
`Currency`, which supplies the ISO 4217 code and the number of decimal places the
currency is displayed with. A separate `ExchangeRateManager` actor handles converting
between currencies via a downloaded rate matrix.

## Component overview

| Component | Role |
| --- | --- |
| `Money` | The public value type: a fixed-point `amount: Int` paired with a `Currency`. Parses from and formats to `String`, and converts between currencies via `ExchangeRateManager`. |
| `Currency` | `String`-backed enum of 18 ISO 4217 currencies. Supplies `details` (name, alphabetic code, decimal precision) and a hand-written `RawRepresentable` mapping to the ISO code. |
| `Int`/`String` extensions | The formatting/parsing engine `Money` is built on — `Int.currencyString(...)` and `String.currencyValue(decimalPrecision:)` — usable directly on raw scaled amounts without going through `Money`. |
| `ExchangeRateManager` | An `actor` that lazily downloads a `[Currency: Double]` conversion matrix from the fixer.io API, caches it, and computes pairwise exchange rates. |
| `Response` / `CurrencyExchange` / `Agent` | The fixer.io API layer: response decoding, request building, and a small Combine-based HTTP runner. Internal (non-`public`). |
| `Collection.isNotEmpty` | Internal convenience extension used for readability at call sites (e.g. guarding the access key). |

## Fixed-point storage model

Every `Money.amount` and every value produced by `String.currencyValue`/consumed by
`Int.currencyString` is an `Int` scaled to a **fixed** `maxDecimalPrecision` of 4 decimal
places—this can be easily changed based on need, regardless of the currency's own display precision:

```swift
public let maxDecimalPrecision = 4
public let baseMultiplier: Int = 10.pow(toPower: maxDecimalPrecision) // 10,000
```

So `$1.00` is stored as `10_000`, and `23.234 IQD` (Iraqi Dinar, 3 decimal places) is
stored as `232_340`. Using one fixed internal precision for every currency — rather than
scaling by each currency's own `decimalPrecision` — means:

- Two `Money.amount` values can be added, subtracted, or compared directly as `Int`s
- Converting between currencies of different precision (e.g. USD → JPY) never loses
  sub-unit information from truncating to a coarser internal scale.
- Display precision is applied only at the formatting boundary (`amountString` /
  `currencyString(using:)`), which truncates the fixed 4-digit fraction down to
  `currency.details.decimalPrecision` digits.

### `Money` initializers

`Money` has three initializers, each handling the fixed-point scaling differently:

| Initializer | Behavior |
| --- | --- |
| `init(currency:amount: Int)` | The `Int` is taken as-is — already assumed to be scaled to `maxDecimalPrecision`. No conversion happens. |
| `init(currency:amount: String)` | Delegates to `String.currencyValue(decimalPrecision:)` using `currency.details.decimalPrecision`, parsing a human-entered string (e.g. `"23.23"`) up to the fixed internal scale. |
| `init(currency:amount: Double)` | Separates sign and magnitude up front (`abs(amount)`), splits the magnitude into an integer base and a fractional remainder scaled to `currency.details.decimalPrecision`, **zero-pads that fraction as a string** (not an `Int`) so a leading zero in the fraction — e.g. the `05` in `100.05` — survives, right-pads it out to `maxDecimalPrecision` digits, and re-applies the sign at the end. |

Zero-padding the fraction as a string, and tracking the sign separately from the magnitude, both matter: an `Int`-based fraction silently drops leading zeros (`Int("05") == 5`, not `05`), and folding the sign into the same subtraction/scaling arithmetic used for the magnitude corrupts it once a "-" character enters a padding computation. Currencies with `decimalPrecision == 0` (Japanese Yen) skip the fraction step entirely rather than computing a scale of `10^0` and multiplying by it, sidestepping `Int.pow(toPower:)`'s historical `0`-exponent edge case (see below).

### The formatting/parsing pipeline

`Int.currencyString(useThousandsSeparator:keepDecimal:using:)` and
`String.currencyValue(decimalPrecision:)` are the inverse of each other and do the actual
digit manipulation, entirely as string slicing rather than floating-point math (avoiding
any precision loss at the display boundary too):

- **`currencyString`**: stringifies `abs(amount)`, left-pads it to at least
  `maxDecimalPrecision` digits, splits off the last `maxDecimalPrecision` digits as the
  fractional part (itself truncated to the currency's `decimalPrecision`), then
  re-inserts the locale's grouping separator into the integer part every 3 digits from
  the right. A leading `-` is reattached for negative amounts (unless the formatted
  result is exactly `"0"`).
- **`currencyValue`**: strips the locale's grouping separator, then checks for and
  strips a leading `-` *before* any digit parsing happens (rather than inferring sign
  from the parsed integer part afterward — `Int("-0")` is `0`, which is never `< 0`, so
  inferring sign that way silently drops the sign of any `"-0.xx"`-style input). What
  remains must be only digits and the locale's decimal separator or the string is
  rejected outright (returning `0`). It then splits on the decimal separator, scales the
  integer part by `baseMultiplier`, right-pads/truncates the fractional part to
  `maxDecimalPrecision` digits, and re-applies the sign last.
- **`Int.adjustedDecimal`**: right-pads a bare fractional digit string (e.g. `"23"` from
  `23.23`) with zeros out to `maxDecimalPrecision` digits and converts it to `Int` — the
  glue that lets a decimal fragment be added directly to a `baseMultiplier`-scaled whole
  part.
- **`Int.pow(toPower:)`**: a small integer power helper (`10.pow(toPower: 4) == 10_000`)
  used throughout in place of `Foundation.pow`, which operates on `Double` and would
  reintroduce floating-point error into a fixed-point computation. `toPower: 0` correctly
  returns `1` (via `Array(repeating:count: 0).reduce(1, *)`, which reduces the empty array
  to its seed value); negative exponents return `0`, since this integer-only helper has no
  way to represent a fractional result.
- **`Int.currencyAmount`**: converts a fixed-point `Int` back to a `Double` by dividing as
  `Double(self) / Double(10.pow(toPower: maxDecimalPrecision))` — the division happens
  *after* the conversion to `Double` specifically so sub-unit value isn't truncated away
  by `Int` division first.

Both `currencyString` and `currencyValue` have zero-argument conveniences (`Int.currencyString`,
`String.currencyValue`) that resolve `Currency` from `Locale.current.currencyCode`,
falling back to `.usDollar`.

## Currency model

`Currency` is `CaseIterable`, `Codable`, and `Sendable`, with 18 cases named for their
currency (`.usDollar`, `.euro`, `.japaneseYen`, ...) rather than their ISO code. Two
independent pieces of data are attached per case:

- **`details: CurrencyDetails`** — a `switch` returning `name`, `alphabeticCode`
  (`= rawValue`), and `decimalPrecision` (2 for most currencies, 3 for the Bahraini/
  Iraqi/Jordanian/Kuwaiti/Omani currencies, 0 for Japanese Yen). All three fields on
  `CurrencyDetails` are `public let`s — `details` itself being `public` isn't enough on
  its own for callers outside the module to read the fields of the value it returns.
- **`RawRepresentable` conformance** — hand-written (not the compiler-synthesized
  `String` enum default) as two parallel `switch` statements mapping each case to/from
  its ISO 4217 alphabetic code (`.usDollar <-> "USD"`). This exists so `rawValue` is the
  ISO code rather than the Swift case name, while the case names stay ergonomic
  (`Currency.britishPound` rather than `Currency.gbp`).

`CurrencyDetails` defines `==` purely in terms of `alphabeticCode`, so two
`CurrencyDetails` values are equal whenever their currencies are, independent of `name`
or `decimalPrecision` agreeing.

## Currency conversion

`Money.convert(to:using:) async throws -> Money` converts an amount by asking an
`ExchangeRateManager` for a rate and applying it directly to the fixed-point `amount`:

```swift
public func convert(to newCurrency: Currency, using exchangeRateManager: ExchangeRateManager) async throws -> Money {
    var baseCurrency = await exchangeRateManager.baseCurrency
    var rate: Double
    if currency == baseCurrency {
        rate = try await exchangeRateManager.exchangeRate(from: currency, to: newCurrency)
    } else {
        rate = try await exchangeRateManager.exchangeRate(from: currency, to: baseCurrency)
    }

    // exchangeRate(from:to:) may have just triggered a download that changed
    // baseCurrency; re-read it before deciding whether a second hop is needed.
    baseCurrency = await exchangeRateManager.baseCurrency

    var adjustedAmount = Int(Double(amount) * rate)

    if currency != baseCurrency && newCurrency != baseCurrency {
        rate = try await exchangeRateManager.exchangeRate(from: baseCurrency, to: newCurrency)
        adjustedAmount = Int(Double(adjustedAmount) * rate)
    }

    return Money(currency: newCurrency, amount: adjustedAmount)
}
```

The rate matrix is quoted against a single `baseCurrency` (fixer.io's free tier always
quotes against EUR), so a conversion between two non-base currencies is done in two
hops — source → base → destination — each hop multiplying the fixed-point `Int` amount
directly by a `Double` rate. This is the one place fixed-point precision is deliberately
given up: `Double` arithmetic is unavoidable once a market exchange rate is involved, and
the result is truncated back to `Int` (not rounded) by the `Int(Double)` conversion.

`baseCurrency` is read twice — once before the first `exchangeRate` call, once after.
The first call's own internal logic is always correct regardless (it reads the actor's
live `baseCurrency` at the moment it runs, not a value passed in from `Money.convert`);
the second read exists purely so `Money.convert`'s own branching decision — whether a
second base-currency hop is needed at all — uses a `baseCurrency` that reflects any
download `exchangeRate` may have just triggered (e.g. on first use, when the matrix
started out empty), rather than a value snapshotted before that download happened.

## `ExchangeRateManager` — actor & caching

```swift
public final actor ExchangeRateManager {
    public init(with matrix: ConversionMatrix? = nil, base: Currency? = .euro)
    public private(set) var baseCurrency: Currency = .euro
    public func exchangeRate(from currency: Currency, to newCurrency: Currency) async throws -> Double
}
```

`init`, `baseCurrency`'s getter, and `exchangeRate` are all explicitly `public`. In Swift,
members of a `public` type default to `internal` unless individually marked — a type
being `public` says nothing about its members. Without these explicit modifiers the type
was constructible and usable only from *within* the Money module itself (including
`Money.convert`, and tests via `@testable import`), making the whole conversion feature
unreachable for any actual consumer of the package despite `Money.convert(to:using:)`
being public and requiring an `ExchangeRateManager` argument. `ConversionMatrix` (the
`[Currency: Double]` typealias used by `init`) is `public` for the same reason — a public
initializer can't take an internal type as a parameter.

- Being an `actor`, concurrent callers awaiting `exchangeRate` are automatically
  serialized against the manager's mutable `conversionMatrix`/`lastDownload` state — no
  separate locking is needed.
- A caller can seed `matrix`/`base` directly in the initializer (useful for tests, or to
  supply rates from a source other than fixer.io), bypassing the network entirely as long
  as `conversionMatrix` stays non-empty.
- `exchangeRate(from:to:)` triggers `downloadMatrix()` whenever the matrix is empty, or
  when it judges the cached matrix stale. Staleness is measured as
  `Date().timeIntervalSince(lastDownload) / 3600` — genuine hours elapsed since the last
  successful download — and a refresh is triggered once that reaches `4`, so a non-empty
  matrix is re-downloaded on the first `exchangeRate` call at least 4 hours after the
  previous download, not on a background timer. `lastDownload` starts `nil`, so the very
  first call always falls through to the `conversionMatrix.isEmpty` branch instead.
- Once a matrix is available, the rate itself is computed algebraically rather than
  looked up directly, since the matrix is only ever quoted against `baseCurrency`:
  `1 / conversionMatrix[currency]` when converting *to* the base currency, or
  `conversionMatrix[newCurrency]` directly when converting *from* the base currency to
  anything else. (Base-to-non-base and non-base-to-base are the only two shapes
  `exchangeRate` is ever called with — `Money.convert` handles the non-base-to-non-base
  case itself by chaining two calls through the base currency.) If `currency` itself is
  missing from the matrix, the thrown `MoneyError.missingCurrency` names `currency`, not
  `newCurrency` — each of the two `guard`s names the specific currency it checked.
- `downloadMatrix()` bridges the Combine-based `CurrencyExchange.retrieveLatest()`
  publisher into `async`/`await` with `withCheckedContinuation`, storing the subscription
  in a single actor-isolated `subscription: AnyCancellable?` so it isn't deallocated
  before the completion fires. A new download overwrites (and thereby cancels) whatever
  subscription preceded it, rather than accumulating one entry per download in an
  ever-growing collection — downloads are already serialized by the staleness check
  above, so at most one is ever in flight. Swift 6's strict concurrency checking rules
  out removing individual completed entries from a collection here: doing so would
  require sending a cancellable captured in a Combine completion closure (running off the
  actor, on `DispatchQueue.main`) back across actor isolation to remove itself, which the
  compiler rejects as a data-race risk.
- A `.failure` from the Combine pipeline is now classified before being surfaced:
  `error is DecodingError` maps to `MoneyError.parse`, anything else to `.download` — so
  callers can distinguish "the response didn't parse" from "the request itself failed"
  (previously both collapsed to `.download`, leaving `.parse` unreachable).

### fixer.io API layer

- `CurrencyExchange.accessKey` is a placeholder (`"<To be filled in by user>"`) that must
  be set before any live download; `retrieveLatest()` checks it with `accessKey.isNotEmpty`
  and throws `MoneyError.needKey` if it's still blank.
- `retrieveLatest()` builds a `GET` request against fixer.io's `/latest` endpoint over
  `https://`, requesting rates for every `Currency.allCases` code as a comma-joined
  `symbols` list. (fixer.io's free plan only serves plain `http://` — the access key is
  sent as a query parameter either way, so anyone on the free plan downgrading the scheme
  back to `http://` should be aware it's transmitted in cleartext.)
- `retrieve(for:)` is the historical-rate counterpart: same query-parameter shape as
  `retrieveLatest()`, but against a `yyyy-MM-dd`-formatted date path instead of `latest`.
- `Response` decodes `success`, `base` (as `Currency`, not raw `String`), and `rates` —
  the JSON `rates` object is `[String: Double]` on the wire but is remapped in a custom
  `init(from:)` into `[Currency: Double]`, silently dropping any code fixer.io returns
  that doesn't match a `Currency` case.
- `Agent.run(_:_:)` decodes the response with whichever `JSONDecoder` is passed in
  (defaulting to a plain `JSONDecoder()`), rather than always constructing its own —
  letting a future caller plug in a decoder with custom date/key strategies if needed.
- `MoneyError` (`needKey`, `download`, `parse`, `missingCurrency(String)`) is `public` —
  the error type surfaced through `Money.convert`'s `throws` — so callers can
  pattern-match specific failures (e.g. `catch MoneyError.needKey`) rather than only
  seeing an opaque `Error`.

## Package layout

```
Money/
  Sources/Money/
    Money.swift              — Money struct, baseMultiplier
    Currency.swift            — Currency enum, CurrencyDetails, maxDecimalPrecision
    ExchangeRateManager.swift — ExchangeRateManager actor, fixer.io API layer, MoneyError
    Response.swift            — fixer.io response decoding
    Extensions/
      Int.swift                — currencyString, currencyAmount, pow(toPower:), adjustedDecimal
      String.swift              — currencyValue
      Collection.swift          — isNotEmpty
  Tests/MoneyTests/
```

- Single library target (`Money`), no external dependencies — everything is built on
  `Foundation` and `Combine`.
- Minimum platforms: iOS 13, macOS 12, tvOS 15, watchOS 6.
- `Response`, `CurrencyExchange`, and `Agent` are internal (non-`public`) — the fixer.io
  request/response plumbing is an implementation detail. `MoneyError` is the one type in
  that area that's `public`, since it's the concrete error surfaced through
  `Money.convert`'s `throws`.
