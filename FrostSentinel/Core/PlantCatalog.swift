//
//  PlantCatalog.swift
//  PlantSentinel (formerly FrostSentinel)
//
//  A starter catalog of common garden plants so users aren't guessing at
//  tolerance numbers. Values are horticultural approximations — the point is
//  a sane starting slider position, not botany-grade precision. Users can
//  adjust both numbers after picking a preset.
//
//  Deliberately UI-free and Foundation-only: this file is part of the shared
//  "brain" a future Android port re-implements from the same table.
//

import Foundation

/// A named preset: what this plant tolerates uncovered on a cold night, and
/// the daytime heat it handles without extra water or shade.
struct PlantPreset: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let coldToleranceC: Double
    let heatToleranceC: Double
}

enum PlantCatalog {
    /// Ordered roughly from tender to tough, cold-side first —
    /// the same order a gardener worries about them.
    static let presets: [PlantPreset] = [
        PlantPreset(name: "Basil",            coldToleranceC:   5, heatToleranceC: 35),
        PlantPreset(name: "Tomato",           coldToleranceC:   2, heatToleranceC: 35),
        PlantPreset(name: "Pepper",           coldToleranceC:   4, heatToleranceC: 35),
        PlantPreset(name: "Succulent (tender)", coldToleranceC: 2, heatToleranceC: 40),
        PlantPreset(name: "Citrus (potted)",  coldToleranceC:  -2, heatToleranceC: 38),
        PlantPreset(name: "Lettuce",          coldToleranceC:  -2, heatToleranceC: 27),
        PlantPreset(name: "Spinach",          coldToleranceC:  -6, heatToleranceC: 26),
        PlantPreset(name: "Rosemary",         coldToleranceC:  -7, heatToleranceC: 38),
        PlantPreset(name: "Kale",             coldToleranceC:  -9, heatToleranceC: 30),
        PlantPreset(name: "Lavender",         coldToleranceC: -12, heatToleranceC: 38),
        PlantPreset(name: "Rose",             coldToleranceC: -20, heatToleranceC: 35),
        PlantPreset(name: "Hydrangea",        coldToleranceC: -20, heatToleranceC: 32),
        PlantPreset(name: "Fern (hardy)",     coldToleranceC: -20, heatToleranceC: 30),
        PlantPreset(name: "Hosta",            coldToleranceC: -30, heatToleranceC: 32),
    ]
}
