//
//  ForecastService.swift
//  PlantSentinel (formerly FrostSentinel)
//
//  Fetches daily minimum and maximum temperatures from the Open-Meteo REST API.
//  No API key, no account — consistent with the app's no-tracking posture.
//
//  The minimum answers the frost question ("cover it tonight?"); the maximum
//  answers the heat question ("water it tonight, before tomorrow?"). Same
//  endpoint, same request — one extra field made the app multi-season.
//

import Foundation

/// One day's forecast: the overnight minimum and the daytime maximum.
struct DayForecast: Equatable {
    let date: Date
    let minTempC: Double
    let maxTempC: Double
}

/// Abstraction over the forecast source so the view model can be tested
/// without touching the network. (This protocol is also the seam a future
/// Android port re-implements — keep platform types out of it.)
protocol ForecastFetching {
    func forecast(
        latitude: Double,
        longitude: Double,
        days: Int
    ) async throws -> [DayForecast]
}

enum ForecastError: Error, Equatable {
    case badURL
    case badResponse(statusCode: Int)
    case malformedPayload
}

/// Live Open-Meteo implementation.
///
/// Endpoint shape:
/// https://api.open-meteo.com/v1/forecast?latitude=..&longitude=..
///   &daily=temperature_2m_min,temperature_2m_max&timezone=auto&forecast_days=N
struct OpenMeteoForecastService: ForecastFetching {
    var session: URLSession = .shared

    func forecast(
        latitude: Double,
        longitude: Double,
        days: Int
    ) async throws -> [DayForecast] {
        guard let url = makeURL(latitude: latitude, longitude: longitude, days: days) else {
            throw ForecastError.badURL
        }

        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw ForecastError.badResponse(statusCode: http.statusCode)
        }

        return try Self.parse(data)
    }

    func makeURL(latitude: Double, longitude: Double, days: Int) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "daily", value: "temperature_2m_min,temperature_2m_max"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: String(days)),
        ]
        return components?.url
    }

    // MARK: - Decoding

    /// Open-Meteo returns parallel arrays; this zips them into typed values.
    /// Static and pure so it is directly unit-testable against fixtures.
    static func parse(_ data: Data) throws -> [DayForecast] {
        let decoded: OpenMeteoResponse
        do {
            decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
        } catch {
            throw ForecastError.malformedPayload
        }

        guard decoded.daily.time.count == decoded.daily.temperature2mMin.count,
              decoded.daily.time.count == decoded.daily.temperature2mMax.count else {
            throw ForecastError.malformedPayload
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")

        return try zip(
            decoded.daily.time,
            zip(decoded.daily.temperature2mMin, decoded.daily.temperature2mMax)
        ).map { day, temps in
            guard let date = formatter.date(from: day) else {
                throw ForecastError.malformedPayload
            }
            return DayForecast(date: date, minTempC: temps.0, maxTempC: temps.1)
        }
    }
}

// MARK: - DTOs

struct OpenMeteoResponse: Decodable {
    let daily: Daily

    struct Daily: Decodable {
        let time: [String]
        let temperature2mMin: [Double]
        let temperature2mMax: [Double]

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2mMin = "temperature_2m_min"
            case temperature2mMax = "temperature_2m_max"
        }
    }
}
