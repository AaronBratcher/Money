//
//  Response.swift
//
//
//  Created by Aaron Bratcher on 4/18/22.
//

import Foundation

typealias ExchangeRates = [Currency: Double]

struct Response: Decodable {
	let success: Bool
	let base: Currency
	let rates: ExchangeRates

	private enum ResponseKey: String, CodingKey {
		case success, base, date, rates
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: ResponseKey.self)

		success = try container.decode(Bool.self, forKey: .success)
		base = try container.decode(Currency.self, forKey: .base)
		
		// Map from [String: Double] to [Currency: Double] to validate JSONDecoder.
		let rates = try container.decode([String: Double].self, forKey: .rates)
		self.rates = Dictionary(uniqueKeysWithValues: rates.compactMap { key, value in
			guard let currency = Currency(rawValue: key) else { return nil }
			return (currency, value)
		})
	}
}
