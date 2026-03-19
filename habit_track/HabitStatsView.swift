import SwiftUI
import WidgetKit

struct HabitStatsView: View {
    @ObservedObject var viewModel: HabitViewModel
    let habit: Habit

    @State private var monthCursor = Date()
    @State private var editingLog: HabitLog?
    @State private var editValueText: String = ""
    private let calendar = Calendar.current

    var body: some View {
        List {
            Section("Overview") {
                metricRow(title: "Current streak", value: "\(viewModel.streak(for: habit)) days", icon: "flame.fill")
                metricRow(title: "Best streak", value: "\(viewModel.bestStreak(for: habit)) days", icon: "trophy.fill")
                metricRow(title: "Completed days", value: "\(viewModel.totalCompletedDays(for: habit))", icon: "checkmark.circle.fill")
                metricRow(title: "Total logged", value: "\(viewModel.totalLoggedValue(for: habit))", icon: habit.symbolName)
            }

            Section {
                monthHeader
                MonthCalendarGrid(
                    month: monthCursor,
                    completedDates: Set(viewModel.completedDates(for: habit, in: monthCursor).map { calendar.startOfDay(for: $0) })
                )
            } header: {
                Text("Calendar")
            } footer: {
                Text("Marked days are days you completed this habit.")
            }

            Section {
                if groupedLogs.isEmpty {
                    Text("No logs yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(groupedLogs, id: \.day) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.day)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            ForEach(section.logs) { log in
                                logRow(log)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Logs (latest first)")
            } footer: {
                Text("Logs can only be edited or deleted within 24 hours after they are created.")
            }
        }
        .navigationTitle(habit.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { viewModel.refresh() }
        .alert("Edit Log", isPresented: Binding(
            get: { editingLog != nil },
            set: { isPresented in
                if !isPresented {
                    editingLog = nil
                    editValueText = ""
                }
            })
        ) {
            TextField("New value", text: $editValueText)
                .keyboardType(.numberPad)
            Button("Save") { saveEdit() }
            Button("Cancel", role: .cancel) {
                editingLog = nil
                editValueText = ""
            }
        } message: {
            Text("Enter the updated value for this log.")
        }
    }

    private func metricRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Label(title, systemImage: icon)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }

    private var groupedLogs: [(day: String, logs: [HabitLog])] {
        let logs = viewModel.logs(for: habit)
        let grouped = Dictionary(grouping: logs) { dayTitle(for: $0.timestamp) }
        return grouped
            .map { (day: $0.key, logs: $0.value.sorted { $0.timestamp > $1.timestamp }) }
            .sorted { lhs, rhs in
                guard let left = lhs.logs.first?.timestamp, let right = rhs.logs.first?.timestamp else {
                    return false
                }
                return left > right
            }
    }

    private func logRow(_ log: HabitLog) -> some View {
        let canModify = viewModel.canEditOrDelete(log)
        return HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("+\(log.value)")
                    .font(.headline)
                Text(timeTitle(for: log.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if canModify {
                Button {
                    editingLog = log
                    editValueText = "\(log.value)"
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(role: .destructive) {
                    _ = viewModel.deleteLog(for: habit, logID: log.id)
                    WidgetCenter.shared.reloadAllTimelines()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            } else {
                Text("Locked")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func saveEdit() {
        guard let log = editingLog, let value = Int(editValueText), value > 0 else { return }
        _ = viewModel.updateLog(for: habit, logID: log.id, newValue: value)
        WidgetCenter.shared.reloadAllTimelines()
        editingLog = nil
        editValueText = ""
    }

    private func dayTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func timeTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var monthHeader: some View {
        HStack {
            Button {
                shiftMonth(by: -1)
            } label: {
                Image(systemName: "chevron.left")
            }

            Spacer()

            Text(monthTitle(monthCursor))
                .font(.headline)

            Spacer()

            Button {
                shiftMonth(by: 1)
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(isShowingCurrentMonthOrLater)
        }
        .buttonStyle(.plain)
    }

    private func monthTitle(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: date)
    }

    private var isShowingCurrentMonthOrLater: Bool {
        let current = calendar.dateComponents([.year, .month], from: Date())
        let shown = calendar.dateComponents([.year, .month], from: monthCursor)
        return shown.year == current.year && shown.month == current.month
    }

    private func shiftMonth(by value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: monthCursor) {
            monthCursor = next
        }
    }
}

private struct MonthCalendarGrid: View {
    let month: Date
    let completedDates: Set<Date>
    private let calendar = Calendar.current

    var body: some View {
        let days = buildDayCells(for: month)
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

        VStack(spacing: 8) {
            HStack(spacing: 4) {
                ForEach(shortWeekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let date = day {
                        let isCompleted = completedDates.contains(calendar.startOfDay(for: date))
                        ZStack {
                            Circle()
                                .fill(isCompleted ? Color.green.opacity(0.25) : Color.clear)
                                .overlay(
                                    Circle()
                                        .stroke(isCompleted ? Color.green : Color.secondary.opacity(0.25), lineWidth: 1)
                                )
                            Text("\(calendar.component(.day, from: date))")
                                .font(.caption2.weight(.medium))
                        }
                        .frame(height: 28)
                    } else {
                        Color.clear
                            .frame(height: 28)
                    }
                }
            }
        }
    }

    private var shortWeekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let start = calendar.firstWeekday - 1
        let leading = Array(symbols[start...])
        let trailing = Array(symbols[..<start])
        return leading + trailing
    }

    private func buildDayCells(for month: Date) -> [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: interval.start),
              let lastWeek = calendar.dateInterval(of: .weekOfMonth, for: interval.end.addingTimeInterval(-1)),
              let range = calendar.dateComponents([.day], from: firstWeek.start, to: lastWeek.end).day else {
            return []
        }

        return (0..<range).map { offset in
            guard let date = calendar.date(byAdding: .day, value: offset, to: firstWeek.start) else {
                return nil
            }
            return calendar.isDate(date, equalTo: month, toGranularity: .month) ? date : nil
        }
    }
}
