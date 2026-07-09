//
//  ForecastServiceTests.swift
//  FrostSentinelTests
//
//  Tests the Open-Meteo response parsing against fixtures — no network.
//

import Foundation
import Testing
@testable import FrostSentinel

struct ForecastServiceTests {

    private let validPayload = """
    {
      "daily": {
        "time": ["2026-07-06", "2026-07-07", "2026-07-08"],
        "temperature_2m_min": [4.2, -1.5, 0.0],
        "temperature_2m_max": [22.0, 31.5, 38.0]
      }
    }
    """.data(using: .utf8)!

    @Test func parsesParallelArraysIntoTypedDays() throws {
        let days = try OpenMeteoForecastService.parse(validPayload)
        #expect(days.count == 3)
        #expect(days[0].minTempC == 4.2)
        #expect(days[0].maxTempC == 22.0)
        #expect(days[1].minTempC == -1.5)
        #expect(days[2].maxTempC == 38.0)
        #expect(days[0].date < days[1].date)
    }

    @Test func mismatchedMinArrayLengthIsRejected() {
        let bad = """
        {"daily": {"time": ["2026-07-06", "2026-07-07"],
                   "temperature_2m_min": [4.2],
                   "temperature_2m_max": [22.0, 24.0]}}
        """.data(using: .utf8)!

        #expect(throws: ForecastError.malformedPayload) {
            _ = try OpenMeteoForecastService.parse(bad)
        }
    }

    @Test func mismatchedMaxArrayLengthIsRejected() {
        let bad = """
        {"daily": {"time": ["2026-07-06", "2026-07-07"],
                   "temperature_2m_min": [4.2, 3.0],
                   "temperature_2m_max": [22.0]}}
        """.data(using: .utf8)!

        #expect(throws: ForecastError.malformedPayload) {
            _ = try OpenMeteoForecastService.parse(bad)
        }
    }

    @Test func missingMaxFieldIsRejected() {
        // A v1-shaped payload (min only) must fail loudly, not half-parse.
        let v1 = """
        {"daily": {"time": ["2026-07-06"], "temperature_2m_min": [4.2]}}
        """.data(using: .utf8)!

        #expect(throws: ForecastError.malformedPayload) {
            _ = try OpenMeteoForecastService.parse(v1)
        }
    }

    @Test func garbageJSONIsRejected() {
        let garbage = "{not json".data(using: .utf8)!
        #expect(throws: ForecastError.malformedPayload) {
            _ = try OpenMeteoForecastService.parse(garbage)
        }
    }

    @Test func unparseableDateIsRejected() {
        let badDate = """
        {"daily": {"time": ["tomorrow-ish"],
                   "temperature_2m_min": [4.2],
                   "temperature_2m_max": [20.0]}}
        """.data(using: .utf8)!

        #expect(throws: ForecastError.malformedPayload) {
            _ = try OpenMeteoForecastService.parse(badDate)
        }
    }

    @Test func urlIncludesCoordinatesAndBothDailyFields() throws {
        let service = OpenMeteoForecastService()
        let url = try #require(service.makeURL(latitude: 40.76, longitude: -111.89, days: 3))
        let query = try #require(url.query())

        #expect(url.host() == "api.open-meteo.com")
        #expect(query.contains("latitude=40.76"))
        #expect(query.contains("longitude=-111.89"))
        #expect(query.contains("temperature_2m_min"))
        #expect(query.contains("temperature_2m_max"))
        #expect(query.contains("forecast_days=3"))
    }
}
