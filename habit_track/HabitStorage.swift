import Foundation
import SwiftUI

// MARK: - Habit model

enum HabitKind: Codable, Equatable {
    case boolean
    case count(max: Int)

    private enum CodingKeys: String, CodingKey {
        case caseName
        case max
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let name = try container.decode(String.self, forKey: .caseName)
        switch name {
        case "boolean":
            self = .boolean
        case "count":
            let max = try container.decode(Int.self, forKey: .max)
            self = .count(max: max)
        default:
            self = .boolean
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .boolean:
            try container.encode("boolean", forKey: .caseName)
        case .count(let max):
            try container.encode("count", forKey: .caseName)
            try container.encode(max, forKey: .max)
        }
    }
}

struct Habit: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var symbolName: String
    var kind: HabitKind
}

/// Shared keys and helpers for storing habit data between the app and the widget.
enum HabitStorage {
    static let appGroupID = "group.com.habit-track.habit-track"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    private static let calendar = Calendar.current

    private enum Keys {
        static let habits = "habits.list"
        static let todayDate = "habits.todayDate"
        static let todayValues = "habits.todayValues"
        static let streak = "habits.streak"
        static let lastSuccessDay = "habits.lastSuccessDay"
    }

    /// A simple value type representing today's state and the current streak.
    struct State {
        var habits: [Habit]
        var values: [UUID: Int]
        var streakDays: Int

        // Convenience for existing UI & widgets: assume first two habits are push-ups & water.
        var todayPushupsCount: Int {
            guard let first = habits.first else { return 0 }
            return values[first.id] ?? 0
        }

        var todayWaterCount: Int {
            guard habits.count > 1 else { return 0 }
            let water = habits[1]
            return values[water.id] ?? 0
        }

        var isTodayPushupsDone: Bool { todayPushupsCount > 0 }
        var isTodayWaterDone: Bool { todayWaterCount > 0 }
    }

    // MARK: - Date helpers

    private static func normalizedToday() -> Date {
        calendar.startOfDay(for: Date())
    }

    private static func ensureToday() {
        let today = normalizedToday()
        if let stored = defaults.object(forKey: Keys.todayDate) as? Date,
           calendar.isDate(stored, inSameDayAs: today) {
            return
        }
        defaults.set(today, forKey: Keys.todayDate)
        defaults.set([String: Int](), forKey: Keys.todayValues)
    }

    // MARK: - Habits list

    static func loadHabits() -> [Habit] {
        if let data = defaults.data(forKey: Keys.habits),
           let habits = try? JSONDecoder().decode([Habit].self, from: data),
           !habits.isEmpty {
            return habits
        }

        // First-time defaults: push-ups + water
        let defaultsHabits: [Habit] = [
            Habit(id: UUID(),
                  name: "Push-ups",
                  symbolName: "figure.strengthtraining.traditional",
                  kind: .count(max: 500)),
            Habit(id: UUID(),
                  name: "Water",
                  symbolName: "drop.fill",
                  kind: .count(max: 50))
        ]
        saveHabits(defaultsHabits)
        return defaultsHabits
    }

    static func saveHabits(_ habits: [Habit]) {
        if let data = try? JSONEncoder().encode(habits) {
            defaults.set(data, forKey: Keys.habits)
        }
    }

    // MARK: - Today state

    static func loadState() -> State {
        ensureToday()
        let habits = loadHabits()
        let raw = defaults.dictionary(forKey: Keys.todayValues) as? [String: Int] ?? [:]

        var values: [UUID: Int] = [:]
        for habit in habits {
            values[habit.id] = raw[habit.id.uuidString] ?? 0
        }

        let streak = defaults.integer(forKey: Keys.streak)
        return State(habits: habits, values: values, streakDays: streak)
    }

    static func setValue(for habit: Habit, value: Int) -> State {
        ensureToday()
        var dict = defaults.dictionary(forKey: Keys.todayValues) as? [String: Int] ?? [:]
        dict[habit.id.uuidString] = max(0, value)
        defaults.set(dict, forKey: Keys.todayValues)
        return recomputeStreak()
    }

    // MARK: - Streak recompute

    @discardableResult
    private static func recomputeStreak() -> State {
        ensureToday()
        let today = normalizedToday()
        let habits = loadHabits()
        let raw = defaults.dictionary(forKey: Keys.todayValues) as? [String: Int] ?? [:]

        var values: [UUID: Int] = [:]
        var allCompleted = true

        for habit in habits {
            let v = raw[habit.id.uuidString] ?? 0
            values[habit.id] = v

            switch habit.kind {
            case .boolean:
                if v == 0 { allCompleted = false }
            case .count:
                if v == 0 { allCompleted = false }
            }
        }

        var streak = defaults.integer(forKey: Keys.streak)
        if allCompleted {
            let lastSuccess = defaults.object(forKey: Keys.lastSuccessDay) as? Date
            if lastSuccess == nil || !calendar.isDate(lastSuccess!, inSameDayAs: today) {
                if let last = lastSuccess,
                   let d = calendar.dateComponents([.day], from: last, to: today).day,
                   d == 1 {
                    streak += 1
                } else {
                    streak = 1
                }
                defaults.set(today, forKey: Keys.lastSuccessDay)
                defaults.set(streak, forKey: Keys.streak)
            }
        }

        return State(habits: habits, values: values, streakDays: streak)
    }
}

// MARK: - View model

@MainActor
final class HabitViewModel: ObservableObject {
    @Published private(set) var state: HabitStorage.State

    init() {
        self.state = HabitStorage.loadState()
    }

    var habits: [Habit] { state.habits }

    func value(for habit: Habit) -> Int {
        state.values[habit.id] ?? 0
    }

    func refresh() {
        state = HabitStorage.loadState()
    }

    func setValue(for habit: Habit, value: Int) {
        state = HabitStorage.setValue(for: habit, value: value)
    }

    // Backwards-compatible helpers for existing UI
    func setPushups(count: Int) {
        if let habit = state.habits.first {
            setValue(for: habit, value: count)
        }
    }

    func setWater(count: Int) {
        if state.habits.count > 1 {
            let habit = state.habits[1]
            setValue(for: habit, value: count)
        }
    }

    // Habit management
    func addHabit(name: String, symbolName: String, kind: HabitKind) {
        var list = HabitStorage.loadHabits()
        list.append(Habit(id: UUID(), name: name, symbolName: symbolName, kind: kind))
        HabitStorage.saveHabits(list)
        refresh()
    }

    func deleteHabit(_ habit: Habit) {
        var list = HabitStorage.loadHabits()
        list.removeAll { $0.id == habit.id }
        HabitStorage.saveHabits(list)
        refresh()
    }
}

