import XCTest
import Foundation
@testable import Money

final class MoneyTests: XCTestCase {
	func testUSD() {
		var money = Money(currency: .usDollar, amount: "1")
		XCTAssertEqual(money.amount, 1 * baseMultiplier)

		var amountString = money.amountString
		XCTAssertEqual(amountString, "1.00")

		money = Money(currency: .usDollar, amount: "23.23")
		XCTAssertEqual(money.amount, 23 * baseMultiplier + 23.adjustedDecimal)

		amountString = money.amountString
		XCTAssertEqual(amountString, "23.23")

		money = Money(currency: .usDollar, amount: "-1")
		XCTAssertEqual(money.amount, -1 * baseMultiplier)

		money = Money(currency: .usDollar, amount: 100 * baseMultiplier)
		XCTAssertEqual(money.amountString, "100.00")

		money = Money(currency: .usDollar, amount: 1000 * baseMultiplier)
		XCTAssertEqual(money.amountString, "1,000.00")

		money = Money(currency: .usDollar, amount: 1000 * baseMultiplier + 23.adjustedDecimal)
		XCTAssertEqual(money.amountString, "1,000.23")

		XCTAssertEqual(money.amount.currencyString(useThousandsSeparator: true, keepDecimal: false, using: money.currency),"1,000")
		XCTAssertEqual(money.amount.currencyString(useThousandsSeparator: false, keepDecimal: true, using: money.currency),"1000.23")
		XCTAssertEqual(money.amount.currencyString(useThousandsSeparator: false, keepDecimal: false, using: money.currency),"1000")
	}

	func testInit() {
		let money = Money(currency: .usDollar, amount: 100.25)
		XCTAssertEqual(money.amountString, "100.25")
	}

	func testJPY() {
		let money = Money(currency: .japaneseYen, amount: "23.23")
		XCTAssertEqual(money.amount, 23 * baseMultiplier)

		let amountString = money.amountString
		XCTAssertEqual(amountString, "23")
	}

	func testIQD() {
		let money = Money(currency: .iraqiDinar, amount: "23.234")
		XCTAssertEqual(money.amount, 23 * baseMultiplier + 234.adjustedDecimal)

		let amountString = money.amountString
		XCTAssertEqual(amountString, "23.234")

	}

	func testCurrencyValue() {
		let value = 100250000
		XCTAssertEqual(Double(value / 10000), value.currencyAmount)
	}
}
