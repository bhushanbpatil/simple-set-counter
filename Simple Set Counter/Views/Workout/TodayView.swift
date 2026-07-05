//
//  TodayView.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var activeSessions: [WorkoutSession]
    @Query(sort: \ExerciseTag.sortOrder) private var tags: [ExerciseTag]

    @State private var showSettings = false
    @State private var showRoutineEditor = false
    @State private var showAddExercise = false
    @State private var addingExercise: Exercise?
    @State private var showFinishConfirm = false

    private var activeSession: WorkoutSession? { activeSessions.first }
    private var sortedTags: [ExerciseTag] { RoutineCatalog.sortedTags(tags) }
    private var routineExerciseCount: Int {
        sortedTags.reduce(0) { $0 + $1.visibleExercises.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headerCard

                    if routineExerciseCount == 0 {
                        emptyRoutineCard
                    } else {
                        ForEach(sortedTags) { tag in
                            if !tag.visibleExercises.isEmpty {
                                TodayTagSection(tag: tag) { exercise in
                                    ExerciseSetBlock(
                                        exercise: exercise,
                                        session: activeSession,
                                        onAddSet: { beginAddingSet(for: exercise) }
                                    )
                                }
                            }
                        }
                    }

                    Button {
                        showAddExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(AppTheme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    if activeSession != nil, activeSession?.sets.isEmpty == false {
                        Button("Finish Workout") {
                            showFinishConfirm = true
                        }
                        .buttonStyle(.primary)
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background)
            .foregroundStyle(.white)
            .navigationTitle("Today")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showRoutineEditor = true
                    } label: {
                        Text("Routine")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack { SettingsView() }
            }
            .sheet(isPresented: $showRoutineEditor) {
                NavigationStack { RoutineEditorView() }
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showAddExercise) {
                AddExerciseToRoutineSheet()
            }
            .sheet(item: $addingExercise) { exercise in
                AddSetSheet(
                    exercise: exercise,
                    session: sessionForLogging(),
                    suggestedWeight: suggestedWeight(for: exercise),
                    suggestedReps: suggestedReps(for: exercise)
                )
            }
            .alert("Finish this workout?", isPresented: $showFinishConfirm) {
                Button("Finish") { finishWorkout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Your sets will be saved to History.")
            }
            .onAppear {
                RoutineCatalog.ensureGeneralTag(context: modelContext)
                RoutineCatalog.finishStaleSessions(activeSessions, context: modelContext)
            }
        }
    }

    private var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(activeSession == nil ? "Ready to train" : "In progress")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accent)
                Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            if let session = activeSession {
                Text("\(session.sets.count) sets")
                    .font(.headline)
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var emptyRoutineCard: some View {
        VStack(spacing: 12) {
            Text("Add your usual exercises")
                .font(.headline)
            Text("They'll show up here every day. Tags like Upper Body are optional — General is the default.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
            Button("Edit Routine") {
                showRoutineEditor = true
            }
            .buttonStyle(.primary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func beginAddingSet(for exercise: Exercise) {
        _ = sessionForLogging()
        addingExercise = exercise
    }

    @discardableResult
    private func sessionForLogging() -> WorkoutSession {
        if let session = activeSession { return session }
        let session = WorkoutSession()
        modelContext.insert(session)
        try? modelContext.save()
        return session
    }

    private func suggestedWeight(for exercise: Exercise) -> Double {
        let session = activeSession ?? sessionForLogging()
        if let last = session.sortedSets.filter({ $0.exercise?.id == exercise.id }).last, !last.isBodyweight {
            return last.weight
        }
        if let last = ProgressCalculator.fetchLastSet(for: exercise, before: session, context: modelContext), !last.isBodyweight {
            return last.weight
        }
        return 0
    }

    private func suggestedReps(for exercise: Exercise) -> Int {
        let session = activeSession ?? sessionForLogging()
        if let last = session.sortedSets.filter({ $0.exercise?.id == exercise.id }).last {
            return last.reps
        }
        if let last = ProgressCalculator.fetchLastSet(for: exercise, before: session, context: modelContext) {
            return last.reps
        }
        return 8
    }

    private func finishWorkout() {
        activeSession?.endedAt = .now
        try? modelContext.save()
    }
}

struct TodayTagSection: View {
    let tag: ExerciseTag
    let exerciseContent: (Exercise) -> ExerciseSetBlock

    @State private var isCollapsed: Bool

    init(tag: ExerciseTag, @ViewBuilder exerciseContent: @escaping (Exercise) -> ExerciseSetBlock) {
        self.tag = tag
        self.exerciseContent = exerciseContent
        _isCollapsed = State(initialValue: AppSettings.isTagCollapsed(tag.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCollapsed.toggle()
                    AppSettings.setTagCollapsed(tag.id, collapsed: isCollapsed)
                }
            } label: {
                HStack {
                    Text(tag.name)
                        .font(.headline)
                    if tag.name != RoutineCatalog.generalTagName {
                        Text("tag")
                            .font(.caption2.bold())
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                    Spacer()
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                ForEach(tag.visibleExercises) { exercise in
                    exerciseContent(exercise)
                }
            }
        }
    }
}

private struct AddExerciseToRoutineSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @Query(sort: \ExerciseTag.sortOrder) private var tags: [ExerciseTag]

    @State private var search = ""
    @State private var debouncedSearch = ""
    @State private var customName = ""
    @State private var generalTag: ExerciseTag?

    private var sortedTagsFlat: [Exercise] {
        RoutineCatalog.sortedTags(tags).flatMap(\.visibleExercises)
    }

    private var availableExercises: [Exercise] {
        let inRoutine = Set(sortedTagsFlat.map(\.id))
        return allExercises.filter { exercise in
            !exercise.isHidden &&
            !inRoutine.contains(exercise.id) &&
            (debouncedSearch.isEmpty || exercise.name.localizedCaseInsensitiveContains(debouncedSearch))
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        TextField("Custom name", text: $customName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit { createCustom() }

                        Button("Create") { createCustom() }
                            .font(.subheadline.weight(.semibold))
                            .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                } header: {
                    Text("New exercise")
                }

                Section {
                    DebouncedSearchField(
                        prompt: "Search catalog",
                        text: $search,
                        debouncedText: $debouncedSearch
                    )
                }

                Section("Catalog") {
                    if availableExercises.isEmpty {
                        Text(debouncedSearch.isEmpty ? "All catalog exercises are in your routine." : "No matches.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableExercises) { exercise in
                            Button {
                                addToGeneral(exercise)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                    Text(exercise.category)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                generalTag = RoutineCatalog.ensureGeneralTag(context: modelContext)
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func addToGeneral(_ exercise: Exercise) {
        guard let generalTag else { return }
        RoutineCatalog.addExercise(exercise, to: generalTag, context: modelContext)
        dismiss()
    }

    private func createCustom() {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let generalTag else { return }
        if RoutineCatalog.addCustomExercise(name: trimmed, to: generalTag, context: modelContext) != nil {
            customName = ""
            dismiss()
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [Exercise.self, ExerciseTag.self, TaggedExercise.self, WorkoutSession.self, LoggedSet.self], inMemory: true)
}
