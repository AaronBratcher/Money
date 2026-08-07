# Money
- A way of storing money values as `Int` for easy, exact mathematical manipulation at the database level — no floating point rounding errors.
- Supports 18 currencies, each with its own decimal precision (e.g. 2 for US Dollar, 3 for Kuwaiti Dinar, 0 for Japanese Yen).
- Formats amounts as locale-aware, currency-correct strings, and parses strings back into exact `Int` amounts.
- Includes an actor-based `ExchangeRateManager` for converting a `Money` value between currencies.

## Installation ##
include Money as a dependency in your Package.swift file:
```swift
dependencies: [
   .package(url: "https://github.com/AaronBratcher/Money", from: "1.1.3")
]
```

## Getting Started ##
Money values are always stored as an `Int` scaled to a fixed 4 decimal places (`maxDecimalPrecision`), regardless of how many decimal places the currency itself uses for display. This keeps arithmetic exact — no `Double` rounding errors accumulate when you add, subtract, or sum amounts — while `amountString` still formats the value using the correct number of decimal places for its currency.

```swift
public let maxDecimalPrecision = 4
public let baseMultiplier: Int = 10.pow(toPower: maxDecimalPrecision) // 10000
```

## Money Struct ##
```swift
public struct Money: Codable {
    public let currency: Currency
    public let amount: Int

    public var amountString: String { get }

    public init(currency: Currency = .usDollar, amount: String)
    public init(currency: Currency = .usDollar, amount: Int)
    public init(currency: Currency = .usDollar, amount: Double)

    public func convert(to newCurrency: Currency, using exchangeRateManager: ExchangeRateManager) async throws -> Money
}
```
- `amount` is always stored at `maxDecimalPrecision` (4 decimal places) internally, no matter the currency's own decimal precision.
- Initializing from a `String` or `Double` parses/scales the value into that internal `Int` representation; initializing from an `Int` treats the value as already being in that representation.
- `amountString` formats `amount` back down to the currency's own decimal precision (e.g. 2 places for US Dollar, 0 for Japanese Yen), with thousands separators and locale-aware separators.

### Sample Usage ###
```swift
import Money

// From a String — parsed using the currency's own decimal precision
let price = Money(currency: .usDollar, amount: "23.23")
price.amount        // 232300  (23.23 * baseMultiplier)
price.amountString  // "23.23"

// From a Double
let total = Money(currency: .usDollar, amount: 100.25)
total.amountString  // "100.25"

// From an already-scaled Int (e.g. loaded from a database)
let stored = Money(currency: .usDollar, amount: 1_000 * baseMultiplier)
stored.amountString  // "1,000.00"

// Currencies with different decimal precision are handled automatically
let yen = Money(currency: .japaneseYen, amount: "23.23")
yen.amountString  // "23"  (Yen has 0 decimal places)

let dinar = Money(currency: .iraqiDinar, amount: "23.234")
dinar.amountString  // "23.234"  (Dinar has 3 decimal places)
```

## Currency ##
`Currency` is a `String`-backed, `Codable`, `Sendable` enum covering 18 ISO 4217 currencies:

```swift
public enum Currency: String, CaseIterable, Codable, Sendable {
    case australianDollar, bahrainiDinar, britishPound, canadianDollar, caymanIslandsDollar,
         chineseRenminbi, euro, hongKongDollar, iraqiDinar, japaneseYen, jordanDinar,
         kuwaitiDinar, malaysianRinggit, newZealandDollar, rialOmani, swedishKrona,
         swissFranc, usDollar
}
```
- `rawValue` is the currency's ISO 4217 alphabetic code (e.g. `.usDollar.rawValue == "USD"`), and `Currency(rawValue:)` parses a code back into a case.
- `details` returns a `CurrencyDetails` with the currency's display `name`, `alphabeticCode`, and `decimalPrecision` (how many decimal places that currency is displayed with).

```swift
let currency = Currency.kuwaitiDinar
currency.rawValue                    // "KWD"
currency.details.name                // "Kuwaiti Dinar"
currency.details.decimalPrecision    // 3

let parsed = Currency(rawValue: "EUR")  // .euro
```

## Formatting & Parsing Extensions ##
The `Int` and `String` extensions that back `Money` are also usable directly if you're working with raw scaled amounts.

### Int → String ###
```swift
/**
Formats an Int amount (scaled to maxDecimalPrecision) as a currency string.

- parameter useThousandsSeparator: Insert locale-aware grouping separators. Default true.
- parameter keepDecimal: Include the decimal portion. Default true.
- parameter using: The Currency whose decimalPrecision determines how many decimal digits are shown.

- returns: A formatted, locale-aware currency string.
*/
func currencyString(useThousandsSeparator: Bool = true, keepDecimal: Bool = true, using currency: Currency = .usDollar) -> String
```
```swift
let amount = 1_000 * baseMultiplier + 23.adjustedDecimal
amount.currencyString(using: .usDollar)                                      // "1,000.23"
amount.currencyString(useThousandsSeparator: false, using: .usDollar)         // "1000.23"
amount.currencyString(keepDecimal: false, using: .usDollar)                   // "1,000"

// currencyString with no arguments uses the device's current locale currency
amount.currencyString
```

### String → Int ###
```swift
/**
Parses a currency-formatted string (grouping separators allowed) into an Int scaled to maxDecimalPrecision.

- parameter decimalPrecision: The number of decimal digits the input string is expressed in (typically currency.details.decimalPrecision).

- returns: The parsed amount as an Int, or 0 if the string contains characters other than digits, the locale's decimal separator, and a leading "-".
*/
func currencyValue(decimalPrecision: Int) -> Int
```
```swift
"23.23".currencyValue(decimalPrecision: 2)   // 232300
"1,000.23".currencyValue(decimalPrecision: 2) // 10002300

// currencyValue with no arguments uses the device's current locale currency
"23.23".currencyValue
```

## Exchange Rates ##
`ExchangeRateManager` is a Swift `actor` that fetches a conversion matrix (currently from the [fixer.io](https://fixer.io) API) and converts `Money` values between currencies.

```swift
public final actor ExchangeRateManager {
    public init(with matrix: ConversionMatrix? = nil, base: Currency? = .euro)

    public private(set) var baseCurrency: Currency

    public func exchangeRate(from currency: Currency, to newCurrency: Currency) async throws -> Double
}
```
- `ConversionMatrix` is a public `[Currency: Double]` typealias.
- If no `matrix` is supplied, the manager downloads one on first use and refreshes it automatically once it's more than 4 hours old.
- Downloading requires a fixer.io access key. Set `CurrencyExchange.accessKey` (in `ExchangeRateManager.swift`) before making a live conversion; without a key, `exchangeRate` throws `MoneyError.needKey`.
- Pass your own `matrix` (e.g. for tests, or a rate source other than fixer.io) to skip the network call entirely.

### Usage ###
```swift
let exchangeRateManager = ExchangeRateManager()

let price = Money(currency: .usDollar, amount: "23.23")
do {
    let converted = try await price.convert(to: .euro, using: exchangeRateManager)
    // converted.amountString
} catch MoneyError.needKey {
    // CurrencyExchange.accessKey hasn't been set
} catch MoneyError.missingCurrency(let code) {
    // the conversion matrix didn't include a rate for the given ISO code
} catch {
    // .download or .parse — the fixer.io request failed or its response didn't decode
}
```

`Money.convert(to:using:)` handles the case where neither the source nor destination currency is the manager's `baseCurrency`, chaining two conversions (source → base → destination) through the same matrix.
