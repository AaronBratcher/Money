//
//  ExchangeRateManager.swift
//
//
//  Created by Aaron Bratcher on 4/18/22.
//

import Foundation
import Combine

enum MoneyError: Error {
	case needKey
	case download
	case parse
	case missingCurrency(String)
}

typealias ConversionMatrix = [Currency: Double]

public final actor ExchangeRateManager {
	private var conversionMatrix: ConversionMatrix = [:]
	private(set) var baseCurrency: Currency = .euro
	private var lastDownload: Date?
	private var subscriptions: Set<AnyCancellable> = []

	init(with matrix: ConversionMatrix? = nil, base: Currency? = .euro) {
		if let matrix = matrix {
			self.conversionMatrix = matrix
		}

		if let base = base {
			self.baseCurrency = base
		}
	}
    
	func exchangeRate(from currency: Currency, to newCurrency: Currency) async throws -> Double {
		let hoursElapsed: Int
		if let lastDownload = lastDownload {
			hoursElapsed = Int(lastDownload.timeIntervalSince(Date()) / 14400)
		} else {
			hoursElapsed = 0
		}

		if conversionMatrix.isEmpty || hoursElapsed > 4 {
			try await downloadMatrix()
			lastDownload = Date()
		}

		let rate: Double
		guard let currencyRate = conversionMatrix[currency] else {
			throw MoneyError.missingCurrency(newCurrency.rawValue)
		}

		guard let newCurrencyRate = conversionMatrix[newCurrency] else {
			throw MoneyError.missingCurrency(newCurrency.rawValue)
		}

		if newCurrency == baseCurrency {
			rate = 1 / currencyRate
		} else {
			rate = newCurrencyRate
		}

		return rate
	}

	private func downloadMatrix() async throws {
		let results = await downloadMatrixBridge()
		switch results {
		case .success(let response):
			guard response.success else { throw MoneyError.download }
			baseCurrency = response.base
			conversionMatrix = response.rates
		case .failure(let error):
			throw error
		}
	}

	private func downloadMatrixBridge() async -> ExchangeResults {
		await withCheckedContinuation { continuation in
			downloadConversionMatrix { results in
				continuation.resume(returning: results)
			}
		}
	}

	typealias ExchangeResults = Result<Response, MoneyError>
	private func downloadConversionMatrix(completion: @escaping (ExchangeResults) -> Void) {
		do {
			try CurrencyExchange.retrieveLatest()
				.sink(receiveCompletion: { (apiCompletion) in
				switch apiCompletion {
				case .failure(_):
					completion(.failure(.download))
				case .finished:
					break
				}
			}) { response in
				completion(.success(response))
			}
				.store(in: &subscriptions)
		} catch {
			completion(.failure(.download))
			return

		}
	}
}

struct Agent {
	struct Response<T> {
		let value: T
		let response: URLResponse
	}

	func run<T: Decodable>(_ request: URLRequest, _ decoder: JSONDecoder = JSONDecoder()) -> AnyPublisher<T, Error> {
		return URLSession.shared
			.dataTaskPublisher(for: request)
			.map(\.data)
			.receive(on: DispatchQueue.main)
			.decode(type: T.self, decoder: JSONDecoder())
			.eraseToAnyPublisher()
	}
}

enum CurrencyExchange {
	static let agent = Agent()
	static let base = "http://data.fixer.io/api/"
	static let latest = "latest"
	static let accessKey = ""

}

extension CurrencyExchange {
	static func retrieveLatest() throws -> AnyPublisher<Response, Error> {
		guard accessKey.isNotEmpty else { throw MoneyError.needKey }

		let currencies = Currency.allCases.map { $0.rawValue }.joined(separator: ",")
		var urlString = CurrencyExchange.base
		urlString += CurrencyExchange.latest
		urlString += "?access_key=" + CurrencyExchange.accessKey
		urlString += "&symbols=" + currencies
		urlString += "&format=1"
		guard let url = URL(string: urlString) else {
			throw MoneyError.download
		}

		let request = URLRequest(url: url)
		return agent.run(request)
	}

	static func retrieve(for: Date) throws -> AnyPublisher<Response, Error> {
		guard let base = URL(string: CurrencyExchange.base) else {
			throw MoneyError.download
		}
		let request = URLRequest(url: base.appendingPathComponent(CurrencyExchange.accessKey))
		return agent.run(request)
	}
}
