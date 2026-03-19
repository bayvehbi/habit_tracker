//
//  ContentView.swift
//  habit_track
//
//  Created by Vehbi baycan on 16/3/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = HabitViewModel()
    @State private var showingAddToday = false
    @State private var showingManageHabits = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today")
                            .font(.title.bold())
                        Text("Keep your streak alive by completing both.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(viewModel.habits) { habit in
                            NavigationLink {
                                HabitStatsView(viewModel: viewModel, habit: habit)
                            } label: {
                                summaryCard(
                                    title: habit.name,
                                    value: "\(viewModel.value(for: habit))",
                                    unit: unitLabel(for: habit),
                                    systemImage: habit.symbolName,
                                    isDone: viewModel.value(for: habit) > 0,
                                    streak: viewModel.streak(for: habit)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button {
                        showingAddToday = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add / update today")
                                .fontWeight(.semibold)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .navigationTitle("Habit Track")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingManageHabits = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                }
            }
            .sheet(isPresented: $showingAddToday, onDismiss: {
                viewModel.refresh()
            }) {
                AddTodayView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingManageHabits, onDismiss: {
                viewModel.refresh()
            }) {
                ManageHabitsView(viewModel: viewModel)
            }
            .onAppear {
                viewModel.refresh()
            }
        }
    }

    private func summaryCard(
        title: String,
        value: String,
        unit: String,
        systemImage: String,
        isDone: Bool,
        streak: Int
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .font(.system(size: 22))
                    .foregroundStyle(isDone ? Color.green : Color.gray)
                Spacer()
                if isDone {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                Text(unit)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Label("\(streak) day streak", systemImage: "flame.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(streak > 0 ? Color.orange : Color.secondary)

            Text(title)
                .font(.subheadline.weight(.semibold))
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private func unitLabel(for habit: Habit) -> String {
        switch habit.kind {
        case .boolean:
            return "done"
        case .count(let max):
            if max == 1 {
                return "time"
            } else {
                return "of \(max)"
            }
        }
    }
}

#Preview {
    ContentView()
}
