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

struct HabitLog: Identifiable, Codable, Equatable {
    var id: UUID
    var habitID: UUID
    var value: Int
    var timestamp: Date
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
        static let todayValues = "habits.todayValues"
        static let logs = "habits.logs"
        static let historyByDay = "habits.historyByDay"
    }

    /// Represents today's values and per-habit streaks.
    struct State {
        var habits: [Habit]
        var values: [UUID: Int]
        var streaksByHabit: [UUID: Int]

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

    private static var dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static func dayKey(for date: Date) -> String {
        dayFormatter.string(from: calendar.startOfDay(for: date))
    }

    private static func date(from dayKey: String) -> Date? {
        dayFormatter.date(from: dayKey)
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

    // MARK: - Logs + migration

    private static func loadLegacyHistoryByDay() -> [String: [String: Int]] {
        defaults.dictionary(forKey: Keys.historyByDay) as? [String: [String: Int]] ?? [:]
    }

    private static func loadLogs() -> [HabitLog] {
        if let data = defaults.data(forKey: Keys.logs),
           let logs = try? JSONDecoder().decode([HabitLog].self, from: data) {
            return logs
        }
        return []
    }

    private static func saveLogs(_ logs: [HabitLog]) {
        if let data = try? JSONEncoder().encode(logs) {
            defaults.set(data, forKey: Keys.logs)
        }
    }

    // Migrates previous day totals into timestamped logs.
    private static func migrateToLogsIfNeeded() {
        if defaults.data(forKey: Keys.logs) != nil { return }

        let history = loadLegacyHistoryByDay()
        var migrated: [HabitLog] = []

        if !history.isEmpty {
            for (day, values) in history {
                guard let baseDate = date(from: day),
                      let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: baseDate) else {
                    continue
                }
                for (habitID, value) in values where value > 0 {
                    if let uuid = UUID(uuidString: habitID) {
                        migrated.append(HabitLog(id: UUID(), habitID: uuid, value: value, timestamp: noon))
                    }
                }
            }
        } else {
            let todayValues = defaults.dictionary(forKey: Keys.todayValues) as? [String: Int] ?? [:]
            for (habitID, value) in todayValues where value > 0 {
                if let uuid = UUID(uuidString: habitID) {
                    migrated.append(HabitLog(id: UUID(), habitID: uuid, value: value, timestamp: Date()))
                }
            }
        }

        saveLogs(migrated)
    }

    // MARK: - Aggregates

    static func loadState() -> State {
        migrateToLogsIfNeeded()
        let habits = loadHabits()
        let logs = loadLogs()
        let todayKey = dayKey(for: normalizedToday())

        var totalsByDayAndHabit: [String: [UUID: Int]] = [:]
        for log in logs {
            let key = dayKey(for: log.timestamp)
            var day = totalsByDayAndHabit[key] ?? [:]
            day[log.habitID, default: 0] += max(0, log.value)
            totalsByDayAndHabit[key] = day
        }

        var values: [UUID: Int] = [:]
        var streaks: [UUID: Int] = [:]
        for habit in habits {
            values[habit.id] = totalsByDayAndHabit[todayKey]?[habit.id] ?? 0
            streaks[habit.id] = currentStreak(for: habit.id, totalsByDayAndHabit: totalsByDayAndHabit)
        }

        return State(habits: habits, values: values, streaksByHabit: streaks)
    }

    @discardableResult
    static func addLog(for habit: Habit, value: Int, at timestamp: Date = Date()) -> State {
        migrateToLogsIfNeeded()
        let sanitized = max(0, value)
        guard sanitized > 0 else { return loadState() }

        var logs = loadLogs()
        logs.append(HabitLog(id: UUID(), habitID: habit.id, value: sanitized, timestamp: timestamp))
        saveLogs(logs)

        // Keep compatibility key synced with today's total.
        syncLegacyTodayValuesFromLogs(logs)
        return loadState()
    }

    @discardableResult
    static func setValue(for habit: Habit, value: Int) -> State {
        addLog(for: habit, value: value)
    }

    static func streak(for habit: Habit) -> Int {
        loadState().streaksByHabit[habit.id] ?? 0
    }

    static func completedDates(for habit: Habit, in month: Date) -> [Date] {
        let grouped = groupedValuesByDay(for: habit)
        return grouped.compactMap { key, value in
            guard value > 0, let day = date(from: key) else { return nil }
            return calendar.isDate(day, equalTo: month, toGranularity: .month) ? day : nil
        }.sorted()
    }

    static func totalCompletedDays(for habit: Habit) -> Int {
        groupedValuesByDay(for: habit).values.filter { $0 > 0 }.count
    }

    static func totalLoggedValue(for habit: Habit) -> Int {
        loadLogs()
            .filter { $0.habitID == habit.id }
            .reduce(0) { $0 + max(0, $1.value) }
    }

    static func bestStreak(for habit: Habit) -> Int {
        let allDates = groupedValuesByDay(for: habit)
            .compactMap { key, value -> Date? in
                guard value > 0 else { return nil }
                return date(from: key)
            }
            .sorted()

        guard !allDates.isEmpty else { return 0 }
        var best = 1
        var current = 1

        for i in 1..<allDates.count {
            let previous = calendar.startOfDay(for: allDates[i - 1])
            let currentDate = calendar.startOfDay(for: allDates[i])
            let diff = calendar.dateComponents([.day], from: previous, to: currentDate).day ?? 0
            if diff == 1 {
                current += 1
            } else if diff > 1 {
                current = 1
            }
            best = max(best, current)
        }
        return best
    }

    static func logs(for habit: Habit) -> [HabitLog] {
        loadLogs()
            .filter { $0.habitID == habit.id }
            .sorted { $0.timestamp > $1.timestamp }
    }

    static func canEditOrDelete(_ log: HabitLog) -> Bool {
        let age = Date().timeIntervalSince(log.timestamp)
        return age >= 0 && age <= 24 * 60 * 60
    }

    @discardableResult
    static func updateLog(for habit: Habit, logID: UUID, newValue: Int) -> Bool {
        migrateToLogsIfNeeded()
        let sanitized = max(0, newValue)
        guard sanitized > 0 else { return false }

        var logs = loadLogs()
        guard let index = logs.firstIndex(where: { $0.id == logID && $0.habitID == habit.id }) else {
            return false
        }
        guard canEditOrDelete(logs[index]) else { return false }

        logs[index].value = sanitized
        saveLogs(logs)
        syncLegacyTodayValuesFromLogs(logs)
        return true
    }

    @discardableResult
    static func deleteLog(for habit: Habit, logID: UUID) -> Bool {
        migrateToLogsIfNeeded()
        var logs = loadLogs()
        guard let index = logs.firstIndex(where: { $0.id == logID && $0.habitID == habit.id }) else {
            return false
        }
        guard canEditOrDelete(logs[index]) else { return false }

        logs.remove(at: index)
        saveLogs(logs)
        syncLegacyTodayValuesFromLogs(logs)
        return true
    }

    static func removeData(for habit: Habit) {
        var logs = loadLogs()
        logs.removeAll { $0.habitID == habit.id }
        saveLogs(logs)
        syncLegacyTodayValuesFromLogs(logs)
        var todayValues = defaults.dictionary(forKey: Keys.todayValues) as? [String: Int] ?? [:]
        todayValues.removeValue(forKey: habit.id.uuidString)
        defaults.set(todayValues, forKey: Keys.todayValues)
    }

    private static func syncLegacyTodayValuesFromLogs(_ logs: [HabitLog]) {
        let todayKey = dayKey(for: normalizedToday())
        var totals: [String: Int] = [:]
        for log in logs where dayKey(for: log.timestamp) == todayKey {
            totals[log.habitID.uuidString, default: 0] += max(0, log.value)
        }
        defaults.set(totals, forKey: Keys.todayValues)
    }

    private static func groupedValuesByDay(for habit: Habit) -> [String: Int] {
        var grouped: [String: Int] = [:]
        for log in loadLogs() where log.habitID == habit.id {
            let key = dayKey(for: log.timestamp)
            grouped[key, default: 0] += max(0, log.value)
        }
        return grouped
    }

    private static func currentStreak(for habitID: UUID, totalsByDayAndHabit: [String: [UUID: Int]]) -> Int {
        let today = normalizedToday()
        var cursor = today
        var streak = 0

        while true {
            let key = dayKey(for: cursor)
            let dayValues = totalsByDayAndHabit[key] ?? [:]
            let value = dayValues[habitID] ?? 0

            if value > 0 {
                streak += 1
            } else {
                break
            }

            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else {
                break
            }
            cursor = previous
        }

        return streak
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

    func addLog(for habit: Habit, value: Int) {
        state = HabitStorage.addLog(for: habit, value: value)
    }

    func streak(for habit: Habit) -> Int {
        state.streaksByHabit[habit.id] ?? 0
    }

    func completedDates(for habit: Habit, in month: Date) -> [Date] {
        HabitStorage.completedDates(for: habit, in: month)
    }

    func totalCompletedDays(for habit: Habit) -> Int {
        HabitStorage.totalCompletedDays(for: habit)
    }

    func totalLoggedValue(for habit: Habit) -> Int {
        HabitStorage.totalLoggedValue(for: habit)
    }

    func bestStreak(for habit: Habit) -> Int {
        HabitStorage.bestStreak(for: habit)
    }

    func logs(for habit: Habit) -> [HabitLog] {
        HabitStorage.logs(for: habit)
    }

    func canEditOrDelete(_ log: HabitLog) -> Bool {
        HabitStorage.canEditOrDelete(log)
    }

    @discardableResult
    func updateLog(for habit: Habit, logID: UUID, newValue: Int) -> Bool {
        let didUpdate = HabitStorage.updateLog(for: habit, logID: logID, newValue: newValue)
        if didUpdate { refresh() }
        return didUpdate
    }

    @discardableResult
    func deleteLog(for habit: Habit, logID: UUID) -> Bool {
        let didDelete = HabitStorage.deleteLog(for: habit, logID: logID)
        if didDelete { refresh() }
        return didDelete
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
        HabitStorage.removeData(for: habit)
        refresh()
    }
}

