import SwiftUI

struct ManageHabitsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HabitViewModel

    @State private var showingAddSheet = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.habits) { habit in
                    HStack {
                        Image(systemName: habit.symbolName)
                            .frame(width: 24, height: 24)
                        VStack(alignment: .leading) {
                            Text(habit.name)
                            Text(kindDescription(for: habit.kind))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(viewModel.streak(for: habit))d")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { indexSet in
                    for index in indexSet {
                        let habit = viewModel.habits[index]
                        viewModel.deleteHabit(habit)
                    }
                }
            }
            .navigationTitle("Habits")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddHabitView(viewModel: viewModel)
            }
        }
    }

    private func kindDescription(for kind: HabitKind) -> String {
        switch kind {
        case .boolean:
            return "Once per day"
        case .count(let max):
            return "0 – \(max) per day"
        }
    }
}

struct AddHabitView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HabitViewModel

    @State private var name: String = ""
    @State private var symbolName: String = "star.fill"
    @State private var isBoolean: Bool = false
    @State private var maxCount: Double = 50

    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    TextField("Name", text: $name)
                    iconPickerSection
                }

                Section("Type") {
                    Toggle("Boolean (done / not done)", isOn: $isBoolean)

                    if !isBoolean {
                        VStack(alignment: .leading) {
                            Slider(value: $maxCount, in: 1...500, step: 1)
                            Text("Max per day: \(Int(maxCount))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("New Habit")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveHabit() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private var iconPickerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(presetIcons, id: \.self) { icon in
                        Button {
                            symbolName = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.system(size: 20))
                                .frame(width: 36, height: 36)
                                .foregroundStyle(symbolName == icon ? Color.white : Color.primary)
                                .background(
                                    Circle().fill(symbolName == icon ? Color.blue : Color(.secondarySystemBackground))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 4)
            }

            TextField("Or type SF Symbol name", text: $symbolName)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .font(.footnote)
        }
    }

    private var presetIcons: [String] {
        [
            // Fitness / movement
            "figure.walk",
            "figure.run",
            "figure.strengthtraining.traditional",
            "bicycle",
            "flame.fill",

            // Water / food
            "drop.fill",
            "cup.and.saucer.fill",
            "fork.knife",
            "takeoutbag.and.cup.and.straw.fill",

            // Sleep / rest / routine
            "bed.double.fill",
            "alarm.fill",
            "moon.zzz.fill",

            // Health
            "heart.fill",
            "cross.case.fill",
            "bandage.fill",
            "pills.fill",

            // Beauty / self‑care
            "face.smiling",
            "sparkles",
            "wand.and.stars",
            "hand.raised.fill",
            "scissors",

            // Study / work
            "book.fill",
            "laptopcomputer",
            "pencil.and.outline",
            "calendar",

            // Mind / focus / misc
            "brain.head.profile",
            "eye.fill",
            "music.note",
            "gamecontroller.fill",
            "timer"
        ]
    }

    private func saveHabit() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let kind: HabitKind = isBoolean ? .boolean : .count(max: Int(maxCount))
        viewModel.addHabit(name: trimmed, symbolName: symbolName, kind: kind)
        dismiss()
    }
}

