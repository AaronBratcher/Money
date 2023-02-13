import Foundation

public extension String {
	var currencyValue: Int {
		let currency = Currency(rawValue: Locale.current.currencyCode ?? "USD") ?? .usDollar
		return currencyValue(decimalPrecision: currency.details.decimalPrecision)
	}

	func currencyValue(decimalPrecision: Int) -> Int {
		let decimalSeparator = Locale.current.decimalSeparator!
		let groupingSeparator = Locale.current.groupingSeparator!

		var inputString = self
		var negative = false

		// remove groupingSeparator from inputString
		let groupingInput = CharacterSet(charactersIn: groupingSeparator)
		var commaRange = inputString.rangeOfCharacter(from: groupingInput)

		while commaRange != nil {
			inputString = inputString.replacingCharacters(in: commaRange!, with: "")
			commaRange = inputString.rangeOfCharacter(from: groupingInput)
		}

		let invalidCharacters = CharacterSet(charactersIn: "0123456789\(decimalSeparator)-").inverted

		if inputString.rangeOfCharacter(from: invalidCharacters) != nil {
			return 0
		}

		let amountParts = inputString.components(separatedBy: decimalSeparator)
		var value = Int(amountParts[0]) ?? 0
		if value < 0 {
			value *= -1
			negative = true
		}

		value *= (10.pow(toPower: maxDecimalPrecision))
		let decimalPrecision = decimalPrecision
		if amountParts.count > 1 && decimalPrecision > 0 {
			var decimal = amountParts[1]
			decimal = String(decimal.prefix(decimalPrecision))
			decimal += String(repeating: "0", count: maxDecimalPrecision)
			decimal = String(decimal.prefix(maxDecimalPrecision))

			value += Int(decimal) ?? 0
		}

		if negative {
			value *= -1
		}

		return value
	}
}
