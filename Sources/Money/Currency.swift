//
//  Currency.swift
//  MoneyTrak
//
//  Created by Aaron Bratcher on 11/4/21.
//  Copyright © 2021 Aaron L Bratcher. All rights reserved.
//

import Foundation

public let maxDecimalPrecision = 4

public struct CurrencyDetails: Equatable, Codable {
	public let name: String
	public let alphabeticCode: String
	public let decimalPrecision: Int

	public static func == (lhs: Self, rhs: Self) -> Bool {
		return lhs.alphabeticCode == rhs.alphabeticCode
	}
}

public enum Currency: String, CaseIterable, Codable, Sendable {
	case australianDollar
	case bahrainiDinar
	case britishPound
	case canadianDollar
	case caymanIslandsDollar
	case chineseRenminbi
	case euro
	case hongKongDollar
	case iraqiDinar
	case japaneseYen
	case jordanDinar
	case kuwaitiDinar
	case malaysianRinggit
	case newZealandDollar
	case rialOmani
	case swedishKrona
	case swissFranc
	case usDollar
}

public extension Currency {
	var details: CurrencyDetails {
		switch self {
		case .australianDollar: return CurrencyDetails(name: "Australian Dollar", alphabeticCode: rawValue, decimalPrecision: 2)
		case .bahrainiDinar: return CurrencyDetails(name: "Bahraini Dinar", alphabeticCode: rawValue, decimalPrecision: 3)
		case .britishPound: return CurrencyDetails(name: "British Pound", alphabeticCode: rawValue, decimalPrecision: 2)
		case .canadianDollar: return CurrencyDetails(name: "Canadian Dollar", alphabeticCode: rawValue, decimalPrecision: 2)
		case .caymanIslandsDollar: return CurrencyDetails(name: "Cayman Islands Dollar", alphabeticCode: rawValue, decimalPrecision: 2)
		case .chineseRenminbi: return CurrencyDetails(name: "Chinese Renminbi", alphabeticCode: rawValue, decimalPrecision: 2)
		case .euro: return CurrencyDetails(name: "Euro", alphabeticCode: rawValue, decimalPrecision: 2)
		case .hongKongDollar: return CurrencyDetails(name: "Hong Kong Dollar", alphabeticCode: rawValue, decimalPrecision: 2)
		case .iraqiDinar: return CurrencyDetails(name: "Iraqi Dinar", alphabeticCode: rawValue, decimalPrecision: 3)
		case .japaneseYen: return CurrencyDetails(name: "Japanese Yen", alphabeticCode: rawValue, decimalPrecision: 0)
		case .jordanDinar: return CurrencyDetails(name: "Jordanian Dinar", alphabeticCode: rawValue, decimalPrecision: 3)
		case .kuwaitiDinar: return CurrencyDetails(name: "Kuwaiti Dinar", alphabeticCode: rawValue, decimalPrecision: 3)
		case .malaysianRinggit: return CurrencyDetails(name: "Malaysian Ringgit", alphabeticCode: rawValue, decimalPrecision: 2)
		case .newZealandDollar: return CurrencyDetails(name: "New Zealand Dollar", alphabeticCode: rawValue, decimalPrecision: 2)
		case .rialOmani: return CurrencyDetails(name: "Rial Omani", alphabeticCode: rawValue, decimalPrecision: 3)
		case .swedishKrona: return CurrencyDetails(name: "Swedish Krona", alphabeticCode: rawValue, decimalPrecision: 2)
		case .swissFranc: return CurrencyDetails(name: "Swiss Franc", alphabeticCode: rawValue, decimalPrecision: 2)
		case .usDollar: return CurrencyDetails(name: "US Dollar", alphabeticCode: rawValue, decimalPrecision: 2)
		}
	}
}

extension Currency: RawRepresentable {
	public init?(rawValue: String) {
		switch rawValue {
		case "AUD": self = .australianDollar
		case "BHD": self = .bahrainiDinar
		case "CAD": self = .canadianDollar
		case "CHF": self = .swissFranc
		case "CNY": self = .chineseRenminbi
		case "EUR": self = .euro
		case "GBP": self = .britishPound
		case "HKD": self = .hongKongDollar
		case "IQD": self = .iraqiDinar
		case "JOD": self = .jordanDinar
		case "JPY": self = .japaneseYen
		case "KYD": self = .caymanIslandsDollar
		case "KWD": self = .kuwaitiDinar
		case "MYR": self = .malaysianRinggit
		case "NZD": self = .newZealandDollar
		case "OMR": self = .rialOmani
		case "SEK": self = .swedishKrona
		case "USD": self = .usDollar
		default: return nil
		}
	}

	public var rawValue: String {
		switch self {
		case .australianDollar: return "AUD"
		case .bahrainiDinar: return "BHD"
		case .britishPound: return "GBP"
		case .canadianDollar: return "CAD"
		case .caymanIslandsDollar: return "KYD"
		case .chineseRenminbi: return "CNY"
		case .euro: return "EUR"
		case .hongKongDollar: return "HKD"
		case .iraqiDinar: return "IQD"
		case .japaneseYen: return "JPY"
		case .jordanDinar: return "JOD"
		case .kuwaitiDinar: return "KWD"
		case .malaysianRinggit: return "MYR"
		case .newZealandDollar: return "NZD"
		case .rialOmani: return "OMR"
		case .swissFranc: return "CHF"
		case .swedishKrona: return "SEK"
		case .usDollar: return "USD"
		}
	}
}
