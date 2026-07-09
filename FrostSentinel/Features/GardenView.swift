//
//  GardenView.swift
//  PlantSentinel (formerly FrostSentinel)
//
//  The whole app on one screen: tonight's low, tomorrow's high, and a verdict
//  per plant. Deliberately quiet — no radar, no charts. Just the answer.
//

import SwiftUI

struct GardenView: View {
    @ObservedObject var viewModel: GardenViewModel
    let store: GardenStore

    // A location is two numbers, not a permission dialog. Default: Salt Lake City.
    @AppStorage("latitude") private var latitude: Double = 40.76
    @AppStorage("longitude") private var longitude: Double = -111.89

    @State private var plants: [PlantEntity] = []
    @State private var isShowingAddSheet = false
    @State private var isShowingLocationSheet = false

    var body: some View {
        NavigationStack {
            List {
                tonightSection
                verdictSection
            }
            .navigationTitle("Plant Sentinel")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Location") { isShowingLocationSheet = true }
                        .accessibilityIdentifier("garden.location")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingAddSheet = true
                    } label: {
                        Label("Add Plant", systemImage: "plus")
                    }
                    .accessibilityIdentifier("garden.addPlant")
                }
            }
            .sheet(isPresented: $isShowingAddSheet) {
                AddPlantSheet { name, coldTolerance, heatTolerance in
                    _ = try? store.addPlant(
                        name: name,
                        toleranceCelsius: coldTolerance,
                        heatToleranceCelsius: heatTolerance
                    )
                    reloadPlants()
                    viewModel.reevaluate()
                }
            }
            .sheet(isPresented: $isShowingLocationSheet) {
                LocationSheet(latitude: $latitude, longitude: $longitude) {
                    Task { await viewModel.refresh(latitude: latitude, longitude: longitude) }
                }
            }
            .refreshable {
                await viewModel.refresh(latitude: latitude, longitude: longitude)
            }
            .task {
                reloadPlants()
                await viewModel.refresh(latitude: latitude, longitude: longitude)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var tonightSection: some View {
        Section {
            if let min = viewModel.tonightMinC {
                HStack {
                    Text("Tonight's low")
                    Spacer()
                    Text(String(format: "%.1f °C", min))
                        .font(.title3.weight(.semibold))
                        .accessibilityIdentifier("garden.tonightLow")
                }
                if let max = viewModel.tomorrowMaxC {
                    HStack {
                        Text("Tomorrow's high")
                        Spacer()
                        Text(String(format: "%.1f °C", max))
                            .font(.title3.weight(.semibold))
                            .accessibilityIdentifier("garden.tomorrowHigh")
                    }
                }
            } else if let error = viewModel.errorMessage {
                Text(error).foregroundStyle(.secondary)
            } else {
                Text("Fetching forecast…").foregroundStyle(.secondary)
            }

            if case .cache(let fetchedAt) = viewModel.dataSource {
                Label(
                    "Offline — using forecast from \(fetchedAt.formatted(.relative(presentation: .named)))",
                    systemImage: "wifi.slash"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var verdictSection: some View {
        Section("Your plants") {
            if plants.isEmpty {
                Text("No plants right now. Tap the + button to add one.")
                    .foregroundStyle(.secondary)
            } else if viewModel.verdicts.isEmpty {
                ForEach(plants) { plant in
                    Text(plant.name)
                }
            } else {
                ForEach(viewModel.verdicts) { verdict in
                    VerdictRow(verdict: verdict)
                }
                .onDelete(perform: deletePlants)
            }
        }
    }

    // MARK: - Actions

    private func reloadPlants() {
        plants = (try? store.plants()) ?? []
    }

    private func deletePlants(at offsets: IndexSet) {
        let sortedPlants = (try? store.plants()) ?? []
        // Verdicts are sorted by severity; map back to the plant by id.
        for index in offsets {
            let verdict = viewModel.verdicts[index]
            if let plant = sortedPlants.first(where: { $0.id == verdict.id }) {
                _ = try? store.deletePlant(plant)
            }
        }
        reloadPlants()
        viewModel.reevaluate()
    }
}

// MARK: - Rows

private struct VerdictRow: View {
    let verdict: PlantVerdict

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(severityColor)
                .frame(width: 12, height: 12)

            VStack(alignment: .leading, spacing: 2) {
                Text(verdict.plantName).font(.body)
                Text(verdict.advice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // The margin of whichever side is tighter — the number that matters.
            Text(String(format: "%+.1f°", dominantMargin))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("garden.verdict.\(verdict.plantName)")
    }

    private var dominantMargin: Double {
        verdict.heatRisk.rawValue > verdict.frostRisk.rawValue
            ? verdict.heatMarginC
            : verdict.frostMarginC
    }

    private var severityColor: Color {
        switch verdict.severity {
        case 0: return .green
        case 1: return .yellow
        case 2: return .orange
        default: return .red
        }
    }
}

// MARK: - Sheets

private struct AddPlantSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var coldTolerance: Double = 0
    @State private var heatTolerance: Double = PersistenceController.defaultHeatToleranceCelsius

    let onAdd: (String, Double, Double) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Plant name", text: $name)
                        .accessibilityIdentifier("addPlant.nameField")

                    Menu("Start from a common plant") {
                        ForEach(PlantCatalog.presets) { preset in
                            Button(preset.name) {
                                name = preset.name
                                coldTolerance = preset.coldToleranceC
                                heatTolerance = preset.heatToleranceC
                            }
                        }
                    }
                    .accessibilityIdentifier("addPlant.presetMenu")
                } footer: {
                    Text("Presets are starting points, not botany — adjust either number for your garden's reality.")
                }

                Section {
                    VStack(alignment: .leading) {
                        Text("Cold tolerance: \(String(format: "%.0f", coldTolerance)) °C")
                        Slider(value: $coldTolerance, in: -30...10, step: 1)
                            .accessibilityIdentifier("addPlant.toleranceSlider")
                        Text("The lowest temperature it tolerates uncovered. Tender plants: around 0°. Hardy perennials: −15° or lower.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading) {
                        Text("Heat tolerance: \(String(format: "%.0f", heatTolerance)) °C")
                        Slider(value: $heatTolerance, in: 20...45, step: 1)
                            .accessibilityIdentifier("addPlant.heatSlider")
                        Text("The daytime high it handles without extra water or shade. Cool-season greens: mid-20s. Heat lovers: high 30s.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Add Plant")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(name.trimmingCharacters(in: .whitespaces), coldTolerance, heatTolerance)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityIdentifier("addPlant.confirm")
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

private struct LocationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var latitude: Double
    @Binding var longitude: Double

    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LabeledContent("Latitude") {
                        TextField("Latitude", value: $latitude, format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Longitude") {
                        TextField("Longitude", value: $longitude, format: .number)
                            .keyboardType(.numbersAndPunctuation)
                            .multilineTextAlignment(.trailing)
                    }
                } footer: {
                    Text("Coordinates only — Plant Sentinel never asks for location permission, so your position is never shared with anyone. Find yours on any map app.")
                }
            }
            .navigationTitle("Location")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
