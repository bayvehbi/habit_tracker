import SwiftUI
import WidgetKit

struct AddTodayView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HabitViewModel

    @State private var inputValues: [UUID: Int] = [:]

    var body: some View {
        NavigationStack {
            Form {
                ForEach(viewModel.habits) { habit in
                    Section(habit.name) {
                        logEditor(for: habit)
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
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func logEditor(for habit: Habit) -> some View {
        let todayTotal = viewModel.value(for: habit)
        let input = Binding(
            get: { inputValues[habit.id] ?? 1 },
            set: { inputValues[habit.id] = max(1, $0) }
        )
        
        VStack(spacing: 8) {
            HStack {
                Text("Today total")
                Spacer()
                Text("\(todayTotal)")
                    .fontWeight(.semibold)
            }
            
            switch habit.kind {
            case .boolean:
                let isDoneToday = todayTotal > 0
                Button {
                    viewModel.addLog(for: habit, value: 1)
                    WidgetCenter.shared.reloadAllTimelines()
                } label: {
                    Label(isDoneToday ? "Already done today" : "Log done now", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isDoneToday)
            case .count:
                Stepper("Log amount: \(input.wrappedValue)", value: input, in: 1...10_000)
                HStack(spacing: 8) {
                    quickAddButton(label: "+1", amount: 1, value: input)
                    quickAddButton(label: "+5", amount: 5, value: input)
                    quickAddButton(label: "+10", amount: 10, value: input)
                }
                Button {
                    viewModel.addLog(for: habit, value: input.wrappedValue)
                    WidgetCenter.shared.reloadAllTimelines()
                } label: {
                    Label("Add log entry", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func quickAddButton(
        label: String,
        amount: Int,
        value: Binding<Int>
    ) -> some View {
        Button(label) {
            value.wrappedValue = max(1, value.wrappedValue + amount)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

