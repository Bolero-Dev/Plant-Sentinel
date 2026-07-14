# Plant Sentinel

*(formerly Frost Sentinel — I renamed it when it stopped being a one-season app)*

Two questions, answered the night before they matter: **does anything in my
garden need covering tonight — and does anything need water before tomorrow's
heat?**

Gardeners do this math by hand: cross-reference the forecast against what each
plant can take, every cold-snap evening in spring and fall, every heat-wave
evening in summer. I built Plant Sentinel so nobody has to. Log your plants
once; every evening it checks the forecast and gives you a plain answer per
plant: *"Basil is fine tonight." "Cover the lavender." "Water the lettuce
tonight — tomorrow will be hotter than it likes."*

The timing is the whole product. Watering the night before a scorcher beats
watering at noon, and covering at dusk beats finding frost at dawn. Advice
should show up while you can still act on it.

No accounts. No ads. No location permission — you give it coordinates, and it
never asks the OS where you are. Works offline with the last cached forecast,
because weather doesn't wait for good Wi-Fi.

## Why I built it this way

Three layers, each one on purpose:

**REST networking (Swift, async/await).** Daily minimums and maximums come from
the [Open-Meteo API](https://open-meteo.com/) — no API key, which fits the
no-tracking posture. The service sits behind a `ForecastFetching` protocol, the
parser is a pure function tested against fixtures, and the URL construction is
unit-tested.

**Core Data, offline-first.** The managed object model is written in code, not
an `.xcdatamodeld` file — the whole schema is reviewable in a diff and can't
drift from what the code expects. The v2 schema (heat tolerances, daily maxes)
migrates v1 stores in place with default values. When the network fails, the
app falls back to the cache and says so plainly ("Offline — using forecast from
2 hours ago"). A slightly stale answer beats no answer when frost is coming.

**An Objective-C layer, on purpose.** Real horticultural and agricultural
calculation libraries are usually legacy code, and real jobs mean maintaining
and bridging code like that — not rewriting it. So the risk classification
lives in Objective-C, bridged into Swift. When the app went multi-season, I
**added** heat classification to the legacy class without breaking a single
existing caller — the original initializer and every v1 method still work,
because that's what extending production legacy code actually demands. The
class is still named `FSFrostCalculator` even though it handles heat now.
Real legacy names outlive their accuracy; mine gets to as well. (It also
demonstrates `NS_ENUM` bridging, nullability, designated initializers, and an
`NS_SWIFT_NAME` fix for a name collision Swift's import rules created — the
kind of interop scar tissue this layer exists to show.)

## Tests

All three layers, plus the seams between them:

- `FrostCalculatorTests` — the Objective-C math (frost *and* heat) exercised
  through the Swift bridge. These tests are also the spec for the planned
  Android port: the port is correct when it passes the same table.
- `ForecastServiceTests` — parsing against fixtures, malformed-payload
  rejection (including v1-shaped payloads), URL construction
- `GardenViewModelTests` — integration: mocked REST + real in-memory Core Data
  + the bridged calculator. Verdict ordering, tomorrow-vs-today heat semantics,
  combined two-sided advice, offline fallback, error paths.

Run with ⌘U.

## Architecture

```
App/FrostSentinelApp.swift          entry point, dependency wiring
Features/GardenView.swift           the single screen: tonight's low, tomorrow's high, verdicts
Core/GardenViewModel.swift          orchestrates fetch -> cache -> classify (both risks)
Core/PlantCatalog.swift             starter presets: common plants, both tolerances
Core/Network/ForecastService.swift  Open-Meteo client behind a protocol
Core/Persistence/                   programmatic Core Data model + GardenStore
Legacy/FSFrostCalculator.h/.m       Objective-C risk classification (bridged)
```

The model and network layers stay UI-free on purpose: they're the brain a
native Android port (Kotlin + Jetpack Compose) will re-implement against the
same test spec.

## Roadmap

- **1.0** — heat + frost verdicts (done), per-plant profiles with presets
  (done), one-time optional location setup, daily local notifications — no
  server, ever; the app schedules them itself after fetching the forecast
- **1.1** — plant-sitting mode: share your garden as a file (AirDrop or
  Messages it to whoever's watering while you're away). No accounts, no cloud.
- **Later** — the native Android port

---

Built by Liza Sloane — [github.com/Bolero-Dev](https://github.com/Bolero-Dev)
