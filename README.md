# Plant Sentinel

*(formerly Frost Sentinel — renamed when it became multi-season)*

Two questions, answered quietly, the night before they matter:
**does anything in my garden need covering tonight — and does anything need water
before tomorrow's heat?**

Gardeners cross-reference weather forecasts against each plant's tolerances by hand —
every cold-snap evening in spring and fall, every heat-wave evening in summer. Plant
Sentinel removes that friction. Log your plants once; every evening it fetches the
forecast and gives you a plain answer per plant: *"Basil is fine tonight." "Cover the
lavender." "Water the lettuce tonight — tomorrow will be hotter than it likes."*

The timing is the whole product: watering the night before a scorcher beats watering
at noon, and covering at dusk beats discovering frost at dawn. Advice arrives when
you can still act on it.

No accounts. No ads. No location permission — you give it coordinates, it never asks
the OS where you are. Works offline with the last cached forecast, because weather
doesn't wait for good Wi-Fi.

## Why this project exists (the technical story)

Plant Sentinel is deliberately built across three layers that mirror real production
iOS work:

**REST networking (Swift, async/await).** Daily minimum and maximum temperatures come
from the [Open-Meteo API](https://open-meteo.com/) — no API key, consistent with the
app's no-tracking posture. The service is defined behind a `ForecastFetching` protocol,
the response parser is a pure static function tested against fixtures, and the URL
construction is unit-tested.

**Core Data, offline-first.** The stack uses a *programmatic* managed object model —
the entire schema is reviewable in a code diff, with no `.xcdatamodeld` drift. The v2
schema (heat tolerances, daily maximums) migrates v1 stores in place via lightweight
migration with default values. On every successful fetch the forecast cache is replaced;
when the network fails, the app falls back to the cache and says so honestly ("Offline —
using forecast from 2 hours ago"). A slightly stale answer beats no answer when frost
is coming.

**Objective-C legacy layer, bridged into Swift.** The temperature-risk classification
lives in `FSFrostCalculator`, written in Objective-C on purpose. Real-world horticultural
and agricultural calculation libraries are frequently legacy code, and contract work
means maintaining and bridging code like this — not rewriting it. When the app went
multi-season, heat classification was **added to the legacy class without breaking its
existing callers** — the original initializer and every v1 method still work, which is
exactly the discipline extending production legacy code demands. The class name stays
`FSFrostCalculator` for the same reason real legacy names outlive their accuracy. It
demonstrates `NS_ENUM` bridging (two enums now), nullability annotations, designated
initializers, and a legacy surface consumed by a modern `@MainActor` Swift view model.

## Tests

The suite covers all three layers and the seams between them:

- `FrostCalculatorTests` — the Objective-C domain math (frost *and* heat), exercised
  through the Swift bridge. These tests double as the risk engine's behavior spec:
  a future Android port is correct when it passes the same table.
- `ForecastServiceTests` — response parsing against fixtures, malformed-payload
  rejection (including v1-shaped payloads), URL construction
- `GardenViewModelTests` — integration: mocked REST service + real in-memory Core Data
  + bridged calculator; verdict ordering by severity, tomorrow-vs-today heat semantics,
  combined two-sided advice, cache population, offline fallback, and error paths

Run with ⌘U.

## Architecture

```
App/FrostSentinelApp.swift          entry point, dependency wiring
Features/GardenView.swift           the single screen: tonight's low, tomorrow's high, verdicts
Core/GardenViewModel.swift          orchestrates fetch -> cache -> classify (both risks)
Core/PlantCatalog.swift             starter presets: common plants with both tolerances
Core/Network/ForecastService.swift  Open-Meteo client behind a protocol
Core/Persistence/                   programmatic Core Data model + GardenStore
Legacy/FSFrostCalculator.h/.m       Objective-C risk classification (bridged)
```

The model and network layers are UI-free and platform-thin on purpose: they're the
"brain" a planned native Android port (Kotlin + Jetpack Compose) re-implements against
the same test spec.

## Roadmap

- **1.0** — heat + frost verdicts (done), per-plant profiles with presets (done),
  one-time optional location setup, daily local notifications (no server — the app
  schedules them itself after fetching the forecast)
- **1.1** — plant-sitting mode: share your garden as a file (AirDrop/Messages), no
  accounts, no cloud
- **Later** — native Android port

---

Built by Liza Sloane — [github.com/Bolero-Dev](https://github.com/Bolero-Dev)
