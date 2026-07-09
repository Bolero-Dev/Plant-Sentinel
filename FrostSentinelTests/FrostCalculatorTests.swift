//
//  FrostCalculatorTests.swift
//  FrostSentinelTests
//
//  Exercises the legacy Objective-C calculator through the Swift bridge —
//  which is itself part of what these tests verify.
//
//  These tests are also the behavior spec for the risk engine: a future
//  Android port is correct when its implementation passes this same table.
//

import Testing
@testable import FrostSentinel

struct FrostCalculatorTests {

    private let calculator = FSFrostCalculator()

    // MARK: - Frost (tolerance 0°C tender annual against varying forecasts)

    @Test func comfortableMarginIsNoRisk() {
        #expect(calculator.risk(forForecastMinCelsius: 8, toleranceCelsius: 0) == .none)
    }

    @Test func withinWatchMarginIsWatch() {
        #expect(calculator.risk(forForecastMinCelsius: 2, toleranceCelsius: 0) == .watch)
    }

    @Test func exactlyAtToleranceIsFrost() {
        #expect(calculator.risk(forForecastMinCelsius: 0, toleranceCelsius: 0) == .frost)
    }

    @Test func slightlyBelowToleranceIsFrost() {
        #expect(calculator.risk(forForecastMinCelsius: -2, toleranceCelsius: 0) == .frost)
    }

    @Test func farBelowToleranceIsHardFreeze() {
        #expect(calculator.risk(forForecastMinCelsius: -5, toleranceCelsius: 0) == .hardFreeze)
    }

    @Test func hardyPlantShrugsOffAFrostyNight() {
        // A -15°C tolerant perennial on a -4°C night: no risk.
        #expect(calculator.risk(forForecastMinCelsius: -4, toleranceCelsius: -15) == .none)
    }

    @Test func marginIsForecastMinusTolerance() {
        #expect(calculator.margin(forForecastMinCelsius: 3, toleranceCelsius: -2) == 5)
        #expect(calculator.margin(forForecastMinCelsius: -6, toleranceCelsius: -2) == -4)
    }

    @Test func customMarginsAreRespected() {
        // The original two-parameter initializer must keep working —
        // extending the legacy class was not allowed to break its callers.
        let strict = FSFrostCalculator(watchMarginCelsius: 6, hardFreezeMarginCelsius: 1)
        #expect(strict.risk(forForecastMinCelsius: 5, toleranceCelsius: 0) == .watch)
        #expect(strict.risk(forForecastMinCelsius: -2, toleranceCelsius: 0) == .hardFreeze)
    }

    @Test func adviceMentionsThePlantByName() {
        let advice = calculator.advice(for: .frost, plantName: "Lavender")
        #expect(advice.contains("Lavender"))
        #expect(advice.contains("Cover"))
    }

    // MARK: - Heat (tolerance 35°C summer vegetable against varying forecasts)

    @Test func comfortableHeatMarginIsNoRisk() {
        #expect(calculator.heatRisk(forForecastMaxCelsius: 25, heatToleranceCelsius: 35) == .none)
    }

    @Test func withinHeatWatchMarginIsWatch() {
        #expect(calculator.heatRisk(forForecastMaxCelsius: 33, heatToleranceCelsius: 35) == .watch)
    }

    @Test func exactlyAtHeatToleranceIsHeat() {
        #expect(calculator.heatRisk(forForecastMaxCelsius: 35, heatToleranceCelsius: 35) == .heat)
    }

    @Test func slightlyAboveHeatToleranceIsHeat() {
        #expect(calculator.heatRisk(forForecastMaxCelsius: 38, heatToleranceCelsius: 35) == .heat)
    }

    @Test func farAboveHeatToleranceIsScorch() {
        #expect(calculator.heatRisk(forForecastMaxCelsius: 40, heatToleranceCelsius: 35) == .scorch)
    }

    @Test func heatLoverShrugsOffAWarmDay() {
        // A 40°C-tolerant succulent on a 33°C day: no risk.
        #expect(calculator.heatRisk(forForecastMaxCelsius: 33, heatToleranceCelsius: 40) == .none)
    }

    @Test func coolSeasonGreensFeelHeatEarly() {
        // Lettuce (27°C tolerance) on a 29°C day: already past its limit.
        #expect(calculator.heatRisk(forForecastMaxCelsius: 29, heatToleranceCelsius: 27) == .heat)
    }

    @Test func heatMarginIsToleranceMinusForecast() {
        // Positive = headroom, negative = over the limit; mirrors the frost margin.
        #expect(calculator.margin(forForecastMaxCelsius: 30, heatToleranceCelsius: 35) == 5)
        #expect(calculator.margin(forForecastMaxCelsius: 38, heatToleranceCelsius: 35) == -3)
    }

    @Test func customHeatMarginsAreRespected() {
        let strict = FSFrostCalculator(
            watchMarginCelsius: 3, hardFreezeMarginCelsius: 3,
            heatWatchMarginCelsius: 6, scorchMarginCelsius: 1
        )
        #expect(strict.heatRisk(forForecastMaxCelsius: 30, heatToleranceCelsius: 35) == .watch)
        #expect(strict.heatRisk(forForecastMaxCelsius: 37, heatToleranceCelsius: 35) == .scorch)
    }

    @Test func heatAdviceSaysToWaterTonight() {
        let advice = calculator.advice(forHeatRisk: .heat, plantName: "Lettuce")
        #expect(advice.contains("Lettuce"))
        #expect(advice.contains("Water"))
        #expect(advice.contains("tonight"))
    }

    @Test func scorchAdviceAddsShade() {
        let advice = calculator.advice(forHeatRisk: .scorch, plantName: "Spinach")
        #expect(advice.contains("Spinach"))
        #expect(advice.contains("shade"))
    }
}
