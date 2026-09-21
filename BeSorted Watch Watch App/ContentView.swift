//
//  ContentView.swift
//  BeSorted Watch Watch App
//
//  Created by Michał Wołtosz on 11/09/2026.
//

import SwiftUI
import SwiftData

struct WatchRootView: View {
    var body: some View {
        NavigationStack {
            WatchPlanView()
        }
    }
}

struct WatchPlanView: View {
    @Query(
        filter: #Predicate<ProjectTask> { task in
            task.isInCurrentPlan && !task.isCompleted
        },
        sort: \ProjectTask.createdAt
    ) private var planTasks: [ProjectTask]

    var body: some View {
        Group {
            if planTasks.isEmpty {
                VStack(spacing: 10) {
                    Text("Aktualny Plan")
                        .font(.headline)
                    NavigationLink("Dodaj zadanie") {
                        WatchAddTaskView()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    Section("\(planTasks.count)/\(CurrentPlanStore.maxActiveTasks)") {
                        ForEach(planTasks) { task in
                            NavigationLink {
                                WatchTaskDetailView(task: task)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.name)
                                        .font(.headline)
                                        .lineLimit(2)
                                    if let projectName = task.project?.name {
                                        Text(projectName)
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    NavigationLink("Dodaj zadanie") {
                        WatchAddTaskView()
                    }
                }
            }
        }
        .navigationTitle("Plan")
        .onAppear {
            PhoneWatchSyncService.shared.pushSnapshotNow()
        }
    }
}

struct WatchAddTaskView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Project.createdAt, order: .reverse) private var projects: [Project]

    private var groups: [(project: Project, tasks: [ProjectTask])] {
        projects.compactMap { project in
            let tasks = project.taskList
                .filter { !$0.isCompleted && !$0.isInCurrentPlan && $0.planQueuedAt == nil }
                .sorted { $0.createdAt > $1.createdAt }
            guard !tasks.isEmpty else { return nil }
            return (project, tasks)
        }
    }

    var body: some View {
        List {
            if groups.isEmpty {
                Text("Brak dostępnych zadań")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(groups, id: \.project.persistentModelID) { group in
                    Section(group.project.name) {
                        ForEach(group.tasks) { task in
                            Button {
                                CurrentPlanStore.prioritize(task, in: modelContext)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(task.name)
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                    Text(task.kind.title)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Dodaj")
        .onAppear {
            // Poproś ekosystem o świeży stan z iPhone (jeśli sparowany i aktywny).
            PhoneWatchSyncService.shared.pushSnapshotNow()
        }
    }
}

struct WatchTaskDetailView: View {
    @Bindable var task: ProjectTask
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var showBugQuestion = false
    @State private var showSeverityPicker = false
    @State private var selectedSeverity = 3

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(task.name)
                    .font(.headline)

                if !task.details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(task.details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Usuń z planu", role: .destructive) {
                    CurrentPlanStore.removeFromPlan(task, in: modelContext)
                    dismiss()
                }

                Button("Zrobione") {
                    showBugQuestion = true
                }
                .tint(.green)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 4)
        }
        .navigationTitle("Zadanie")
        .confirmationDialog("Czy są błędy do poprawy?", isPresented: $showBugQuestion, titleVisibility: .visible) {
            Button("Tak") {
                showSeverityPicker = true
            }
            Button("Nie") {
                CurrentPlanStore.complete(task, in: modelContext)
                dismiss()
            }
        }
        .sheet(isPresented: $showSeverityPicker) {
            NavigationStack {
                VStack(spacing: 12) {
                    Text("Waga błędu")
                        .font(.headline)

                    Picker("Waga", selection: $selectedSeverity) {
                        ForEach(1...5, id: \.self) { value in
                            Text("\(value)").tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 90)

                    Text(severityHint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Zapisz błąd") {
                        saveBugAndComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .navigationTitle("Błąd")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Anuluj") {
                            showSeverityPicker = false
                        }
                    }
                }
            }
        }
    }

    private var severityHint: String {
        switch selectedSeverity {
        case 1: "Mało istotny"
        case 2: "Czasami się pokazuje"
        case 3: "Przeszkadza w niektórych zadaniach"
        case 4: "Przeszkadza w całej rozgrywce"
        default: "Nie pozwala na odpalenie gry"
        }
    }

    private func saveBugAndComplete() {
        var createdBug: ProjectBug?
        if let project = task.project {
            let bug = ProjectBug(
                title: CurrentPlanStore.nextBugTitle(for: project),
                details: task.name,
                severity: selectedSeverity,
                project: project,
                relatedTaskName: task.name
            )
            modelContext.insert(bug)
            createdBug = bug
        }
        CurrentPlanStore.complete(task, in: modelContext)
        if let createdBug {
            CurrentPlanStore.persistAndSync(modelContext, mutatedTask: task, mutatedBug: createdBug)
        }
        showSeverityPicker = false
        dismiss()
    }
}

#Preview {
    WatchRootView()
        .modelContainer(for: [Project.self, ProjectTask.self, ProjectBug.self], inMemory: true)
}
