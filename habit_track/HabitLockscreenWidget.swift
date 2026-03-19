import Foundation

#if canImport(WidgetKit) && canImport(AppIntents)
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - Widget configuration intent

struct HabitWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Habit"
    static var description = IntentDescription("Choose which habit to show.")

    @Parameter(title: "Habit")
    var habit: HabitAppEntity?

    static var parameterSummary: some ParameterSummary {
        Summary("Show \(\.$habit)")
    }
}

// MARK: - Timeline / Entry

struct HabitEntry: TimelineEntry {
    let date: Date
    let state: HabitStorage.State
    let habit: Habit?
}

@available(iOS 17.0, *)
struct GenericHabitProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HabitEntry {
        let state = HabitStorage.loadState()
        let habit = state.habits.first
        return HabitEntry(date: Date(), state: state, habit: habit)
    }

    func snapshot(for configuration: HabitWidgetIntent, in context: Context) async -> HabitEntry {
        let state = HabitStorage.loadState()
        let habit = selectHabit(from: state.habits, config: configuration)
        return HabitEntry(date: Date(), state: state, habit: habit)
    }

    func timeline(for configuration: HabitWidgetIntent, in context: Context) async -> Timeline<HabitEntry> {
        let state = HabitStorage.loadState()
        let habit = selectHabit(from: state.habits, config: configuration)
        let entry = HabitEntry(date: Date(), state: state, habit: habit)
        let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func selectHabit(from habits: [Habit], config: HabitWidgetIntent) -> Habit? {
        if let selected = config.habit {
            return habits.first(where: { $0.id == selected.id }) ?? habits.first
        }
        return habits.first
    }
}

// MARK: - Widget View

@available(iOS 17.0, *)
struct GenericHabitView: View {
    let entry: HabitEntry

    var body: some View {
        Group {
            if let habit = entry.habit {
                content(for: habit)
            } else {
                Text("No habit")
                    .font(.caption2)
            }
        }
    }

    private func content(for habit: Habit) -> some View {
        let value = entry.state.values[habit.id] ?? 0
        let isDone = value > 0
        let streak = entry.state.streaksByHabit[habit.id] ?? 0
        
        return HStack(spacing: 8) {
            // Left: habit icon
            Image(systemName: habit.symbolName)
                .font(.system(size: 18, weight: .semibold))
            
            // Middle: value and name
            VStack(alignment: .leading, spacing: 2) {
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                Text("\(streak)d streak")
                    .font(.caption)
                    .lineLimit(1)
            }
            
            Spacer(minLength: 0)
            
            // Right: big failed / success symbol
            Image(systemName: isDone ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 22, weight: .bold))
        }
        .padding(.horizontal, 4)
        .containerBackground(for: .widget) { Color.clear }
    }

    private func subtitle(for habit: Habit) -> String {
        switch habit.kind {
        case .boolean:
            return "donzey" // special label so you can see it's using today's state
        case .count(let max):
            return "of \(max)"
        }
    }
}

// MARK: - Widget Definition

@available(iOS 17.0, *)
struct GenericHabitWidget: Widget {
    let kind: String = "GenericHabitWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: HabitWidgetIntent.self,
                               provider: GenericHabitProvider()) { entry in
            GenericHabitView(entry: entry)
                .widgetURL(URL(string: "habittrack://open")!)
        }
        .configurationDisplayName("Habit")
        .description("Show progress for a habit.")
        .supportedFamilies([.accessoryRectangular])
    }
}

@available(iOS 17.0, *)
struct HabitLockscreenWidgetBundle: WidgetBundle {
    var body: some Widget {
        GenericHabitWidget()
    }
}

#endif

