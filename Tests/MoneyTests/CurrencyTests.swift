//
//  CurrencyTests.swift
//  
//
//  Created by Aaron Bratcher on 4/20/22.
//

import XCTest
@testable import Money

class CurrencyTests: XCTestCase {
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
