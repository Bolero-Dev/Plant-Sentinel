//
//  PersistenceController.swift
//  PlantSentinel (formerly FrostSentinel)
//
//  Core Data stack with a programmatic model.
//
//  The model is defined in code rather than an .xcdatamodeld file so the whole
//  schema is reviewable in a diff, versionable, and impossible to drift from
//  what the code expects.
//
//  Schema history: v2 added heatToleranceCelsius (plants) and maxTempCelsius
//  (forecast cache) for the multi-season pivot. Both carry default values so
//  Core Data's automatic lightweight migration upgrades existing stores in
//  place. ForecastNightEntity keeps its v1 name — it now caches a full day,
//  but renaming a Core Data entity costs a migration and buys nothing.
//

import CoreData

/// A plant in the user's garden, with its unprotected cold tolerance and the
/// heat it tolerates without extra water or shade.
@objc(PlantEntity)
final class PlantEntity: NSManagedObject, Identifiable {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var toleranceCelsius: Double
    @NSManaged var heatToleranceCelsius: Double
    @NSManaged var createdAt: Date
}

/// One cached forecast day, so the app still answers offline.
@objc(ForecastNightEntity)
final class ForecastNightEntity: NSManagedObject, Identifiable {
    @NSManaged var date: Date
    @NSManaged var minTempCelsius: Double
    @NSManaged var maxTempCelsius: Double
    @NSManaged var fetchedAt: Date
}

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    var viewContext: NSManagedObjectContext { container.viewContext }

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(
            name: "FrostSentinel",
            managedObjectModel: Self.makeModel()
        )

        if inMemory {
            container.persistentStoreDescriptions.first?.url =
                URL(fileURLWithPath: "/dev/null")
        }

        container.loadPersistentStores { _, error in
            if let error {
                // A persistence failure at launch is unrecoverable for this
                // app's purpose; fail loudly in development.
                fatalError("Failed to load persistent store: \(error)")
            }
        }
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - Programmatic model

    /// A late-summer-safe default for plants stored before heat tracking
    /// existed: warm enough that migrated plants don't suddenly demand water.
    /// (nonisolated so it can appear in default arguments — those are
    /// evaluated outside MainActor isolation under this project's settings.)
    nonisolated static let defaultHeatToleranceCelsius = 32.0

    private static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()

        let plant = NSEntityDescription()
        plant.name = "PlantEntity"
        plant.managedObjectClassName = "PlantEntity"
        plant.properties = [
            attribute("id", .UUIDAttributeType),
            attribute("name", .stringAttributeType),
            attribute("toleranceCelsius", .doubleAttributeType),
            attribute("heatToleranceCelsius", .doubleAttributeType,
                      defaultValue: defaultHeatToleranceCelsius),
            attribute("createdAt", .dateAttributeType),
        ]

        let night = NSEntityDescription()
        night.name = "ForecastNightEntity"
        night.managedObjectClassName = "ForecastNightEntity"
        night.properties = [
            attribute("date", .dateAttributeType),
            attribute("minTempCelsius", .doubleAttributeType),
            // Migrated v1 cache rows get 0.0 — harmless, because the cache is
            // a snapshot that's replaced wholesale on the next refresh.
            attribute("maxTempCelsius", .doubleAttributeType, defaultValue: 0.0),
            attribute("fetchedAt", .dateAttributeType),
        ]

        model.entities = [plant, night]
        return model
    }

    private static func attribute(
        _ name: String,
        _ type: NSAttributeType,
        optional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attr = NSAttributeDescription()
        attr.name = name
        attr.attributeType = type
        attr.isOptional = optional
        if let defaultValue {
            attr.defaultValue = defaultValue
        }
        return attr
    }
}

// MARK: - Garden store operations

/// Thin, testable wrappers around the fetches and mutations the app needs.
struct GardenStore {
    let context: NSManagedObjectContext

    func plants() throws -> [PlantEntity] {
        let request = NSFetchRequest<PlantEntity>(entityName: "PlantEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
        return try context.fetch(request)
    }

    @discardableResult
    func addPlant(
        name: String,
        toleranceCelsius: Double,
        heatToleranceCelsius: Double = PersistenceController.defaultHeatToleranceCelsius
    ) throws -> PlantEntity {
        let plant = PlantEntity(
            entity: NSEntityDescription.entity(forEntityName: "PlantEntity", in: context)!,
            insertInto: context
        )
        plant.id = UUID()
        plant.name = name
        plant.toleranceCelsius = toleranceCelsius
        plant.heatToleranceCelsius = heatToleranceCelsius
        plant.createdAt = Date()
        try context.save()
        return plant
    }

    func deletePlant(_ plant: PlantEntity) throws {
        context.delete(plant)
        try context.save()
    }

    /// Replaces the cached forecast wholesale. The cache is a snapshot,
    /// not a history — old days have no value once superseded.
    func replaceForecastCache(with days: [DayForecast]) throws {
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "ForecastNightEntity")
        let delete = NSBatchDeleteRequest(fetchRequest: request)
        try context.execute(delete)

        let now = Date()
        for forecast in days {
            let entity = ForecastNightEntity(
                entity: NSEntityDescription.entity(
                    forEntityName: "ForecastNightEntity", in: context
                )!,
                insertInto: context
            )
            entity.date = forecast.date
            entity.minTempCelsius = forecast.minTempC
            entity.maxTempCelsius = forecast.maxTempC
            entity.fetchedAt = now
        }
        try context.save()
    }

    func cachedForecast() throws -> [DayForecast] {
        let request = NSFetchRequest<ForecastNightEntity>(entityName: "ForecastNightEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        return try context.fetch(request).map {
            DayForecast(date: $0.date, minTempC: $0.minTempCelsius, maxTempC: $0.maxTempCelsius)
        }
    }

    func cacheFetchedAt() throws -> Date? {
        let request = NSFetchRequest<ForecastNightEntity>(entityName: "ForecastNightEntity")
        request.fetchLimit = 1
        return try context.fetch(request).first?.fetchedAt
    }
}
