//
//  SettingsView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/11/26.
//

import SwiftUI
import EventKit
import SwiftData

struct SettingsView: View {
    @State private var calendarManager = CalendarSyncManager()
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CalendarEvent.startDate, order: .forward) private var appEvents: [CalendarEvent]

    @AppStorage("settings.displayName") private var displayName: String = ""
    @AppStorage("settings.calendarSyncEnabled") private var calendarSyncEnabled: Bool = false
    @AppStorage("settings.selectedCalendarIdentifier") private var selectedCalendarIdentifier: String = ""

    var body: some View {
        ZStack {
            LystariaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // MARK: - Content
                ScrollView {
                    VStack(spacing: LSpacing.sectionGap) {
                        profileSection
                        calendarSyncSection
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.bottom, 40)
                }
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            calendarManager.refreshAuthorizationStatus()
            if calendarManager.hasFullAccess {
                calendarManager.loadCalendars()
                if calendarSyncEnabled,
                   selectedCalendarIdentifier.isEmpty,
                   let first = calendarManager.calendars.first {
                    selectedCalendarIdentifier = first.calendarIdentifier
                }
            }
        }
        .onChange(of: calendarSyncEnabled) { _, isEnabled in
            Task {
                if isEnabled {
                    if calendarManager.authorizationStatus != .fullAccess {
                        await calendarManager.requestAccess()
                    }
                    if calendarManager.hasFullAccess {
                        calendarManager.loadCalendars()
                        if selectedCalendarIdentifier.isEmpty,
                           let first = calendarManager.calendars.first {
                            selectedCalendarIdentifier = first.calendarIdentifier
                        }
                    } else {
                        calendarSyncEnabled = false
                    }
                }
            }
        }
    }

    // MARK: - Profile Section

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            GlassCard {
                VStack(spacing: 0) {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Display Name")
                                .font(.caption)
                                .foregroundStyle(LColors.textSecondary)

                            GlassTextField(
                                placeholder: "Your name",
                                text: $displayName
                            )
                        }
                    }
                    .padding(14)
                }
            }
        }
    }

    // MARK: - Calendar Sync Section

    private var calendarSyncSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Calendar Sync", icon: "calendar")

            GlassCard {
                VStack(spacing: 16) {

                    // Toggle row
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Sync with Apple Calendar")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(LColors.textPrimary)
                            Text("Export Lystaria events to your calendar")
                                .font(.caption)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $calendarSyncEnabled)
                            .labelsHidden()
                            .tint(LColors.accent)
                    }

                    Divider()
                        .background(LColors.glassBorder)

                    // Status row
                    HStack {
                        Label("Status", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)
                        Spacer()
                        LBadge(
                            text: calendarManager.statusText,
                            color: calendarManager.hasFullAccess ? LColors.success : LColors.textSecondary
                        )
                    }

                    // Conditional expanded content
                    if calendarSyncEnabled {
                        Divider()
                            .background(LColors.glassBorder)

                        expandedCalendarContent
                    }
                }
            }

            if calendarSyncEnabled && calendarManager.hasFullAccess {
                LButton(
                    title: calendarManager.isSyncing ? "Syncing…" : "Sync Now",
                    icon: calendarManager.isSyncing ? nil : "arrow.triangle.2.circlepath",
                    style: .gradient
                ) {
                    Task {
                        if selectedCalendarIdentifier.isEmpty,
                           let first = calendarManager.calendars.first {
                            selectedCalendarIdentifier = first.calendarIdentifier
                        }

                        await calendarManager.syncEvents(
                            appEvents: appEvents,
                            modelContext: modelContext,
                            selectedCalendarIdentifier: selectedCalendarIdentifier
                        )
                    }
                }
                .disabled(calendarManager.isSyncing || selectedCalendarIdentifier.isEmpty)
            }

            if let syncMessage = calendarManager.syncStatusMessage, !syncMessage.isEmpty {
                Text(syncMessage)
                    .font(.footnote)
                    .foregroundStyle(LColors.textSecondary)
                    .padding(.horizontal, 4)
            }
        }
    }

    @ViewBuilder
    private var expandedCalendarContent: some View {
        // Not determined: show connect button
        if calendarManager.authorizationStatus == .notDetermined {
            HStack {
                Spacer()
                LButton(
                    title: calendarManager.isRequestingAccess ? "Connecting…" : "Connect Calendar",
                    icon: calendarManager.isRequestingAccess ? nil : "calendar.badge.plus",
                    style: .gradient
                ) {
                    Task {
                        await calendarManager.requestAccess()
                        if calendarManager.hasFullAccess {
                            calendarManager.loadCalendars()
                        } else {
                            calendarSyncEnabled = false
                        }
                    }
                }
                .disabled(calendarManager.isRequestingAccess)
                Spacer()
            }
        }

        // Denied / restricted
        if calendarManager.authorizationStatus == .denied || calendarManager.authorizationStatus == .restricted {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(LColors.warning)
                Text("Calendar access is unavailable. Enable it in iPhone Settings.")
                    .font(.footnote)
                    .foregroundStyle(LColors.textSecondary)
            }
            .padding(12)
            .background(LColors.warning.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: LSpacing.inputRadius))
            .overlay(
                RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                    .stroke(LColors.warning.opacity(0.2), lineWidth: 1)
            )
        }

        // Authorised: calendar picker
        if calendarManager.hasFullAccess {
            if calendarManager.calendars.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .foregroundStyle(LColors.textSecondary)
                    Text("No writable calendars found.")
                        .font(.footnote)
                        .foregroundStyle(LColors.textSecondary)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Calendar")
                        .font(.caption)
                        .foregroundStyle(LColors.textSecondary)

                    Menu {
                        ForEach(calendarManager.calendars, id: \.calendarIdentifier) { cal in
                            Button {
                                selectedCalendarIdentifier = cal.calendarIdentifier
                            } label: {
                                HStack {
                                    Text(cal.title)
                                    if cal.calendarIdentifier == selectedCalendarIdentifier {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack {
                            Text(
                                calendarManager.calendars
                                    .first(where: { $0.calendarIdentifier == selectedCalendarIdentifier })?
                                    .title ?? "Select a calendar"
                            )
                            .font(.subheadline)
                            .foregroundStyle(LColors.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.caption)
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(LColors.glassSurface2)
                        .clipShape(RoundedRectangle(cornerRadius: LSpacing.inputRadius))
                        .overlay(
                            RoundedRectangle(cornerRadius: LSpacing.inputRadius)
                                .stroke(LColors.glassBorder, lineWidth: 1)
                        )
                    }
                }
            }
        }

        // Error message
        if let error = calendarManager.errorMessage, !error.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(LColors.danger)
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(LColors.danger)
            }
        }

        if let lastSyncDate = calendarManager.lastSyncDate {
            Text("Last synced \(lastSyncDate.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption)
                .foregroundStyle(LColors.textSecondary)
        }
    }
}
