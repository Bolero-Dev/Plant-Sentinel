//
//  GardenViewModelTests.swift
//  FrostSentinelTests
//
//  Integration tests across all three layers: a mocked REST service,
//  a real in-memory Core Data stack, and the bridged Objective-C calculator.
//

import Foundation
import Testing
@testable import FrostSentinel

// MARK: - Mock forecast service

struct MockForecastService: ForecastFetching {
    var result: Result<[DayForecast], Error>

    func forecast(latitude: Double, longitude: Double, days: Int) async throws -> [DayForecast] {
        try result.get()
    }
}

private func day(min minTempC: Double, max maxTempC: Double = 20, daysFromNow: Int = 0) -> DayForecast {
    DayForecast(
        date: Calendar.current.date(byAdding: .day, value: daysFromNow, to: .now)!,
        minTempC: minTempC,
        maxTempC: maxTempC
    )
}

// MARK: - Tests

@MainActor
struct GardenViewModelTests {

    private func makeStore() -> GardenStore {
        GardenStore(context: PersistenceController(inMemory: true).viewContext)
    }

    @Test func liveForecastProducesVerdictsSortedBySeverity() async throws {
        let store = makeStore()
        try store.addPlant(name: "Basil", toleranceCelsius: 5)      // tender
        try store.addPlant(name: "Lavender", toleranceCelsius: -15) // hardy

        let viewModel = GardenViewModel(
            store: store,
            forecastService: MockForecastService(result: .success([day(min: 1.0)]))
        )
        await viewModel.refresh(latitude: 0, longitude: 0)

        #expect(viewModel.dataSource == .live)
        #expect(viewModel.tonightMinC == 1.0)
        #expect(viewModel.verdicts.count == 2)

        // Basil (1.0 vs 5.0 tolerance = frost risk) must sort above Lavender (safe).
        #expect(viewModel.verdicts.first?.plantName == "Basil")
        #expect(viewModel.verdicts.first?.frostRisk == .frost)
        #expect(viewModel.verdicts.last?.frostRisk == FSFrostRisk.none)
    }

    @Test func heatIsJudgedOnTomorrowsHighNotTodays() async throws {
        let store = makeStore()
        try store.addPlant(name: "Lettuce", toleranceCelsius: -2, heatToleranceCelsius: 27)

        // Mild today, brutal tomorrow — the whole point is warning tonight.
        let viewModel = GardenViewModel(
            store: store,
            forecastService: MockForecastService(result: .success([
                day(min: 12, max: 24),
                day(min: 15, max: 33, daysFromNow: 1),
            ]))
        )
        await viewModel.refresh(latitude: 0, longitude: 0)

        #expect(viewModel.tomorrowMaxC == 33)
        let verdict = try #require(viewModel.verdicts.first)
        #expect(verdict.heatRisk == .scorch) // 33 vs 27 tolerance, 6 over > 4 scorch margin
        #expect(verdict.advice.contains("Water"))
        #expect(verdict.frostRisk == FSFrostRisk.none)
    }

    @Test func singleDayForecastFallsBackToTodaysHigh() async throws {
        let store = makeStore()
        try store.addPlant(name: "Spinach", toleranceCelsius: -6, heatToleranceCelsius: 26)

        let viewModel = GardenViewModel(
            store: store,
            forecastService: MockForecastService(result: .success([day(min: 10, max: 28)]))
        )
        await viewModel.refresh(latitude: 0, longitude: 0)

        #expect(viewModel.tomorrowMaxC == 28)
        #expect(viewModel.verdicts.first?.heatRisk == .heat)
    }

    @Test func plantAtRiskFromBothEndsGetsBothPiecesOfAdvice() async throws {
        let store = makeStore()
        // Desert spring: freezing night, scorching afternoon.
        try store.addPlant(name: "Seedlings", toleranceCelsius: 5, heatToleranceCelsius: 28)

        let viewModel = GardenViewModel(
            store: store,
            forecastService: MockForecastService(result: .success([
                day(min: 1, max: 20),
                day(min: 8, max: 34, daysFromNow: 1),
            ]))
        )
        await viewModel.refresh(latitude: 0, longitude: 0)

        let verdict = try #require(viewModel.verdicts.first)
        #expect(verdict.frostRisk == .frost)
        #expect(verdict.heatRisk == .scorch)
        #expect(verdict.severity == 3)
        // Tonight's action first, tomorrow's second.
        #expect(verdict.advice.contains("Cover"))
        #expect(verdict.advice.contains("Water"))
        let coverIndex = try #require(verdict.advice.range(of: "Cover")?.lowerBound)
        let waterIndex = try #require(verdict.advice.range(of: "Water")?.lowerBound)
        #expect(coverIndex < waterIndex)
    }

    @Test func heatOnlyRiskOutranksSafePlantsInSorting() async throws {
        let store = makeStore()
        try store.addPlant(name: "Succulent", toleranceCelsius: 2, heatToleranceCelsius: 40)
        try store.addPlant(name: "Lettuce", toleranceCelsius: -2, heatToleranceCelsius: 27)

        let viewModel = GardenViewModel(
            store: store,
            forecastService: MockForecastService(result: .success([
                day(min: 10, max: 25),
                day(min: 14, max: 30, daysFromNow: 1),
            ]))
        )
        await viewModel.refresh(latitude: 0, longitude: 0)

        // Lettuce is heat-stressed (30 vs 27); succulent is fine both ways.
        #expect(viewModel.verdicts.first?.plantName == "Lettuce")
        #expect(viewModel.verdicts.first?.heatRisk == .heat)
        #expect(viewModel.verdicts.last?.severity == 0)
    }

    @Test func successfulFetchPopulatesTheCacheWithBothTemperatures() async throws {
        let store = makeStore()
        let viewModel = GardenViewModel(
            store: store,
            forecastService: MockForecastService(result: .success([
                day(min: 2.5, max: 21.0),
                day(min: 3.0, max: 35.5, daysFromNow: 1),
            ]))
        )
        await viewModel.refresh(latitude: 0, longitude: 0)

        let cached = try store.cachedForecast()
        #expect(cached.count == 2)
        #expect(cached.first?.minTempC == 2.5)
        #expect(cached.first?.maxTempC == 21.0)
        #expect(cached.last?.maxTempC == 35.5)
    }

    @Test func networkFailureFallsBackToCache() async throws {
        let store = makeStore()
        try store.addPlant(name: "Basil", toleranceCelsius: 5)
        try store.replaceForecastCache(with: [day(min: -1.0)])

        let viewModel = GardenViewModel(
            store: store,
            forecastService: MockForecastService(result: .failure(ForecastError.badResponse(statusCode: 500)))
        )
        await viewModel.refresh(latitude: 0, longitude: 0)

        guard case .cache = viewModel.dataSource else {
            Issue.record("Expected cache fallback, got \(viewModel.dataSource)")
            return
        }
        #expect(viewModel.tonightMinC == -1.0)
        #expect(viewModel.verdicts.first?.frostRisk == .hardFreeze)
    }

    @Test func networkFailureWithEmptyCacheReportsError() async {
        let viewModel = GardenViewModel(
            store: makeStore(),
            forecastService: MockForecastService(result: .failure(ForecastError.badURL))
        )
        await viewModel.refresh(latitude: 0, longitude: 0)

        #expect(viewModel.dataSource == .none)
        #expect(viewModel.errorMessage != nil)
        #expect(viewModel.verdicts.isEmpty)
    }

    @Test func refetchReplacesStaleCacheInsteadOfAppending() async throws {
        let store = makeStore()
        try store.replaceForecastCache(with: [
            day(min: 9), day(min: 8, daysFromNow: 1), day(min: 7, daysFromNow: 2),
        ])
        try store.replaceForecastCache(with: [day(min: 1)])

        let cached = try store.cachedForecast()
        #expect(cached.count == 1)
        #expect(cached.first?.minTempC == 1)
    }

    @Test func plantsPersistBothTolerances() throws {
        let store = makeStore()
        try store.addPlant(name: "Echinacea", toleranceCelsius: -20, heatToleranceCelsius: 34)

        let plants = try store.plants()
        #expect(plants.count == 1)
        #expect(plants.first?.name == "Echinacea")
        #expect(plants.first?.toleranceCelsius == -20)
        #expect(plants.first?.heatToleranceCelsius == 34)
    }

    @Test func plantsAddedWithoutHeatToleranceGetTheDefault() throws {
        // v1 call sites (and migrated v1 rows) must land on a sane default.
        let store = makeStore()
        try store.addPlant(name: "Mystery Gift Plant", toleranceCelsius: 0)

        let plants = try store.plants()
        #expect(plants.first?.heatToleranceCelsius == PersistenceController.defaultHeatToleranceCelsius)
    }
}
