//
//  GardenViewModel.swift
//  PlantSentinel (formerly FrostSentinel)
//
//  Orchestrates the three layers: REST forecast (Swift async), Core Data
//  cache (offline-first), and the legacy Objective-C risk calculator.
//
//  Two questions, one evening: does anything need covering tonight, and does
//  anything need water before tomorrow?
//

import Foundation
import Combine
import CoreData

/// The answer for one plant this evening: its frost verdict for tonight and
/// its heat verdict for tomorrow, folded into one piece of advice.
struct PlantVerdict: Identifiable {
    let id: UUID
    let plantName: String
    let frostRisk: FSFrostRisk
    let heatRisk: FSHeatRisk
    let advice: String
    let frostMarginC: Double
    let heatMarginC: Double

    /// How urgent this plant is overall — used for sorting and row color.
    var severity: Int { max(frostRisk.rawValue, heatRisk.rawValue) }
}

@MainActor
final class GardenViewModel: ObservableObject {

    enum DataSource: Equatable {
        case live
        case cache(fetchedAt: Date)
        case none
    }

    @Published private(set) var verdicts: [PlantVerdict] = []
    @Published private(set) var tonightMinC: Double?
    @Published private(set) var tomorrowMaxC: Double?
    @Published private(set) var dataSource: DataSource = .none
    @Published private(set) var errorMessage: String?

    private let store: GardenStore
    private let forecastService: ForecastFetching
    private let calculator = FSFrostCalculator()

    init(store: GardenStore, forecastService: ForecastFetching? = nil) {
        self.store = store
        self.forecastService = forecastService ?? OpenMeteoForecastService()
    }

    /// Offline-first refresh:
    /// 1. Try the network; on success, cache the result.
    /// 2. On failure, fall back to the Core Data cache and say so —
    ///    a slightly stale answer beats no answer when frost is coming.
    func refresh(latitude: Double, longitude: Double) async {
        errorMessage = nil

        do {
            let days = try await forecastService.forecast(
                latitude: latitude, longitude: longitude, days: 3
            )
            try store.replaceForecastCache(with: days)
            dataSource = .live
            evaluate(days: days)
        } catch {
            do {
                let cached = try store.cachedForecast()
                if cached.isEmpty {
                    dataSource = .none
                    errorMessage = "Couldn't reach the forecast service, and no cached forecast exists yet."
                } else {
                    let fetchedAt = (try? store.cacheFetchedAt()) ?? nil
                    dataSource = .cache(fetchedAt: fetchedAt ?? .distantPast)
                    evaluate(days: cached)
                }
            } catch {
                dataSource = .none
                errorMessage = "Couldn't load the cached forecast: \(error.localizedDescription)"
            }
        }
    }

    /// Re-runs verdicts without refetching (e.g. after adding a plant).
    func reevaluate() {
        if let cached = try? store.cachedForecast(), !cached.isEmpty {
            evaluate(days: cached)
        }
    }

    // MARK: - Verdicts

    /// Frost is judged on tonight's minimum (day 0). Heat is judged on
    /// tomorrow's maximum (day 1) because the whole point is acting the night
    /// before — if the forecast only has one day, today's max stands in.
    private func evaluate(days: [DayForecast]) {
        guard let today = days.first else {
            verdicts = []
            tonightMinC = nil
            tomorrowMaxC = nil
            return
        }

        let tomorrow = days.dropFirst().first ?? today

        tonightMinC = today.minTempC
        tomorrowMaxC = tomorrow.maxTempC

        let plants = (try? store.plants()) ?? []
        verdicts = plants.map { plant in
            // Legacy Objective-C layer doing the domain math, bridged into Swift.
            let frostRisk = calculator.risk(
                forForecastMinCelsius: today.minTempC,
                toleranceCelsius: plant.toleranceCelsius
            )
            let heatRisk = calculator.heatRisk(
                forForecastMaxCelsius: tomorrow.maxTempC,
                heatToleranceCelsius: plant.heatToleranceCelsius
            )
            return PlantVerdict(
                id: plant.id,
                plantName: plant.name,
                frostRisk: frostRisk,
                heatRisk: heatRisk,
                advice: Self.combinedAdvice(
                    frostRisk: frostRisk, heatRisk: heatRisk,
                    plantName: plant.name, calculator: calculator
                ),
                frostMarginC: calculator.margin(
                    forForecastMinCelsius: today.minTempC,
                    toleranceCelsius: plant.toleranceCelsius
                ),
                heatMarginC: calculator.margin(
                    forForecastMaxCelsius: tomorrow.maxTempC,
                    heatToleranceCelsius: plant.heatToleranceCelsius
                )
            )
        }
        // Most at-risk plants first: the answer you need is at the top.
        .sorted {
            if $0.severity != $1.severity { return $0.severity > $1.severity }
            if $0.frostRisk.rawValue != $1.frostRisk.rawValue {
                return $0.frostRisk.rawValue > $1.frostRisk.rawValue
            }
            return $0.plantName < $1.plantName
        }
    }

    /// One line per plant. Whatever needs doing is said; when both sides need
    /// doing, tonight's action (covering) comes before tomorrow's (watering).
    /// All user-facing wording stays in the legacy calculator so both risk
    /// vocabularies live in one place.
    private static func combinedAdvice(
        frostRisk: FSFrostRisk,
        heatRisk: FSHeatRisk,
        plantName: String,
        calculator: FSFrostCalculator
    ) -> String {
        var parts: [String] = []
        if frostRisk != FSFrostRisk.none {
            parts.append(calculator.advice(for: frostRisk, plantName: plantName))
        }
        if heatRisk != FSHeatRisk.none {
            parts.append(calculator.advice(forHeatRisk: heatRisk, plantName: plantName))
        }
        if parts.isEmpty {
            return calculator.advice(for: FSFrostRisk.none, plantName: plantName)
        }
        return parts.joined(separator: " ")
    }
}
