//
//  ExchangeTests.swift
//
//
//  Created by Aaron Bratcher on 4/18/22.
//

import XCTest
@testable import Money

class ExchangeTests: XCTestCase {
	let jsonString = """
{
  "success":true,
  "timestamp":1650541996,
  "base":"EUR",
  "date":"2022-04-21",
  "rates":{
	 "AUD":1.464119,
	 "BHD":0.410136,
	 "CAD":1.35954,
	 "CHF":1.033095,
	 "CNY":7.01749,
	 "EUR":1,
	 "GBP":0.834507,
	 "HKD":8.534674,
	 "IQD":1590.319831,
	 "JOD":0.77133,
	 "JPY":139.453637,
	 "KYD":0.908091,
	 "KWD":0.33214,
	 "MYR":4.668432,
	 "NZD":1.604043,
	 "OMR":0.418877,
	 "SEK":10.257698,
	 "USD":1.08795
  }
}
"""

	var conversionMatrix: ConversionMatrix = [:]

	override func setUpWithError() throws {
		let response = try XCTUnwrap(exchangeResponse())
		conversionMatrix = response.rates
	}

	private func exchangeResponse() throws -> Response? {
		let jsonData = try XCTUnwrap(jsonString.data(using: .utf8))
		return try JSONDecoder().decode(Response.self, from: jsonData)
	}

	func testResponse() throws {
		let response = try XCTUnwrap(exchangeResponse())
		XCTAssertEqual(response.base, Currency.euro)
		XCTAssertEqual(response.rates[.usDollar], 1.08795)
	}

	func testSimpleConversion() async throws {
		let exchangeRateManager = ExchangeRateManager(with: conversionMatrix, base: .euro)

		let usd = Money(currency: .usDollar, amount: "1,000.00")
        let eur = try await usd.convert(to: .euro, using: exchangeRateManager)

		XCTAssertEqual(eur.amountString, "919.15")
	}

	func testSimpleReverseConversion() async throws {
		let exchangeRateManager = ExchangeRateManager(with: conversionMatrix, base: .euro)

		let eur = Money(currency: .euro, amount: "1,000.00")
		let usd = try await eur.convert(to: .usDollar, using: exchangeRateManager)

		XCTAssertEqual(usd.amountString, "1,087.95")
	}

	func testJOD2USD() async throws {
		let exchangeRateManager = ExchangeRateManager(with: conversionMatrix, base: .euro)

		let jod = Money(currency: .jordanDinar, amount: "1,000")
		let usd = try await jod.convert(to: .usDollar, using: exchangeRateManager)

		XCTAssertEqual(usd.amountString, "1,410.48")
	}

	func testJPY2CNY() async throws {
		let exchangeRateManager = ExchangeRateManager(with: conversionMatrix, base: .euro)

		let jpn = Money(currency: .japaneseYen, amount: "1000")
		let cny = try await jpn.convert(to: .chineseRenminbi, using: exchangeRateManager)

		XCTAssertEqual(cny.amountString, "50.32")
	}
}
