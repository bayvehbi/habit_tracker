import Foundation
import AppIntents

/// AppIntents representation of a habit for use in widget configuration.
struct HabitAppEntity: AppEntity, Identifiable {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Habit")
    static var defaultQuery = HabitEntityQuery()

    let id: UUID
    let name: String
    let symbolName: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: .init(stringLiteral: name),
            image: .init(systemName: symbolName)
        )
    }
}

struct HabitEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [HabitAppEntity] {
        let habits = HabitStorage.loadHabits()
        return habits
            .filter { identifiers.contains($0.id) }
            .map { HabitAppEntity(id: $0.id, name: $0.name, symbolName: $0.symbolName) }
    }

    func suggestedEntities() async throws -> [HabitAppEntity] {
        let habits = HabitStorage.loadHabits()
        return habits.map { HabitAppEntity(id: $0.id, name: $0.name, symbolName: $0.symbolName) }
    }
}

