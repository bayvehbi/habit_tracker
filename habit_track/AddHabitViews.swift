import SwiftUI
import WidgetKit

struct AddTodayView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HabitViewModel

    @State private var values: [UUID: Int]

    init(viewModel: HabitViewModel) {
        self.viewModel = viewModel
        _values = State(initialValue:
            Dictionary(uniqueKeysWithValues:
                viewModel.habits.map { ($0.id, viewModel.value(for: $0)) }
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(viewModel.habits) { habit in
                    Section(habit.name) {
                        switch habit.kind {
                        case .boolean:
                            Toggle("Done today", isOn: bindingForBoolean(habit: habit))
                        case .count(let max):
                            countEditor(for: habit, max: max)
                        }
                    }
                }
            }
            .navigationTitle("Add today")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveAll() }
                }
            }
        }
    }

    private func bindingForBoolean(habit: Habit) -> Binding<Bool> {
        Binding(
            get: { (values[habit.id] ?? 0) > 0 },
            set: { values[habit.id] = $0 ? 1 : 0 }
        )
    }

    private func bindingForCount(habit: Habit) -> Binding<Int> {
        Binding(
            get: { values[habit.id] ?? 0 },
            set: { values[habit.id] = $0 }
        )
    }

    @ViewBuilder
    private func countEditor(for habit: Habit, max: Int) -> some View {
        let count = bindingForCount(habit: habit)

        VStack(spacing: 8) {
            Slider(
                value: Binding(
                    get: { Double(count.wrappedValue) },
                    set: { count.wrappedValue = Int($0.rounded()) }
                ),
                in: 0...Double(max)
            )

            HStack {
                Stepper("Count: \(count.wrappedValue)", value: count, in: 0...max)
            }

            HStack(spacing: 8) {
                quickAddButton(label: "+10", amount: 10, value: count, max: max)
                quickAddButton(label: "+20", amount: 20, value: count, max: max)
                quickAddButton(label: "+50", amount: 50, value: count, max: max)
            }
        }
    }

    private func quickAddButton(
        label: String,
        amount: Int,
        value: Binding<Int>,
        max: Int
    ) -> some View {
        Button(label) {
            value.wrappedValue = min(max, value.wrappedValue + amount)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private func saveAll() {
        for habit in viewModel.habits {
            let v = values[habit.id] ?? 0
            viewModel.setValue(for: habit, value: v)
        }
        WidgetCenter.shared.reloadAllTimelines()
        dismiss()
    }
}

