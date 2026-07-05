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

    private var sortedTags: [ExerciseTag] { RoutineCatalog.sortedTags(tags) }
    private var optionalTags: [ExerciseTag] {
        sortedTags.filter { $0.name != RoutineCatalog.generalTagName }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("General is the default tag. Use the folder button to move exercises between tags.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                newTagCard

                ForEach(sortedTags) { tag in
                    tagCard(tag)
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationTitle("My Routine")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Done") { dismiss() }
            }
        }
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
            Button(confirm.actionTitle, role: .destructive) {
                performConfirm(confirm)
            }
            Button("Cancel", role: .cancel) {}
        } message: { confirm in
            Text(confirm.message)
        }
        .onAppear {
            RoutineCatalog.ensureGeneralTag(context: modelContext)
        }
    }

    private var newTagCard: some View {
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
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func tagCard(_ tag: ExerciseTag) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(tag.name)
                    .font(.headline)
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
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.plain)
                }
            }

            if tag.visibleExercises.isEmpty {
                Text("No exercises yet — tap Add Exercise below.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.secondaryText)
            } else {
                ForEach(tag.visibleExercises) { exercise in
                    exerciseRow(exercise, in: tag)

                    if exercise.id != tag.visibleExercises.last?.id {
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                }
            }

            Button {
                addExerciseTag = TagPickerItem(id: tag.id)
            } label: {
                Label("Add Exercise", systemImage: "plus")
                    .foregroundStyle(AppTheme.accent)
            }
            .font(.subheadline.weight(.semibold))
        }
        .padding(16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func exerciseRow(_ exercise: Exercise, in tag: ExerciseTag) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                if exercise.isCustom {
                    Text("Custom")
                        .font(.caption2.bold())
                        .foregroundStyle(AppTheme.accent)
                }
            }

            Spacer()

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
                    .foregroundStyle(.orange.opacity(0.9))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contextMenu {
            Button("Remove from routine", role: .destructive) {
                pendingConfirm = .removeExercise(exercise)
            }
            if exercise.isCustom {
                Button("Delete exercise", role: .destructive) {
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
