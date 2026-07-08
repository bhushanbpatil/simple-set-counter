//
//  RoutineEditorView.swift
//  Simple Set Counter
//

import SwiftUI
import SwiftData

private struct TagPickerItem: Identifiable {
    let id: UUID
}

private enum RoutineConfirm: Identifiable {
    case deleteTag(ExerciseTag)
    case removeExercise(Exercise)
    case deleteExercise(Exercise)

    var id: String {
        switch self {
        case .deleteTag(let tag): return "tag-\(tag.id.uuidString)"
        case .removeExercise(let exercise): return "remove-\(exercise.id.uuidString)"
        case .deleteExercise(let exercise): return "delete-\(exercise.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .deleteTag(let tag): return "Delete tag \"\(tag.name)\"?"
        case .removeExercise(let exercise): return "Remove \"\(exercise.name)\"?"
        case .deleteExercise(let exercise): return "Delete \"\(exercise.name)\"?"
        }
    }

    var message: String {
        switch self {
        case .deleteTag: return "Exercises will move to General."
        case .removeExercise: return "It will be removed from your routine."
        case .deleteExercise: return "History is kept, but it won't appear in your routine."
        }
    }

    var actionTitle: String {
        switch self {
        case .deleteTag: return "Delete Tag"
        case .removeExercise: return "Remove"
        case .deleteExercise: return "Delete Exercise"
        }
    }
}

struct RoutineEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \ExerciseTag.sortOrder) private var tags: [ExerciseTag]

    @State private var newTagName = ""
    @State private var addExerciseTag: TagPickerItem?
    @State private var pendingConfirm: RoutineConfirm?
    @FocusState private var newTagFocused: Bool
    @State private var editModeState: EditMode = .inactive

    private var sortedTags: [ExerciseTag] { RoutineCatalog.sortedTags(tags) }
    private var optionalTags: [ExerciseTag] {
        sortedTags.filter { $0.name != RoutineCatalog.generalTagName }
    }

    private var isEditing: Bool { editModeState.isEditing }
    private var hasReorderableExercises: Bool {
        sortedTags.contains { $0.visibleExercises.count > 1 }
    }

    var body: some View {
        List {
            Section {
                Text("General is the default tag. Use the folder button to move exercises between tags.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .listRowBackground(AppTheme.card)

                if hasReorderableExercises {
                    reorderHintRow
                        .listRowBackground(AppTheme.card)
                }

                newTagRow
                    .listRowBackground(AppTheme.card)
            }

            ForEach(sortedTags) { tag in
                Section {
                    if tag.visibleExercises.isEmpty {
                        Text("No exercises yet — tap Add Exercise below.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.secondaryText)
                            .listRowBackground(AppTheme.card)
                    } else {
                        ForEach(tag.visibleExercises) { exercise in
                            exerciseRow(exercise, in: tag)
                                .listRowBackground(AppTheme.card)
                        }
                        .onMove { source, destination in
                            RoutineCatalog.reorderExercises(in: tag, from: source, to: destination, context: modelContext)
                        }
                    }

                    Button {
                        addExerciseTag = TagPickerItem(id: tag.id)
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .foregroundStyle(AppTheme.accent)
                    }
                    .listRowBackground(AppTheme.card)
                } header: {
                    tagSectionHeader(tag)
                } footer: {
                    if tag.visibleExercises.count > 1, !isEditing {
                        Text("Tap Edit above, then drag the handles on the right.")
                            .font(.caption)
                            .foregroundStyle(AppTheme.secondaryText)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppTheme.background)
        .navigationTitle("My Routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
                    .foregroundStyle(AppTheme.accent)
                    .disabled(!hasReorderableExercises)
            }
        }
        .environment(\.editMode, $editModeState)
        .sheet(item: $addExerciseTag) { item in
            if let tag = tags.first(where: { $0.id == item.id }) {
                AddExerciseToTagSheet(tag: tag)
            }
        }
        .alert(
            pendingConfirm?.title ?? "",
            isPresented: Binding(
                get: { pendingConfirm != nil },
                set: { if !$0 { pendingConfirm = nil } }
            ),
            presenting: pendingConfirm
        ) { confirm in
            Button(confirm.actionTitle) {
                performConfirm(confirm)
            }
            Button("Cancel", role: .cancel) {}
        } message: { confirm in
            Text(confirm.message)
        }
        .onAppear {
            RoutineCatalog.ensureGeneralTag(context: modelContext)
            for tag in tags {
                RoutineCatalog.normalizeMembershipSortOrders(for: tag, context: modelContext)
            }
        }
    }

    private var reorderHintRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(AppTheme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(isEditing ? "Drag exercises to reorder" : "Reorder exercises")
                    .font(.subheadline.weight(.semibold))
                Text(isEditing ? "Use the handles on the right of each row." : "Tap Edit in the top-right corner.")
                    .font(.caption)
                    .foregroundStyle(AppTheme.secondaryText)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }

    private var newTagRow: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(optionalTags.isEmpty ? "Optional tags" : "New tag")
                .font(.caption.bold())
                .foregroundStyle(AppTheme.secondaryText)

            HStack(spacing: 12) {
                TextField("Tag name", text: $newTagName, prompt: Text("Upper Body, Leg Day…"))
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($newTagFocused)
                    .onSubmit { addTag() }

                Button("Add") { addTag() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.accent)
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.vertical, 4)
    }

    private func tagSectionHeader(_ tag: ExerciseTag) -> some View {
        HStack {
            Text(tag.name)
            if tag.name == RoutineCatalog.generalTagName {
                Text("default")
                    .font(.caption2.bold())
                    .foregroundStyle(AppTheme.secondaryText)
            }
            Spacer()
            if tag.name != RoutineCatalog.generalTagName {
                Button {
                    pendingConfirm = .deleteTag(tag)
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(AppTheme.accent.opacity(0.85))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func exerciseRow(_ exercise: Exercise, in tag: ExerciseTag) -> some View {
        HStack(spacing: 12) {
            if !isEditing {
                Image(systemName: "line.3.horizontal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.secondaryText.opacity(0.45))
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
            }

            Spacer()

            if !isEditing {
                if sortedTags.count > 1 {
                    Menu {
                        ForEach(sortedTags.filter { $0.id != tag.id }) { destination in
                            Button(destination.name) {
                                RoutineCatalog.moveExercise(exercise, from: tag, to: destination, context: modelContext)
                            }
                        }
                    } label: {
                        Image(systemName: "folder")
                            .foregroundStyle(AppTheme.accent)
                    }
                    .accessibilityLabel("Move to tag")
                }

                Button {
                    pendingConfirm = .removeExercise(exercise)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(AppTheme.accent.opacity(0.9))
                }
                .buttonStyle(.plain)
            }
        }
        .contextMenu {
            Button("Remove from routine") {
                pendingConfirm = .removeExercise(exercise)
            }
            if exercise.isCustom {
                Button("Delete exercise") {
                    pendingConfirm = .deleteExercise(exercise)
                }
            }
            if sortedTags.count > 1 {
                Menu("Move to tag") {
                    ForEach(sortedTags.filter { $0.id != tag.id }) { destination in
                        Button(destination.name) {
                            RoutineCatalog.moveExercise(exercise, from: tag, to: destination, context: modelContext)
                        }
                    }
                }
            }
        }
    }

    private func performConfirm(_ confirm: RoutineConfirm) {
        switch confirm {
        case .deleteTag(let tag):
            RoutineCatalog.deleteTag(tag, context: modelContext)
        case .removeExercise(let exercise):
            RoutineCatalog.removeFromRoutine(exercise, context: modelContext)
        case .deleteExercise(let exercise):
            RoutineCatalog.hideExercise(exercise, context: modelContext)
        }
    }

    private func addTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard trimmed != RoutineCatalog.generalTagName else { return }
        let tag = ExerciseTag(name: trimmed, sortOrder: tags.count)
        modelContext.insert(tag)
        try? modelContext.save()
        newTagName = ""
        newTagFocused = false
    }
}

private struct AddExerciseToTagSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var tag: ExerciseTag
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var search = ""
    @State private var debouncedSearch = ""
    @State private var customName = ""

    private var availableExercises: [Exercise] {
        let inTag = Set(tag.memberships.compactMap { $0.exercise?.id })
        return allExercises.filter { exercise in
            !exercise.isHidden &&
            !inTag.contains(exercise.id) &&
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
                        Text(debouncedSearch.isEmpty ? "All catalog exercises are in this tag." : "No matches.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(availableExercises) { exercise in
                            Button {
                                RoutineCatalog.addExercise(exercise, to: tag, context: modelContext)
                                dismiss()
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
            .navigationTitle("Add to \(tag.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func createCustom() {
        let trimmed = customName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if RoutineCatalog.addCustomExercise(name: trimmed, to: tag, context: modelContext) != nil {
            customName = ""
            dismiss()
        }
    }
}

#Preview {
    NavigationStack {
        RoutineEditorView()
    }
    .modelContainer(for: [Exercise.self, ExerciseTag.self, TaggedExercise.self, WorkoutSession.self, LoggedSet.self], inMemory: true)
}
