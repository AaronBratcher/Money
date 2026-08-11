//
//  CurrencyTests.swift
//  
//
//  Created by Aaron Bratcher on 4/20/22.
//

import XCTest
@testable import Money

class CurrencyTests: XCTestCase {
	func testPowZero() throws {
		// Regression test: x^0 must be 1, not 0.
		XCTAssertEqual(10.pow(toPower: 0), 1)
		XCTAssertEqual(10.pow(toPower: 1), 10)
	}

    func testCurrencies() throws {
		 var codes: [String] = []

		 for currency in Currency.allCases {
			 XCTAssertNotNil(currency.rawValue)
			 codes.append(currency.rawValue)
		 }

		 for code in codes {
			 XCTAssertNotNil(Currency(rawValue: code))
		 }
	 }
}
