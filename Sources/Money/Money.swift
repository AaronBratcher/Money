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
		let base = Int(amount)
		let decimal = (amount - Double(base)) * Double(10.pow(toPower: currency.details.decimalPrecision))
		let adjusted = base * baseMultiplier + Int(decimal).adjustedDecimal

		self.amount = adjusted
	}

	public func convert(to newCurrency: Currency, using exchangeRateManager: ExchangeRateManager) async throws -> Money {
        let baseCurrency = await exchangeRateManager.baseCurrency
		var rate: Double
		if currency == baseCurrency {
			rate = try await exchangeRateManager.exchangeRate(from: currency, to: newCurrency)
		} else {
			rate = try await exchangeRateManager.exchangeRate(from: currency, to: baseCurrency)
		}

		var adjustedAmount = Int(Double(amount) * rate)

		if currency != baseCurrency && newCurrency != baseCurrency {
			rate = try await exchangeRateManager.exchangeRate(from: baseCurrency, to: newCurrency)
			adjustedAmount = Int(Double(adjustedAmount) * rate)
		}

		return Money(currency: newCurrency, amount: adjustedAmount)
	}
}

