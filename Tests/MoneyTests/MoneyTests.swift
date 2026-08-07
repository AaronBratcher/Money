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

		// Regression test: a negative amount whose integer part is zero
		// previously lost its sign (Int("-0") == 0 is never < 0).
		money = Money(currency: .usDollar, amount: "-0.50")
		XCTAssertEqual(money.amount, -5000)
		XCTAssertEqual(money.amountString, "-0.50")

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

	func testDoubleInitLeadingZeroFraction() {
		// Regression test: the fractional digits must not lose a leading zero
		// (e.g. $0.05 previously came out as $0.50).
		let nickel = Money(currency: .usDollar, amount: 0.05)
		XCTAssertEqual(nickel.amount, 500)
		XCTAssertEqual(nickel.amountString, "0.05")

		let money = Money(currency: .usDollar, amount: 100.05)
		XCTAssertEqual(money.amount, 1000500)
		XCTAssertEqual(money.amountString, "100.05")
	}

	func testDoubleInitNegative() {
		// Regression test: negative fractional Double amounts previously lost
		// both their sign and magnitude (e.g. -0.5 came out as -0.05).
		let money = Money(currency: .usDollar, amount: -0.5)
		XCTAssertEqual(money.amount, -5000)
		XCTAssertEqual(money.amountString, "-0.50")

		let larger = Money(currency: .usDollar, amount: -1.99)
		XCTAssertEqual(larger.amount, -19900)
		XCTAssertEqual(larger.amountString, "-1.99")
	}

	func testDoubleInitZeroDecimalPrecision() {
		// Japanese Yen has no fractional units; a fractional Double amount
		// should simply drop the fraction rather than misbehave.
		let money = Money(currency: .japaneseYen, amount: 23.6)
		XCTAssertEqual(money.amount, 23 * baseMultiplier)
		XCTAssertEqual(money.amountString, "23")
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
		XCTAssertEqual(Double(value) / 10000, value.currencyAmount)

		// Regression test: currencyAmount previously divided as Int before
		// converting to Double, truncating any fractional/sub-unit value.
		XCTAssertEqual(12345.currencyAmount, 1.2345)
	}
}
