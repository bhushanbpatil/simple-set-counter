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

    @AppStorage(AppSettings.accentColorKey) private var accentColorRaw = AccentColorOption.lime.rawValue
    @AppStorage(AppSettings.guidedWorkoutFlowKey) private var guidedWorkoutFlow = false
    @State private var showSettings = false
    @State private var showRoutineEditor = false
    @State private var showAddExercise = false
    @State private var addingExercise: Exercise?
    @State private var showFinishConfirm = false
    @State private var restTimerEndsAt: Date?
    @State private var restTimerTotalDuration: TimeInterval = 90
    @State private var workoutSummary: WorkoutSummaryData?

    private var activeSession: WorkoutSession? { activeSessions.first }
    private var displayTags: [ExerciseTag] {
        if guidedWorkoutFlow {
            return WorkoutFlow.tagsForToday(tags, session: activeSession)
        }
        return RoutineCatalog.sortedTags(tags)
    }
    private var routineExerciseCount: Int {
        displayTags.reduce(0) { $0 + $1.visibleExercises.count }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                todayScrollContent
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
                    suggestedReps: suggestedReps(for: exercise),
                    onSetSaved: handleSetSaved
                )
            }
            .sheet(item: $workoutSummary) { summary in
                WorkoutSummarySheet(summary: summary)
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
                for tag in tags {
                    RoutineCatalog.normalizeMembershipSortOrders(for: tag, context: modelContext)
                }
            }
            .onChange(of: guidedWorkoutFlow) { _, enabled in
                if !enabled { clearRestTimer() }
            }
        }
    }

    @ViewBuilder
    private var todayScrollContent: some View {
        VStack(spacing: 16) {
            headerCard
            guidedWorkoutSections
            routineListSection
            addExerciseButton
        }
    }

    @ViewBuilder
    private var guidedWorkoutSections: some View {
        if guidedWorkoutFlow, let endsAt = restTimerEndsAt {
            RestTimerBanner(
                endsAt: endsAt,
                totalDuration: restTimerTotalDuration,
                onSkip: clearRestTimer,
                onAddTime: { addRestTime(15) },
                onComplete: completeRestTimer
            )
        }

        if guidedWorkoutFlow,
           let session = activeSession,
           let current = WorkoutFlow.currentExercise(in: session, tags: tags) {
            nowCard(session: session, exercise: current)
        }
    }

    @ViewBuilder
    private var routineListSection: some View {
        if routineExerciseCount == 0 {
            emptyRoutineCard
        } else {
            ForEach(displayTags) { tag in
                if !tag.visibleExercises.isEmpty {
                    tagSection(for: tag)
                }
            }
        }
    }

    private var addExerciseButton: some View {
        Button {
            showAddExercise = true
        } label: {
            Label("Add Exercise", systemImage: "plus.circle.fill")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(AppTheme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private func tagSection(for tag: ExerciseTag) -> some View {
        let isActive = guidedWorkoutFlow
            && activeSession.flatMap { WorkoutFlow.activeTagID(in: $0) } == tag.id

        return TodayTagSection(
            tag: tag,
            session: activeSession,
            isActiveTag: isActive,
            simpleMode: !guidedWorkoutFlow
        ) { exercise in
            ExerciseSetBlock(
                exercise: exercise,
                session: activeSession,
                onAddSet: { beginAddingSet(for: exercise, in: tag) },
                onSelect: guidedWorkoutFlow ? { startExercise(exercise, in: tag) } : nil
            )
        }
    }

    private func nowCard(session: WorkoutSession, exercise: Exercise) -> some View {
        let loggedSets = WorkoutFlow.sets(for: exercise, in: session)
        let nextName = WorkoutFlow.nextExerciseName(in: session, tags: tags)
        let queueCount = WorkoutFlow.queueIDs(in: session).count

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("NOW")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accent)
                if let tag = WorkoutFlow.currentTag(in: session, tags: tags) {
                    Text("· \(tag.name)")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
                if !loggedSets.isEmpty {
                    Text("\(loggedSets.count) set\(loggedSets.count == 1 ? "" : "s")")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.accent)
                }
            }

            Text(exercise.name)
                .font(.title2.weight(.bold))

            if loggedSets.isEmpty {
                Text("No sets logged yet")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(loggedSets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("Set \(index + 1)")
                                .foregroundStyle(AppTheme.secondaryText)
                                .frame(width: 48, alignment: .leading)
                            Text(set.isBodyweight ? "BW" : AppSettings.formatWeight(set.weight))
                            Text("×")
                                .foregroundStyle(AppTheme.secondaryText)
                            Text("\(set.reps) reps")
                            Spacer()
                            Button {
                                deleteSet(set)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.accent.opacity(0.85))
                            }
                            .buttonStyle(.plain)
                        }
                        .font(.subheadline.weight(.semibold))
                    }
                }
            }

            if let nextName, queueCount > 1 {
                Text("Next: \(nextName)")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }

            HStack(spacing: 12) {
                Button {
                    beginAddingSet(for: exercise, in: WorkoutFlow.currentTag(in: session, tags: tags))
                } label: {
                    Label("Log set", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.accent.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                if queueCount > 1 {
                    Button {
                        clearRestTimer()
                        WorkoutFlow.advanceToNext(in: session, tags: tags, context: modelContext)
                    } label: {
                        Text("Next")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppTheme.accent.opacity(0.35))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
            .foregroundStyle(.white)

            if queueCount > 1 {
                Button {
                    clearRestTimer()
                    WorkoutFlow.skipCurrentToBack(in: session, context: modelContext)
                } label: {
                    Text("Skip to back")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(16)
        .background(AppTheme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(AppTheme.accent.opacity(0.55), lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var headerCard: some View {
        Group {
            if let session = activeSession, !session.sets.isEmpty {
                SwipeToFinishCard(
                    hint: "Swipe right to finish",
                    revealTitle: "Finish workout"
                ) {
                    showFinishConfirm = true
                } content: {
                    inProgressHeaderContent(session: session)
                }
            } else {
                inProgressHeaderContent(session: activeSession)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func inProgressHeaderContent(session: WorkoutSession?) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(activeSession == nil ? "Ready to train" : "In progress")
                    .font(.caption.bold())
                    .foregroundStyle(AppTheme.accent)
                Text(Date.now, format: .dateTime.weekday(.wide).month().day())
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            if let session, !session.sets.isEmpty {
                VStack(alignment: .trailing, spacing: 4) {
                    WorkoutElapsedLabel(startedAt: session.startedAt, isActive: session.isActive)
                    Text("\(session.sets.count) sets")
                        .font(.caption)
                        .foregroundStyle(AppTheme.secondaryText)
                }
            } else if let session {
                Text("\(session.sets.count) sets")
                    .font(.headline)
            }
        }
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

    private func startExercise(_ exercise: Exercise, in tag: ExerciseTag) {
        let session = sessionForLogging()
        WorkoutFlow.startExercise(exercise, in: tag, session: session, context: modelContext)
    }

    private func beginAddingSet(for exercise: Exercise, in tag: ExerciseTag?) {
        let session = sessionForLogging()

        if !guidedWorkoutFlow {
            addingExercise = exercise
            return
        }

        let resolvedTag = tag ?? WorkoutFlow.tag(containing: exercise, in: tags)
        guard let resolvedTag else {
            addingExercise = exercise
            return
        }

        if WorkoutFlow.currentExerciseID(in: session) == exercise.id,
           WorkoutFlow.activeTagID(in: session) == resolvedTag.id {
            // Already on this exercise — log another set without reshuffling the queue.
            WorkoutFlow.setCurrentExercise(exercise, in: resolvedTag, session: session, context: modelContext)
        } else {
            WorkoutFlow.startExercise(exercise, in: resolvedTag, session: session, context: modelContext)
        }
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
        if let suggestion = AppSettings.smartIncreaseSuggestion(for: exercise.id) {
            return suggestion.weight
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
        if let suggestion = AppSettings.smartIncreaseSuggestion(for: exercise.id) {
            return suggestion.reps
        }
        if let last = ProgressCalculator.fetchLastSet(for: exercise, before: session, context: modelContext) {
            return last.reps
        }
        return 8
    }

    private func finishWorkout() {
        guard let session = activeSession else { return }
        clearRestTimer()
        AppSettings.applySmartIncrease(after: session)
        WorkoutFlow.clearFlow(in: session)
        session.endedAt = .now
        try? modelContext.save()
        workoutSummary = WorkoutSummaryBuilder.build(from: session)
    }

    private func handleSetSaved() {
        guard guidedWorkoutFlow, AppSettings.restTimerEnabled else { return }
        startRestTimer()
    }

    private func startRestTimer() {
        let duration = TimeInterval(AppSettings.restTimerDuration)
        restTimerTotalDuration = duration
        restTimerEndsAt = Date().addingTimeInterval(duration)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func clearRestTimer() {
        restTimerEndsAt = nil
    }

    private func addRestTime(_ seconds: TimeInterval) {
        guard let endsAt = restTimerEndsAt else { return }
        restTimerEndsAt = endsAt.addingTimeInterval(seconds)
        restTimerTotalDuration += seconds
    }

    private func completeRestTimer() {
        guard restTimerEndsAt != nil else { return }
        clearRestTimer()
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func deleteSet(_ set: LoggedSet) {
        modelContext.delete(set)
        try? modelContext.save()
    }
}

private struct WorkoutElapsedLabel: View {
    let startedAt: Date
    let isActive: Bool

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let end = isActive ? context.date : startedAt
            Text(AppSettings.formatDuration(end.timeIntervalSince(startedAt)))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
    }
}

struct TodayTagSection: View {
    let tag: ExerciseTag
    let session: WorkoutSession?
    let isActiveTag: Bool
    var simpleMode: Bool = false
    let exerciseContent: (Exercise) -> ExerciseSetBlock

    @State private var isCollapsed: Bool

    init(
        tag: ExerciseTag,
        session: WorkoutSession?,
        isActiveTag: Bool,
        simpleMode: Bool = false,
        @ViewBuilder exerciseContent: @escaping (Exercise) -> ExerciseSetBlock
    ) {
        self.tag = tag
        self.session = session
        self.isActiveTag = isActiveTag
        self.simpleMode = simpleMode
        self.exerciseContent = exerciseContent
        _isCollapsed = State(initialValue: AppSettings.isTagCollapsed(tag.id) && !isActiveTag)
    }

    private var visibleExercises: [Exercise] {
        if simpleMode {
            return tag.visibleExercises
        }
        return WorkoutFlow.visibleExercises(in: tag, session: session)
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
                    Spacer()
                    Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .buttonStyle(.plain)

            if !isCollapsed {
                ForEach(visibleExercises) { exercise in
                    exerciseContent(exercise)
                }
            }
        }
        .onChange(of: isActiveTag) { _, active in
            if active { isCollapsed = false }
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
    @State private var selectedTagID: UUID?

    private var sortedTags: [ExerciseTag] { RoutineCatalog.sortedTags(tags) }

    private var selectedTag: ExerciseTag? {
        if let id = selectedTagID {
            return sortedTags.first { $0.id == id }
        }
        return sortedTags.first
    }

    private var sortedTagsFlat: [Exercise] {
        sortedTags.flatMap(\.visibleExercises)
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
                Section("Add to tag") {
                    Picker("Tag", selection: $selectedTagID) {
                        ForEach(sortedTags) { tag in
                            Text(tag.name).tag(Optional(tag.id))
                        }
                    }
                }

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
                                addToSelectedTag(exercise)
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
                _ = RoutineCatalog.ensureGeneralTag(context: modelContext)
                if selectedTagID == nil {
                    selectedTagID = AppSettings.lastUsedTagID ?? sortedTags.first?.id
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func addToSelectedTag(_ exercise: Exercise) {
        guard let tag = selectedTag else { return }
        RoutineCatalog.addExercise(exercise, to: tag, context: modelContext)
        AppSettings.lastUsedTagID = tag.id
        dismiss()
    }

    private func createCustom() {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let tag = selectedTag else { return }
        if RoutineCatalog.addCustomExercise(name: trimmed, to: tag, context: modelContext) != nil {
            AppSettings.lastUsedTagID = tag.id
            customName = ""
            dismiss()
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(for: [Exercise.self, ExerciseTag.self, TaggedExercise.self, WorkoutSession.self, LoggedSet.self], inMemory: true)
}
