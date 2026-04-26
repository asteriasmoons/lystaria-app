// KanbanView.swift
// Lystaria

import SwiftUI
import SwiftData

// MARK: - Main Kanban View

struct KanbanView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var limits = LimitManager.shared
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \KanbanBoard.sortOrder) private var boards: [KanbanBoard]
    @Query(sort: \LystariaReminder.nextRunAt) private var allReminders: [LystariaReminder]
    @Query private var habits: [Habit]
    @Query private var medications: [Medication]
    @Query private var events: [CalendarEvent]

    @State private var selectedBoardID: UUID? = nil
    @State private var showNewBoard = false
    @State private var showEditBoard: KanbanBoard? = nil
    @State private var showNewColumn = false
    @State private var showEditColumn: KanbanColumn? = nil
    @State private var draggingReminder: LystariaReminder? = nil
    @State private var toastMessage: String? = nil

    private var selectedBoard: KanbanBoard? {
        guard let id = selectedBoardID else { return boards.first }
        return boards.first(where: { $0.id == id }) ?? boards.first
    }

    private var sortedColumns: [KanbanColumn] {
        (selectedBoard?.columns ?? []).sorted { $0.sortOrder < $1.sortOrder }
    }

    // Reminders not yet assigned to any column on this board
    private var unassignedReminders: [LystariaReminder] {
        allReminders.filter {
            $0.status != .deleted && $0.kanbanColumn == nil
        }
    }

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()
            
            VStack(spacing: 0) {
                // MARK: Header
                VStack(spacing: 0) {
                    HStack {
                        GradientTitle(text: "Kanban", size: 28)
                        
                        Spacer()
                        
                        Button {
                            let decision = limits.canCreate(.kanbanBoardsTotal, currentCount: boards.count)
                            guard decision.allowed else { return }
                            showNewBoard = true
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        Circle().stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                                    .frame(width: 34, height: 34)
                                
                                Image(systemName: "plus")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.top, 16)
                    .padding(.bottom, 14)
                    
                    Rectangle()
                        .fill(LColors.glassBorder)
                        .frame(height: 1)
                        .padding(.horizontal, LSpacing.pageHorizontal)
                }
                .padding(.bottom, 14)
                
                // MARK: Board Selector
                if boards.isEmpty {
                    emptyBoardsState
                } else {
                    boardSelectorBar
                    
                    if let board = selectedBoard {
                        boardContent(board: board)
                    }
                }
            }
        }
        .overlay {
            if showNewBoard {
                BoardEditorSheet(
                    board: nil,
                    onSave: { name, hex in
                        // Enforce board limit (2 total for free users)
                        let decision = limits.canCreate(.kanbanBoardsTotal, currentCount: boards.count)
                        guard decision.allowed else { return }
                        let b = KanbanBoard(name: name, colorHex: hex, sortOrder: boards.count)
                        modelContext.insert(b)
                        try? modelContext.save()
                        selectedBoardID = b.id
                    },
                    onClose: {
                        showNewBoard = false
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(70)
            }
        }
        .overlay {
            if let board = showEditBoard {
                BoardEditorSheet(
                    board: board,
                    onSave: { name, hex in
                        board.name = name
                        board.colorHex = hex
                        board.updatedAt = Date()
                        try? modelContext.save()
                    },
                    onClose: {
                        showEditBoard = nil
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(71)
            }
        }
        .overlay {
            if showNewColumn, let board = selectedBoard {
                ColumnEditorSheet(
                    column: nil,
                    onSave: { name, hex in
                        // Enforce column limit (3 per board for free users)
                        let currentCount = (board.columns ?? []).count
                        let decision = limits.canCreate(.kanbanColumnsPerBoard, currentCount: currentCount)
                        guard decision.allowed else { return }
                        let col = KanbanColumn(name: name, colorHex: hex, sortOrder: (board.columns ?? []).count)
                        col.board = board
                        modelContext.insert(col)
                        try? modelContext.save()
                    },
                    onClose: {
                        showNewColumn = false
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(72)
            }
        }
        .overlay {
            if let col = showEditColumn {
                ColumnEditorSheet(
                    column: col,
                    onSave: { name, hex in
                        col.name = name
                        col.colorHex = hex
                        col.updatedAt = Date()
                        try? modelContext.save()
                    },
                    onClose: {
                        showEditColumn = nil
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(73)
            }
        }
        .overlay(alignment: .bottom) {
            if let msg = toastMessage {
                ToastView(message: msg)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showNewBoard)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showEditBoard != nil)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showNewColumn)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showEditColumn != nil)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: toastMessage)
    }
    
    // MARK: - Empty State

    private var emptyBoardsState: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 52))
                .foregroundStyle(LColors.textSecondary.opacity(0.3))
            Text("No boards yet")
                .font(.title3.bold())
                .foregroundStyle(LColors.textPrimary)
            Text("Create a board to start organizing your reminders visually.")
                .font(.subheadline)
                .foregroundStyle(LColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            LButton(title: "Create Board", icon: "plus", style: .gradient) {
                showNewBoard = true
            }
            Spacer()
        }
    }

    // MARK: - Board Selector Bar

    private var boardSelectorBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            let allowedBoardIds = Set(
                boards
                    .sorted { $0.createdAt < $1.createdAt }
                    .prefix(2)
                    .map { $0.persistentModelID }
            )
            HStack(spacing: 10) {
                ForEach(boards) { board in
                    let selected = selectedBoard?.id == board.id
                    Button {
                        selectedBoardID = board.id
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(board.color)
                                .frame(width: 8, height: 8)
                            Text(board.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(selected ? .white : LColors.textPrimary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selected ? board.color.opacity(0.25) : Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(selected ? board.color : LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .premiumLocked(!limits.hasPremiumAccess && !allowedBoardIds.contains(board.persistentModelID))
                    .contextMenu {
                        Button("Edit Board") { showEditBoard = board }
                        Button("Add Column") {
                            let currentCount = selectedBoard?.columns?.count ?? 0
                            let decision = limits.canCreate(.kanbanColumnsPerBoard, currentCount: currentCount)
                            guard decision.allowed else { return }
                            showNewColumn = true
                        }
                        Button("Delete Board", role: .destructive) { deleteBoard(board) }
                    }
                }
            }
            .padding(.horizontal, LSpacing.pageHorizontal)
        }
        .padding(.bottom, 14)
    }

    // MARK: - Board Content

    @ViewBuilder
    private func boardContent(board: KanbanBoard) -> some View {
        if sortedColumns.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "rectangle.split.3x1")
                    .font(.system(size: 40))
                    .foregroundStyle(LColors.textSecondary.opacity(0.3))
                Text("No columns yet")
                    .font(.headline)
                    .foregroundStyle(LColors.textPrimary)
                Text("Add columns like \"To Do\", \"In Progress\", \"Done\"")
                    .font(.subheadline)
                    .foregroundStyle(LColors.textSecondary)
                    .multilineTextAlignment(.center)
                LButton(title: "Add Column", icon: "plus", style: .gradient) {
                    let currentCount = (selectedBoard?.columns ?? []).count
                    let decision = limits.canCreate(.kanbanColumnsPerBoard, currentCount: currentCount)
                    guard decision.allowed else { return }
                    showNewColumn = true
                }
                Spacer()
            }
            .padding(.horizontal, 32)
        } else {
            let allowedColumnIds = Set(
                (board.columns ?? [])
                    .sorted { $0.createdAt < $1.createdAt }
                    .prefix(3)
                    .map { $0.persistentModelID }
            )
            HStack(alignment: .top) {
                // Column action button
                Button {
                    let currentCount = (selectedBoard?.columns ?? []).count
                    let decision = limits.canCreate(.kanbanColumnsPerBoard, currentCount: currentCount)
                    guard decision.allowed else { return }
                    showNewColumn = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.accent)
                }
                .buttonStyle(.plain)
                .padding(.leading, LSpacing.pageHorizontal)
                .padding(.top, 2)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(sortedColumns) { column in
                            KanbanColumnView(
                                column: column,
                                allReminders: allReminders,
                                draggingReminder: $draggingReminder,
                                onEditColumn: { showEditColumn = column },
                                onDeleteColumn: { deleteColumn(column) },
                                onDropReminder: { reminder in moveReminder(reminder, to: column) },
                                onMarkDone: { reminder in markDone(reminder) },
                                onUnassign: { reminder in unassign(reminder) }
                            )
                            .premiumLocked(!limits.hasPremiumAccess && !allowedColumnIds.contains(column.persistentModelID))
                        }

                        // Inbox column — unassigned reminders
                        if !unassignedReminders.isEmpty {
                            InboxColumnView(
                                reminders: unassignedReminders,
                                columns: sortedColumns,
                                draggingReminder: $draggingReminder,
                                onMoveToColumn: { reminder, col in moveReminder(reminder, to: col) },
                                onMarkDone: { reminder in markDone(reminder) }
                            )
                        }
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.bottom, 120)
                }
            }
        }
    }

    // MARK: - Actions

    private func moveReminder(_ reminder: LystariaReminder, to column: KanbanColumn) {
        reminder.kanbanColumn = column
        reminder.isKanbanDone = false
        try? modelContext.save()
        showToast("Moved to \(column.name)")
    }

    private func unassign(_ reminder: LystariaReminder) {
        reminder.kanbanColumn = nil
        reminder.isKanbanDone = false
        try? modelContext.save()
    }

    private func canMarkReminderDone(_ reminder: LystariaReminder) -> Bool {
        // Routine reminders should always be allowed to complete from Kanban.
        if reminder.reminderType == .routine {
            return true
        }

        // This view does not have a shared checklist-gating property on the reminder model,
        // so allow non-routine reminders to complete here as well.
        return true
    }

    private func markDone(_ reminder: LystariaReminder) {
        guard canMarkReminderDone(reminder) else { return }
        logHabitProgressFromReminder(reminder)
        logMedicationIfLinked(reminder)
        let completedOccurrenceDate = reminder.nextRunAt

        if reminder.isRecurring {
            let now = Date()
            let base = max(now, reminder.nextRunAt)

            let intervalWindowStart: String? = {
                guard reminder.linkedKind == .habit,
                      let habitId = reminder.linkedHabitId else { return nil }
                let descriptor = FetchDescriptor<Habit>()
                return ((try? modelContext.fetch(descriptor)) ?? []).first(where: { $0.id == habitId })?.reminderIntervalWindowStart
            }()

            let intervalWindowEnd: String? = {
                guard reminder.linkedKind == .habit,
                      let habitId = reminder.linkedHabitId else { return nil }
                let descriptor = FetchDescriptor<Habit>()
                return ((try? modelContext.fetch(descriptor)) ?? []).first(where: { $0.id == habitId })?.reminderIntervalWindowEnd
            }()

            reminder.nextRunAt = ReminderCompute.nextRun(
                after: reminder.nextRunAt.addingTimeInterval(91),
                reminder: reminder,
                intervalWindowStart: intervalWindowStart,
                intervalWindowEnd: intervalWindowEnd
            )
            reminder.acknowledgedAt = nil
            if reminder.reminderType == .routine {
                reminder.resetRoutineChecklist(for: "\(reminder.nextRunAt.timeIntervalSince1970)")
            }
            reminder.lastCompletedAt = Date()
            incrementCompletionsToday(reminder, occurrenceDate: completedOccurrenceDate)
            reminder.updatedAt = Date()
            try? modelContext.save()
            awardPointsForReminderCompletion(reminder, occurrenceDate: completedOccurrenceDate)
            NotificationManager.shared.cancelReminder(reminder)
            NotificationManager.shared.scheduleReminder(reminder)
#if DEBUG
            NotificationManager.shared.printPendingNotifications()
#endif
            showToast("Completed")
        } else {
            reminder.isKanbanDone = true
            reminder.lastCompletedAt = Date()
            incrementCompletionsToday(reminder, occurrenceDate: completedOccurrenceDate)
            reminder.acknowledgedAt = Date()
            reminder.status = .sent
            reminder.updatedAt = Date()
            try? modelContext.save()
            awardPointsForReminderCompletion(reminder, occurrenceDate: completedOccurrenceDate)
            NotificationManager.shared.cancelReminder(reminder)
#if DEBUG
            NotificationManager.shared.printPendingNotifications()
#endif
            showToast("Completed")
        }
    }

    // MARK: - Habit/Medication Logging (from RemindersView)

    private func logHabitProgressFromReminder(_ reminder: LystariaReminder) {
        guard reminder.linkedKind == .habit,
              let habitId = reminder.linkedHabitId else { return }

        let descriptor = FetchDescriptor<Habit>()
        guard let habit = ((try? modelContext.fetch(descriptor)) ?? []).first(where: { $0.id == habitId }) else {
            return
        }

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())

        let cap: Int
        let kind = habit.reminderKind
        if kind == .everyXHours || kind == .everyXMinutes {
            let intervalMins: Int
            if kind == .everyXHours {
                intervalMins = max(1, habit.reminderIntervalHours) * 60
            } else {
                intervalMins = max(1, habit.reminderIntervalMinutes)
            }
            if !habit.reminderIntervalWindowStart.isEmpty,
               !habit.reminderIntervalWindowEnd.isEmpty,
               let (wsH, wsM) = ReminderCompute.parseHHMM(habit.reminderIntervalWindowStart),
               let (weH, weM) = ReminderCompute.parseHHMM(habit.reminderIntervalWindowEnd) {
                let windowMins = (weH * 60 + weM) - (wsH * 60 + wsM)
                cap = windowMins > 0 ? max(1, (windowMins / intervalMins) + 1) : max(1, habit.timesPerDay)
            } else {
                cap = max(1, habit.timesPerDay)
            }
        } else {
            cap = max(1, habit.timesPerDay)
        }

        if let existingSkip = (habit.skips ?? []).first(where: { cal.isDate($0.dayStart, inSameDayAs: todayStart) }) {
            modelContext.delete(existingSkip)
            habit.skips = (habit.skips ?? []).filter { $0.persistentModelID != existingSkip.persistentModelID }
        }

        if let existingLog = (habit.logs ?? []).first(where: { cal.isDate($0.dayStart, inSameDayAs: todayStart) }) {
            if existingLog.count < cap {
                existingLog.count += 1
                habit.updatedAt = Date()

                _ = try? SelfCarePointsManager.awardHabitLog(
                    in: modelContext,
                    habitLogId: existingLog.id.uuidString,
                    title: habit.title,
                    loggedAt: Date()
                )
            }
        } else {
            let newLog = HabitLog(habit: habit, dayStart: todayStart, count: 1)
            modelContext.insert(newLog)

            if habit.logs == nil {
                habit.logs = [newLog]
            } else {
                habit.logs?.append(newLog)
            }

            habit.updatedAt = Date()

            _ = try? SelfCarePointsManager.awardHabitLog(
                in: modelContext,
                habitLogId: newLog.id.uuidString,
                title: habit.title,
                loggedAt: Date()
            )
        }
    }

    private func logMedicationIfLinked(_ reminder: LystariaReminder) {
        if reminder.reminderType == .routine {
            for link in reminder.sortedMedicationLinks {
                guard let medicationId = link.medicationId,
                      let medication = medications.first(where: { $0.id == medicationId })
                else {
                    continue
                }

                let quantity = max(1, link.quantity)
                let previousAmount = medication.currentAmount

                if medication.currentAmount > 0 {
                    medication.currentAmount = max(0, medication.currentAmount - quantity)
                }

                medication.lastTakenAt = Date()
                medication.updatedAt = Date()

                let historyEntry = MedicationHistoryEntry(
                    type: .taken,
                    amountText: "\(previousAmount) → \(medication.currentAmount)",
                    details: "\(reminder.title) • Qty \(quantity)",
                    createdAt: Date(),
                    medication: medication,
                )
                modelContext.insert(historyEntry)
            }
            return
        }

        guard reminder.linkedKind == .medication,
              let mid = reminder.linkedMedicationId,
              let medication = medications.first(where: { $0.id == mid }) else { return }

        let quantity = max(1, reminder.linkedMedicationQuantity)
        let previousAmount = medication.currentAmount

        if medication.currentAmount > 0 {
            medication.currentAmount = max(0, medication.currentAmount - quantity)
        }

        medication.lastTakenAt = Date()
        medication.updatedAt = Date()

        let historyEntry = MedicationHistoryEntry(
            type: .taken,
            amountText: "\(previousAmount) → \(medication.currentAmount)",
            details: "\(reminder.title) • Qty \(quantity)",
            createdAt: Date(),
            medication: medication,
        )
        modelContext.insert(historyEntry)
    }

    private func awardPointsForReminderCompletion(_ reminder: LystariaReminder, occurrenceDate: Date) {
        let reminderId = "\(reminder.persistentModelID)"
        let occurrenceDayKey = SelfCarePointsManager.dayKey(from: occurrenceDate)
        let isEventReminder = events.contains { $0.reminderServerId == reminderId }

        if reminder.linkedKind == .habit {
            _ = try? SelfCarePointsManager.awardHabitReminderCompletion(
                in: modelContext,
                reminderId: reminderId,
                occurrenceDayKey: occurrenceDayKey,
                title: reminder.title,
            )
        } else if isEventReminder {
            _ = try? SelfCarePointsManager.awardEventReminderCompletion(
                in: modelContext,
                eventId: reminderId,
                occurrenceDayKey: occurrenceDayKey,
                title: reminder.title,
            )
        } else {
            _ = try? SelfCarePointsManager.awardReminderCompletion(
                in: modelContext,
                reminderId: reminderId,
                occurrenceDayKey: occurrenceDayKey,
                title: reminder.title,
            )
        }
    }


    private func incrementCompletionsToday(_ reminder: LystariaReminder, occurrenceDate: Date) {
        let cal = Calendar.current
        var timestamps = decodeCompletionTimestamps(reminder)
        timestamps = timestamps.filter { cal.isDateInToday($0) }
        guard cal.isDateInToday(occurrenceDate) else { return }
        timestamps.append(occurrenceDate)
        reminder.completionTimestampsStorage = encodeCompletionTimestamps(timestamps)
    }

    private func decodeCompletionTimestamps(_ reminder: LystariaReminder) -> [Date] {
        guard let data = reminder.completionTimestampsStorage.data(using: .utf8),
              let intervals = try? JSONDecoder().decode([Double].self, from: data) else { return [] }
        return intervals.map { Date(timeIntervalSince1970: $0) }
    }

    private func encodeCompletionTimestamps(_ dates: [Date]) -> String {
        let intervals = dates.map(\.timeIntervalSince1970)
        let data = try? JSONEncoder().encode(intervals)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    private func deleteBoard(_ board: KanbanBoard) {
        // Unassign all reminders before deleting
        for col in (board.columns ?? []) {
            for r in (col.reminders ?? []) {
                r.kanbanColumn = nil
            }
        }
        modelContext.delete(board)
        try? modelContext.save()
        selectedBoardID = boards.first?.id
    }

    private func deleteColumn(_ column: KanbanColumn) {
        for r in (column.reminders ?? []) {
            r.kanbanColumn = nil
        }
        modelContext.delete(column)
        try? modelContext.save()
    }

    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        Task {
            try? await Task.sleep(for: .seconds(2.5))
            withAnimation { toastMessage = nil }
        }
    }
}

private struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(LColors.success)
            Text(message)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(LColors.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.25), radius: 10, y: 4)
        .padding(.bottom, 110)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .zIndex(99)
    }
}

// MARK: - Kanban Column View

struct KanbanColumnView: View {
    @ViewBuilder
    private func reminderCard(for reminder: LystariaReminder) -> some View {
        let isDragging = draggingReminder?.persistentModelID == reminder.persistentModelID

        KanbanCard(
            reminder: reminder,
            accentColor: column.color,
            onMarkDone: { onMarkDone(reminder) },
            onUnassign: { onUnassign(reminder) }
        )
        .draggable(reminder.persistentModelID.hashValue.description) {
            KanbanDragPreview(title: reminder.title, color: column.color)
        }
        .opacity(isDragging ? 0.4 : 1)
    }
    @Bindable var column: KanbanColumn
    let allReminders: [LystariaReminder]
    @Binding var draggingReminder: LystariaReminder?
    let onEditColumn: () -> Void
    let onDeleteColumn: () -> Void
    let onDropReminder: (LystariaReminder) -> Void
    let onMarkDone: (LystariaReminder) -> Void
    let onUnassign: (LystariaReminder) -> Void

    @State private var isDropTargeted = false

    private var kanbanColumnBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial).opacity(0.5)
            RoundedRectangle(cornerRadius: 18).fill(LColors.glassSurface)
        }
    }

    private func countBadge(_ n: Int) -> some View {
        let background = Color.white.opacity(0.08)

        return Text("\(n)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LColors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background)
            .clipShape(Capsule())
    }

    private var columnReminders: [LystariaReminder] {
        (column.reminders ?? [])
            .filter { $0.status != .deleted }
            .sorted { $0.kanbanSortOrder < $1.kanbanSortOrder }
    }

    private var doneCount: Int {
        columnReminders.filter { $0.isKanbanDone }.count
    }

    private var totalCount: Int {
        columnReminders.count
    }

    private var headerBackground: Color {
        column.color.opacity(0.10)
    }

    private var headerStroke: Color {
        column.color.opacity(0.25)
    }

    private var columnBorderColor: Color {
        isDropTargeted ? column.color.opacity(0.6) : LColors.glassBorder
    }

    private var columnBorderWidth: CGFloat {
        isDropTargeted ? 2 : 1
    }

    var body: some View {
        let progressFraction = totalCount > 0 ? (Double(doneCount) / Double(totalCount)) : 0
        let placeholderFill = Color.white.opacity(isDropTargeted ? 0.10 : 0.04)
        let placeholderStrokeColor = isDropTargeted ? column.color : LColors.glassBorder
        let placeholderDash: [CGFloat] = isDropTargeted ? [] : [6]
        VStack(alignment: .leading, spacing: 0) {
            // Column header
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(column.color)
                    .frame(width: 4, height: 20)

                Text(column.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)

                countBadge(totalCount)

                Spacer()

                Menu {
                    Button("Edit Column") { onEditColumn() }
                    Button("Delete Column", role: .destructive) { onDeleteColumn() }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(headerBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(headerStroke, lineWidth: 1)
            )

            // Progress bar if any done
            if totalCount > 0 {
                GeometryReader { geo in
                    let fraction = progressFraction
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.08))
                        RoundedRectangle(cornerRadius: 2)
                            .fill(column.color)
                            .frame(width: geo.size.width * fraction)
                            .animation(.easeInOut, value: doneCount)
                    }
                }
                .frame(height: 3)
                .padding(.horizontal, 4)
                .padding(.top, 6)
            }

            // Cards
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    if columnReminders.isEmpty {
                        // Drop target placeholder
                        RoundedRectangle(cornerRadius: 14)
                            .fill(placeholderFill)
                            .frame(height: 80)
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(
                                        placeholderStrokeColor,
                                        style: StrokeStyle(lineWidth: 1.5, dash: placeholderDash)
                                    )
                            )
                            .overlay(
                                Text("Drop here")
                                    .font(.caption)
                                    .foregroundStyle(LColors.textSecondary)
                            )
                    } else {
                        ForEach(columnReminders, id: \.id) { reminder in
                            reminderCard(for: reminder)
                        }
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 240)
        .padding(12)
        .background(kanbanColumnBackground)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(columnBorderColor, lineWidth: columnBorderWidth)
        )
        .dropDestination(for: String.self) { items, _ in
            guard let hashStr = items.first,
                  let reminder = findReminder(hashStr: hashStr) else { return false }
            onDropReminder(reminder)
            return true
        } isTargeted: { isDropTargeted = $0 }
    }

    private func findReminder(hashStr: String) -> LystariaReminder? {
        allReminders.first(where: { $0.persistentModelID.hashValue.description == hashStr })
    }
}

// MARK: - Inbox Column (Unassigned Reminders)

struct InboxColumnView: View {
    let reminders: [LystariaReminder]
    let columns: [KanbanColumn]
    @Binding var draggingReminder: LystariaReminder?
    let onMoveToColumn: (LystariaReminder, KanbanColumn) -> Void
    let onMarkDone: (LystariaReminder) -> Void

    private var kanbanColumnBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18).fill(.ultraThinMaterial).opacity(0.5)
            RoundedRectangle(cornerRadius: 18).fill(LColors.glassSurface)
        }
    }

    private func countBadge(_ n: Int) -> some View {
        let background = Color.white.opacity(0.08)

        return Text("\(n)")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(LColors.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(background)
            .clipShape(Capsule())
    }

    private func makeColumnMenu(for reminder: LystariaReminder) -> (() -> AnyView)? {
        guard !columns.isEmpty else { return nil }

        return {
            AnyView(
                Menu {
                    ForEach(columns, id: \.id) { col in
                        Button(col.name) {
                            onMoveToColumn(reminder, col)
                        }
                    }
                } label: {
                    Label("Move to…", systemImage: "arrow.right.circle")
                        .font(.caption)
                        .foregroundStyle(LColors.accent)
                }
                .buttonStyle(.plain)
            )
        }
    }

    @ViewBuilder
    private func inboxReminderCard(for reminder: LystariaReminder) -> some View {
        let columnMenu = makeColumnMenu(for: reminder)

        KanbanCard(
            reminder: reminder,
            accentColor: LColors.textSecondary,
            onMarkDone: { onMarkDone(reminder) },
            onUnassign: nil,
            columnMenu: columnMenu
        )
        .draggable(reminder.persistentModelID.hashValue.description) {
            KanbanDragPreview(title: reminder.title, color: LColors.textSecondary)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(LColors.textSecondary)
                    .frame(width: 4, height: 20)

                Text("Inbox")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(LColors.textPrimary)

                countBadge(reminders.count)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    ForEach(reminders, id: \.id) { reminder in
                        inboxReminderCard(for: reminder)
                    }
                }
                .padding(.top, 10)
                .padding(.bottom, 8)
            }
        }
        .frame(width: 240)
        .padding(12)
        .background(kanbanColumnBackground)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(LColors.glassBorder, lineWidth: 1))
    }
}

// MARK: - Kanban Card

struct KanbanCard: View {
    @Bindable var reminder: LystariaReminder
    let accentColor: Color
    let onMarkDone: () -> Void
    let onUnassign: (() -> Void)?
    var columnMenu: (() -> AnyView)? = nil

    private var isDone: Bool { reminder.isKanbanDone }

    private var isDueNow: Bool {
        let now = Date()
        if isDone { return false }
        if reminder.isRecurring {
            let startOfToday = Calendar.current.startOfDay(for: now)
            if reminder.nextRunAt < startOfToday {
                return false
            }
        }
        return reminder.status != .deleted && now >= reminder.nextRunAt
    }

    private var isUpcoming: Bool {
        let now = Date()
        if isDone { return false }
        if now >= reminder.nextRunAt { return false }
        return reminder.status != .deleted && reminder.nextRunAt <= now.addingTimeInterval(24 * 60 * 60)
    }

    private var scheduleLabel: String {
        guard let schedule = reminder.schedule else { return "Once" }

        if schedule.kind == .daily, (schedule.interval ?? 1) > 1 {
            return "Custom"
        }

        return schedule.kind.label
    }
            @ViewBuilder
            private var actionRow: some View {
                HStack(spacing: 6) {
                    Text(scheduleLabel.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(badgeColor.opacity(0.35))
                        .clipShape(Capsule())

                    Text(reminderKindLabel.uppercased())
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(reminderKindBadgeColor)
                        .clipShape(Capsule())

                    if isDueNow {
                        dueNowBadge
                    } else if isUpcoming {
                        upcomingBadge
                    }

                    Spacer()

                    if let menu = columnMenu {
                        menu()
                    }

                    if let unassign = onUnassign {
                        Button { unassign() } label: {
                            Image(systemName: "xmark.circle")
                                .font(.caption)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

    private var scheduleKind: ReminderScheduleKind {
        reminder.schedule?.kind ?? .once
    }

    private var badgeColor: Color {
        if let schedule = reminder.schedule,
           schedule.kind == .daily,
           (schedule.interval ?? 1) > 1 {
            return Color(red: 201/255, green: 44/255, blue: 194/255) // #c92cc2
        }

        switch scheduleKind {
        case .once:
            return LColors.badgeOnce
        case .daily:
            return LColors.badgeDaily
        case .weekly:
            return LColors.badgeWeekly
        case .monthly:
            return .yellow
        case .yearly:
            return LColors.gradientPurple
        case .interval:
            return LColors.badgeInterval
        }
    }
    
    private var reminderKindLabel: String {
        switch reminder.linkedKindRaw?.lowercased() {
        case "habit":
            return "Habit"
        case "event":
            return "Event"
        case "medication":
            return "Medication"
        default:
            return "General"
        }
    }

    private var reminderKindBadgeColor: Color {
        switch reminder.linkedKindRaw?.lowercased() {
        case "habit":
            return Color(red: 0.14, green: 0.63, blue: 0.56).opacity(0.82)
        case "event":
            return Color(red: 0.95, green: 0.56, blue: 0.20).opacity(0.82)
        case "medication":
            return Color(red: 0.86, green: 0.28, blue: 0.58).opacity(0.82)
        default:
            return Color.black
        }
    }
    
    private var dueNowBadge: some View {
        Text("DUE NOW")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(LGradients.blue)
            .clipShape(Capsule())
    }
    
    private var upcomingBadge: some View {
        Text("UPCOMING")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.teal.opacity(0.42))
            .clipShape(Capsule())
    }

    private var nextRunText: String {
        reminder.nextRunAt.formatted(date: .abbreviated, time: .shortened)
    }

    var body: some View {
        let titleColor = isDone ? LColors.textSecondary : LColors.textPrimary
        let checkmarkColor = isDone ? LColors.success : LColors.textSecondary
        let cardFill = isDone ? Color.white.opacity(0.04) : Color.white.opacity(0.08)
        let cardStroke = isDone ? LColors.glassBorder.opacity(0.5) : accentColor.opacity(0.22)
        VStack(alignment: .leading, spacing: 10) {
            // Top row: done check + title
            HStack(alignment: .top, spacing: 10) {
                Button { onMarkDone() } label: {
                    Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(checkmarkColor)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 4) {
                    Text(reminder.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(titleColor)
                        .strikethrough(isDone, color: LColors.textSecondary)
                        .lineLimit(2)

                    if let details = reminder.details, !details.isEmpty {
                        Text(details)
                            .font(.caption)
                            .foregroundStyle(LColors.textSecondary)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)
            }

            // Bottom row: badge + time + actions
            actionRow

            // Next run date
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                    .foregroundStyle(LColors.textSecondary)
                Text(nextRunText)
                    .font(.system(size: 11))
                    .foregroundStyle(LColors.textSecondary)
            }
        }
        .padding(12)
        .background(cardFill, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            RoundedRectangle(cornerRadius: 14)
                .stroke(cardStroke, lineWidth: 1)
        }
        .animation(.easeInOut(duration: 0.2), value: isDone)
    }
}

// MARK: - Drag Preview

struct KanbanDragPreview: View {
    let title: String
    let color: Color

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(color.opacity(0.85))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Board Editor Sheet

struct BoardEditorSheet: View {
    let board: KanbanBoard?
    let onSave: (String, String) -> Void
    var onClose: (() -> Void)? = nil

    @State private var name: String = ""
    @State private var selectedHex: String = "#03dbfc"
    @State private var selectedColor: Color = Color(hex: "#03dbfc")

    private var closeAction: () -> Void {
        onClose ?? {}
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 620,
            heightRatio: 0.70,
            header: {
                HStack {
                    GradientTitle(text: board == nil ? "New Board" : "Edit Board", size: 22)
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("BOARD NAME")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    GlassTextField(placeholder: "Board name", text: $name)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("BOARD COLOR")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    HStack(spacing: 14) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 42, height: 42)
                            .overlay(
                                Circle().stroke(.white.opacity(0.8), lineWidth: 1.5)
                            )

                        ColorPicker("Choose board color", selection: $selectedColor, supportsOpacity: false)
                            .labelsHidden()
                            .scaleEffect(1.2)

                        Spacer()
                    }
                }
                .padding(16)
                .background(LColors.glassSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )

                VStack(alignment: .leading, spacing: 8) {
                    Text("PREVIEW")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    HStack(spacing: 10) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 12, height: 12)

                        Text(name.isEmpty ? "Board preview" : name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(LColors.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(selectedColor.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(selectedColor, lineWidth: 1)
                    )
                }
            },
            footer: {
                LButton(title: "Save Board", style: .gradient) {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed, selectedColor.toHex() ?? "#03dbfc")
                    closeAction()
                }
                .frame(maxWidth: .infinity)
            }
        )
        .onAppear {
            name = board?.name ?? ""
            selectedHex = board?.colorHex ?? "#03dbfc"
            selectedColor = Color(hex: selectedHex)
        }
    }
}

// MARK: - Column Editor Sheet

struct ColumnEditorSheet: View {
    let column: KanbanColumn?
    let onSave: (String, String) -> Void
    var onClose: (() -> Void)? = nil

    @State private var name: String = ""
    @State private var selectedHex: String = "#7d19f7"
    @State private var selectedColor: Color = Color(hex: "#7d19f7")

    private let statusSuggestions = ["To Do", "In Progress", "Review", "Done", "Blocked", "On Hold", "Testing", "Deployed"]

    private var closeAction: () -> Void {
        onClose ?? {}
    }

    var body: some View {
        LystariaOverlayPopup(
            onClose: {
                closeAction()
            },
            width: 620,
            heightRatio: 0.70,
            header: {
                HStack {
                    GradientTitle(text: column == nil ? "New Column" : "Edit Column", size: 22)
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("COLUMN NAME")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    GlassTextField(placeholder: "Column name (e.g. In Progress)", text: $name)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("SUGGESTIONS")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(statusSuggestions, id: \.self) { s in
                                Button { name = s } label: {
                                    Text(s)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(name == s ? .white : LColors.textPrimary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 7)
                                        .background(name == s ? LColors.accent : Color.white.opacity(0.08))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(
                                                name == s ? LColors.accent : LColors.glassBorder,
                                                lineWidth: 1
                                            )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("COLUMN COLOR")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    HStack(spacing: 14) {
                        Circle()
                            .fill(selectedColor)
                            .frame(width: 42, height: 42)
                            .overlay(
                                Circle().stroke(.white.opacity(0.8), lineWidth: 1.5)
                            )

                        ColorPicker("Choose column color", selection: $selectedColor, supportsOpacity: false)
                            .labelsHidden()
                            .scaleEffect(1.2)

                        Spacer()
                    }
                }
                .padding(16)
                .background(LColors.glassSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(LColors.glassBorder, lineWidth: 1)
                )
            },
            footer: {
                LButton(title: "Save Column", style: .gradient) {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSave(trimmed, selectedColor.toHex() ?? "#7d19f7")
                    closeAction()
                }
                .frame(maxWidth: .infinity)
            }
        )
        .onAppear {
            name = column?.name ?? ""
            selectedHex = column?.colorHex ?? "#7d19f7"
            selectedColor = Color(hex: selectedHex)
        }
    }
}


