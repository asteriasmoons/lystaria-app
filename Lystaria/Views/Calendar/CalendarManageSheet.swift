//
//  CalendarManageSheet.swift
//  Lystaria
//
//  Manage app-side EventCalendar records: create, edit name/color, delete.
//

import SwiftUI
import SwiftData

struct CalendarManageSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: [SortDescriptor(\EventCalendar.sortOrder), SortDescriptor(\EventCalendar.name)])
    private var calendars: [EventCalendar]

    @Query(sort: \CalendarEvent.startDate)
    private var allEvents: [CalendarEvent]

    // New calendar
    @State private var newName: String = ""
    @State private var newColorUI: Color = Color(ly_hex: "#5b8def")
    @State private var showingAddPopup = false

    // Editing
    @State private var editingCalendar: EventCalendar? = nil
    @State private var editedName: String = ""
    @State private var editedColor: Color = Color(ly_hex: "#5b8def")

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    GradientTitle(text: "Calendars", size: 22)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 16)

                Rectangle().fill(LColors.glassBorder).frame(height: 1)

                ScrollView {
                    VStack(spacing: 12) {
                        if calendars.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "calendar.badge.exclamationmark")
                                    .font(.system(size: 40))
                                    .foregroundStyle(LColors.textSecondary.opacity(0.4))
                                Text("No calendars yet")
                                    .font(.system(size: 14))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            ForEach(calendars) { calendar in
                                calendarRow(calendar)
                            }
                        }

                        // Add new calendar button
                        Button {
                            newName = ""
                            newColorUI = Color(ly_hex: "#5b8def")
                            showingAddPopup = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(LColors.accent)
                                Text("New Calendar")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(LColors.textPrimary)
                                Spacer()
                            }
                            .padding(16)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }

            // Add popup
            if showingAddPopup {
                LystariaOverlayPopup(
                    onClose: { showingAddPopup = false },
                    width: 560,
                    heightRatio: 0.45,
                    header: {
                        HStack {
                            GradientTitle(text: "New Calendar", font: .title2.bold())
                            Spacer()
                            Button { showingAddPopup = false } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    },
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            CalendarLabeledGlassField(label: "NAME") {
                                TextField("Calendar name", text: $newName)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(LColors.textPrimary)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("COLOR")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)
                                ColorPicker("", selection: $newColorUI, supportsOpacity: false)
                                    .labelsHidden()
                            }
                        }
                    },
                    footer: {
                        Button {
                            saveNewCalendar()
                        } label: {
                            let canSave = !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            Text("Create Calendar")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(canSave ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.white.opacity(0.08)))
                                .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                        }
                        .buttonStyle(.plain)
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(80)
            }

            // Edit popup
            if let calendar = editingCalendar {
                LystariaOverlayPopup(
                    onClose: { editingCalendar = nil },
                    width: 560,
                    heightRatio: 0.45,
                    header: {
                        HStack {
                            GradientTitle(text: "Edit Calendar", font: .title2.bold())
                            Spacer()
                            Button { editingCalendar = nil } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title2)
                                    .foregroundStyle(LColors.textSecondary)
                            }
                            .buttonStyle(.plain)
                        }
                    },
                    content: {
                        VStack(alignment: .leading, spacing: 12) {
                            CalendarLabeledGlassField(label: "NAME") {
                                TextField("Calendar name", text: $editedName)
                                    .textFieldStyle(.plain)
                                    .foregroundStyle(LColors.textPrimary)
                            }
                            VStack(alignment: .leading, spacing: 8) {
                                Text("COLOR")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                                    .tracking(0.5)
                                ColorPicker("", selection: $editedColor, supportsOpacity: false)
                                    .labelsHidden()
                            }
                        }
                    },
                    footer: {
                        Button {
                            saveCalendarEdit(calendar)
                        } label: {
                            Text("Save Changes")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(LGradients.blue)
                                .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                        }
                        .buttonStyle(.plain)
                        .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(80)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: showingAddPopup)
        .animation(.spring(response: 0.35, dampingFraction: 0.82), value: editingCalendar?.serverId)
    }

    // MARK: - Row

    @ViewBuilder
    private func calendarRow(_ calendar: EventCalendar) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(ly_hex: calendar.color))
                .frame(width: 12, height: 12)

            Text(calendar.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(LColors.textPrimary)

            if calendar.isDefault {
                Text("Default")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
            }

            Spacer()

            Button {
                editingCalendar = calendar
                editedName = calendar.name
                editedColor = Color(ly_hex: calendar.color)
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(LColors.glassBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            if !calendar.isDefault {
                Button {
                    deleteCalendar(calendar)
                } label: {
                    Image("trashfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .foregroundStyle(LColors.danger)
                        .frame(width: 30, height: 30)
                        .background(LColors.danger.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(LColors.danger.opacity(0.2), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
    }

    // MARK: - Actions

    private func saveNewCalendar() {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let descriptor = FetchDescriptor<EventCalendar>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        let maxOrder = existing.map(\.sortOrder).max() ?? 0

        let calendar = EventCalendar(
            name: trimmed,
            color: newColorUI.toHexString(),
            sortOrder: maxOrder + 1,
            isDefault: existing.isEmpty
        )
        modelContext.insert(calendar)
        try? modelContext.save()
        showingAddPopup = false
        newName = ""
    }

    private func saveCalendarEdit(_ calendar: EventCalendar) {
        let trimmed = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        calendar.name = trimmed
        calendar.color = editedColor.toHexString()
        try? modelContext.save()
        editingCalendar = nil
    }

    private func deleteCalendar(_ calendar: EventCalendar) {
        guard !calendar.isDefault else { return }
        let descriptor = FetchDescriptor<CalendarEvent>()
        let events = (try? modelContext.fetch(descriptor)) ?? []
        if let defaultCal = calendars.first(where: { $0.isDefault }) {
            for event in events where event.calendarId == calendar.serverId {
                event.calendarId = defaultCal.serverId
                event.calendar = defaultCal
            }
        }
        modelContext.delete(calendar)
        try? modelContext.save()
    }
}
