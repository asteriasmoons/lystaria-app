//
//  CalendarSyncSettingsView.swift
//  Lystaria
//
//  Sheet that handles Apple Calendar connection, calendar selection,
//  manual sync trigger, status display, and conflict badge.
//

import SwiftUI
import SwiftData
import EventKit

struct CalendarSyncSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \CalendarEvent.startDate) private var allEvents: [CalendarEvent]
    @Query private var settingsRecords: [UserSettings]

    @State private var syncManager = CalendarSyncManager()

    @State private var showingConflicts = false
    @State private var showingDisconnectConfirm = false

    // MARK: - Settings singleton

    private var settings: UserSettings? { settingsRecords.first }

    private var selectedCalendarIdentifier: String {
        settings?.calendarSyncSelectedIdentifier ?? ""
    }

    private func setSelectedCalendar(_ identifier: String) {
        guard let settings else { return }
        settings.calendarSyncSelectedIdentifier = identifier
        settings.updatedAt = Date()
        try? modelContext.save()
    }

    // MARK: - Derived

    private var summary: CalendarEventSyncHelper.PendingSummary {
        CalendarEventSyncHelper.pendingSummary(from: allEvents)
    }

    private var conflictedEvents: [CalendarEvent] {
        allEvents.filter { $0.syncState == .conflicted }
    }

    private var canSync: Bool {
        syncManager.hasFullAccess &&
        !selectedCalendarIdentifier.isEmpty &&
        !syncManager.isSyncing
    }

    private var lastSyncText: String {
        guard let date = syncManager.lastSyncDate else { return "Never" }
        let df = RelativeDateTimeFormatter()
        df.unitsStyle = .full
        return df.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack(alignment: .center) {
                    VStack(spacing: 6) {
                        GradientTitle(text: "Apple Calendar Sync", size: 20)
                        Text("Two-way sync with your Apple Calendar")
                            .font(.system(size: 13))
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .trailing) {
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

                Rectangle()
                    .fill(LColors.glassBorder)
                    .frame(height: 1)

                ScrollView {
                    VStack(spacing: 16) {

                        // MARK: Connection card
                        sectionCard {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(syncManager.hasFullAccess
                                              ? LColors.success.opacity(0.15)
                                              : Color.white.opacity(0.07))
                                        .frame(width: 44, height: 44)

                                    Image(systemName: syncManager.hasFullAccess
                                          ? "checkmark.circle.fill"
                                          : "calendar.badge.exclamationmark")
                                        .font(.system(size: 20))
                                        .foregroundStyle(syncManager.hasFullAccess
                                                         ? LColors.success
                                                         : LColors.textSecondary)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(syncManager.hasFullAccess ? "Connected" : "Not Connected")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)

                                    Text(syncManager.statusText)
                                        .font(.system(size: 12))
                                        .foregroundStyle(LColors.textSecondary)
                                }

                                Spacer()

                                if syncManager.hasFullAccess {
                                    Button {
                                        showingDisconnectConfirm = true
                                    } label: {
                                        Text("Disconnect")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(LColors.danger)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(LColors.danger.opacity(0.1))
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(LColors.danger.opacity(0.25), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                } else if syncManager.isRequestingAccess {
                                    ProgressView()
                                        .tint(LColors.accent)
                                        .scaleEffect(0.85)
                                } else {
                                    Button {
                                        Task { await syncManager.requestAccess() }
                                    } label: {
                                        Text("Connect")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 7)
                                            .background(LGradients.blue)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        // MARK: Calendar picker (only when connected)
                        if syncManager.hasFullAccess {
                            sectionCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label {
                                        Text("Target Calendar")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                            .tracking(0.4)
                                    } icon: {
                                        Image(systemName: "calendar")
                                            .font(.system(size: 13))
                                            .foregroundStyle(LColors.textSecondary)
                                    }

                                    if syncManager.calendars.isEmpty {
                                        Text("No writable calendars found")
                                            .font(.system(size: 14))
                                            .foregroundStyle(LColors.textSecondary)
                                    } else {
                                        VStack(spacing: 0) {
                                            ForEach(syncManager.calendars, id: \.calendarIdentifier) { calendar in
                                                Button {
                                                    setSelectedCalendar(calendar.calendarIdentifier)
                                                } label: {
                                                    HStack(spacing: 12) {
                                                        Circle()
                                                            .fill(Color(cgColor: calendar.cgColor))
                                                            .frame(width: 12, height: 12)

                                                        Text(calendar.title)
                                                            .font(.system(size: 14, weight: .medium))
                                                            .foregroundStyle(LColors.textPrimary)

                                                        Spacer()

                                                        if calendar.calendarIdentifier == selectedCalendarIdentifier {
                                                            Image(systemName: "checkmark")
                                                                .font(.system(size: 13, weight: .bold))
                                                                .foregroundStyle(LColors.accent)
                                                        }
                                                    }
                                                    .padding(.vertical, 12)
                                                }
                                                .buttonStyle(.plain)

                                                if calendar.calendarIdentifier != syncManager.calendars.last?.calendarIdentifier {
                                                    Rectangle()
                                                        .fill(LColors.glassBorder)
                                                        .frame(height: 1)
                                                }
                                            }
                                        }
                                    }
                                }
                            }

                            // MARK: Pending changes card
                            sectionCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    Label {
                                        Text("Pending Changes")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                            .tracking(0.4)
                                    } icon: {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                            .font(.system(size: 13))
                                            .foregroundStyle(LColors.textSecondary)
                                    }

                                    HStack(spacing: 12) {
                                        pendingChip(
                                            count: summary.pendingExports,
                                            label: "To Export",
                                            color: LColors.accent
                                        )
                                        pendingChip(
                                            count: summary.pendingDeletes,
                                            label: "To Delete",
                                            color: LColors.danger
                                        )
                                        pendingChip(
                                            count: summary.conflicts,
                                            label: "Conflicts",
                                            color: LColors.warning
                                        )
                                    }

                                    if summary.conflicts > 0 {
                                        Button {
                                            showingConflicts = true
                                        } label: {
                                            HStack(spacing: 8) {
                                                Image(systemName: "exclamationmark.triangle.fill")
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(LColors.warning)
                                                Text("Resolve \(summary.conflicts) conflict\(summary.conflicts == 1 ? "" : "s")")
                                                    .font(.system(size: 13, weight: .semibold))
                                                    .foregroundStyle(LColors.textPrimary)
                                                Spacer()
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(LColors.textSecondary)
                                            }
                                            .padding(12)
                                            .background(LColors.warning.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.warning.opacity(0.25), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    HStack {
                                        Image(systemName: "clock")
                                            .font(.system(size: 11))
                                            .foregroundStyle(LColors.textSecondary)
                                        Text("Last synced: \(lastSyncText)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(LColors.textSecondary)
                                    }
                                }
                            }

                            // MARK: Error message
                            if let error = syncManager.errorMessage {
                                HStack(spacing: 10) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(LColors.danger)
                                    Text(error)
                                        .font(.system(size: 13))
                                        .foregroundStyle(LColors.textPrimary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                .padding(14)
                                .background(LColors.danger.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.danger.opacity(0.25), lineWidth: 1))
                                .padding(.horizontal, 16)
                            }

                            // MARK: Sync status message
                            if let status = syncManager.syncStatusMessage {
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(LColors.success)
                                    Text(status)
                                        .font(.system(size: 13))
                                        .foregroundStyle(LColors.textPrimary)
                                }
                                .padding(14)
                                .background(LColors.success.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.success.opacity(0.25), lineWidth: 1))
                                .padding(.horizontal, 16)
                            }
                        }

                        // MARK: How it works
                        sectionCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Label {
                                    Text("How Sync Works")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(LColors.textSecondary)
                                        .tracking(0.4)
                                } icon: {
                                    Image(systemName: "info.circle")
                                        .font(.system(size: 13))
                                        .foregroundStyle(LColors.textSecondary)
                                }

                                VStack(alignment: .leading, spacing: 8) {
                                    infoRow(icon: "arrow.up.circle", text: "New and edited events are pushed to your chosen Apple Calendar")
                                    infoRow(icon: "arrow.down.circle", text: "Events added in Apple Calendar are imported into Lystaria")
                                    infoRow(icon: "exclamationmark.triangle", text: "If both sides changed, you choose which version to keep")
                                    infoRow(icon: "hand.tap", text: "Sync runs when you tap the button — it's never automatic")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }

                // MARK: Sync button
                Rectangle()
                    .fill(LColors.glassBorder)
                    .frame(height: 1)

                Button {
                    Task {
                        await syncManager.syncEvents(
                            appEvents: allEvents,
                            modelContext: modelContext,
                            selectedCalendarIdentifier: selectedCalendarIdentifier
                        )
                    }
                } label: {
                    HStack(spacing: 10) {
                        if syncManager.isSyncing {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.85)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 15, weight: .semibold))
                        }

                        Text(syncManager.isSyncing ? "Syncing…" : "Sync Now")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSync ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.white.opacity(0.08)))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(canSync ? Color.clear : LColors.glassBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canSync)
                .padding(16)
            }
        }
        .onAppear {
            syncManager.refreshAuthorizationStatus()
            if syncManager.hasFullAccess {
                syncManager.loadCalendars()
            }
        }
        .sheet(isPresented: $showingConflicts) {
            CalendarConflictResolutionSheet(conflictedEvents: conflictedEvents)
                .preferredColorScheme(.dark)
        }
        .confirmationDialog(
            "Disconnect Apple Calendar?",
            isPresented: $showingDisconnectConfirm,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) {
                setSelectedCalendar("")
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the calendar link from Lystaria. Your events won't be deleted.")
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func sectionCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(LColors.glassBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func pendingChip(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(count > 0 ? color : LColors.textSecondary)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(LColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background((count > 0 ? color : Color.white).opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke((count > 0 ? color : LColors.glassBorder).opacity(count > 0 ? 0.25 : 1), lineWidth: 1))
    }

    @ViewBuilder
    private func infoRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(LColors.accent)
                .frame(width: 18)
                .padding(.top, 1)
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(LColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
