import Foundation

public let baseMultiplier: Int = 10.pow(toPower: maxDecimalPrecision)

public struct Money: Codable {

	public let currency: Currency
	public let amount: Int

	public var amountString: String {
		return amount.currencyString(useThousandsSeparator: true, keepDecimal: true, using: currency)
	}

	public init(currency: Currency = .usDollar, amount: String) {
		self.currency = currency
		self.amount = amount.currencyValue(decimalPrecision: currency.details.decimalPrecision)
	}

	public init(currency: Currency = .usDollar, amount: Int) {
		self.currency = currency
		self.amount = amount
	}

	public init(currency: Currency = .usDollar, amount: Double) {
		self.currency = currency
		let decimalPrecision = currency.details.decimalPrecision
		let negative = amount < 0
		let magnitude = abs(amount)
		let base = Int(magnitude)

		var fractionValue = 0
		if decimalPrecision > 0 {
			let scale = 10.pow(toPower: decimalPrecision)
			let scaledFraction = Int(((magnitude - Double(base)) * Double(scale)).rounded())
			var fractionString = String(min(scaledFraction, scale - 1))
			if fractionString.count < decimalPrecision {
				fractionString = String(repeating: "0", count: decimalPrecision - fractionString.count) + fractionString
			}
			fractionString += String(repeating: "0", count: maxDecimalPrecision - decimalPrecision)
			fractionValue = Int(fractionString) ?? 0
		}

		let adjusted = base * baseMultiplier + fractionValue
		self.amount = negative ? -adjusted : adjusted
	}

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
}

