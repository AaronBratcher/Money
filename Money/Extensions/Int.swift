import Foundation

public extension Int {
	var currencyAmount: Double {
		return Double(self) / Double(10.pow(toPower: maxDecimalPrecision))
	}

	var currencyString: String {
		currencyString(useThousandsSeparator: true, keepDecimal: true, using: Currency(rawValue: Locale.current.currencyCode ?? "USD") ?? .usDollar)
	}

	func currencyString(useThousandsSeparator: Bool = true, keepDecimal: Bool = true, using currency: Currency = .usDollar) -> String {
		let amount = self
		let decimalSeparator = Locale.current.decimalSeparator!
		let groupingSeparator = Locale.current.groupingSeparator!

		var amountString = "\(abs(amount))"

		var length = amountString.count

		if length < maxDecimalPrecision {
			amountString = String(repeating: "0", count: maxDecimalPrecision - length) + amountString
			length = maxDecimalPrecision
		}
		let decimalPrecision = currency.details.decimalPrecision
		var decimalPortion = String(amountString.suffix(maxDecimalPrecision))
		decimalPortion = String(decimalPortion.prefix(decimalPrecision))

		var formattedValue = ""
		if keepDecimal && decimalPrecision > 0 {
			formattedValue = decimalSeparator + decimalPortion
		}
		amountString = String(amountString.prefix(amountString.count - maxDecimalPrecision))
		if amountString.isEmpty {
			amountString = "0"
		}

		if length > 2 {
			if !useThousandsSeparator {
				formattedValue = amountString + formattedValue
			} else {
				length = amountString.count
				while length > 0 {
					if length > 3 {
						formattedValue = groupingSeparator + amountString.suffix(3) + formattedValue
						amountString = String(amountString.prefix(amountString.count - 3))
					} else {
						formattedValue = amountString + formattedValue
						amountString = ""
					}

					length = amountString.count
				}
			}
		} else {
			formattedValue = "0" + formattedValue
		}

		if amount < 0 && formattedValue != "0" {
			formattedValue = "-" + formattedValue
		}

		return formattedValue
	}
}

extension Int {
	func pow(toPower: Int) -> Int {
		guard toPower >= 0 else { return 0 }
		return Array(repeating: self, count: toPower).reduce(1, *)
	}
}

extension Int {
	var adjustedDecimal: Int {
		var textValue = "\(self)"
		textValue += String(repeating: "0", count: maxDecimalPrecision - textValue.count)
		return Int(textValue)!
	}
}

