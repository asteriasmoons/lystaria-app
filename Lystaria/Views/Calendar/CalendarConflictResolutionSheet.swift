//
//  CalendarConflictResolutionSheet.swift
//  Lystaria
//
//  Shows all .conflicted CalendarEvents and lets the user pick
//  "Keep Mine" (local wins) or "Use Calendar's" (external wins) per event.
//

import SwiftUI
import SwiftData

struct CalendarConflictResolutionSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let conflictedEvents: [CalendarEvent]
    var onResolved: (() -> Void)? = nil

    private var displayTimeZone: TimeZone {
        TimeZone(identifier: NotificationManager.shared.effectiveTimezoneID) ?? .current
    }

    private var tzCalendar: Calendar {
        var cal = Calendar.current
        cal.timeZone = displayTimeZone
        return cal
    }

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 6) {
                    GradientTitle(text: "Conflicts", size: 22)
                    Text("\(conflictedEvents.count) event\(conflictedEvents.count == 1 ? "" : "s") changed in both places")
                        .font(.system(size: 13))
                        .foregroundStyle(LColors.textSecondary)
                }
                .padding(.top, 24)
                .padding(.bottom, 16)

                Rectangle()
                    .fill(LColors.glassBorder)
                    .frame(height: 1)

                if conflictedEvents.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(LColors.success)
                        Text("All conflicts resolved")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(conflictedEvents) { event in
                                ConflictCard(
                                    event: event,
                                    displayTimeZone: displayTimeZone,
                                    onKeepLocal: {
                                        CalendarEventSyncHelper.resolveConflictKeepLocal(event)
                                        try? modelContext.save()
                                    },
                                    onUseExternal: {
                                        CalendarEventSyncHelper.resolveConflictUseExternal(event)
                                        try? modelContext.save()
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                        .padding(.bottom, 32)
                    }
                }

                // Footer
                Rectangle()
                    .fill(LColors.glassBorder)
                    .frame(height: 1)

                Button {
                    onResolved?()
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LGradients.blue)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .padding(16)
            }
        }
    }
}

// MARK: - ConflictCard

private struct ConflictCard: View {
    let event: CalendarEvent
    let displayTimeZone: TimeZone
    let onKeepLocal: () -> Void
    let onUseExternal: () -> Void

    private var dateText: String {
        let df = DateFormatter()
        df.timeZone = displayTimeZone
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate(event.allDay ? "MMMd" : "MMMd, h:mm a")
        return df.string(from: event.startDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Event identity
            HStack(spacing: 10) {
                Circle()
                    .fill(Color(ly_hex: event.color ?? "#5b8def"))
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 3) {
                    Text(event.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(LColors.textPrimary)
                        .lineLimit(2)

                    Text(dateText)
                        .font(.system(size: 12))
                        .foregroundStyle(LColors.textSecondary)
                }

                Spacer()

                // Conflict badge
                Text("CONFLICT")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(LColors.danger)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(LColors.danger.opacity(0.14))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(LColors.danger.opacity(0.3), lineWidth: 1))
            }

            // Explanation
            Text("This event was edited here and in Apple Calendar since the last sync. Choose which version to keep.")
                .font(.system(size: 12))
                .foregroundStyle(LColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            // Action buttons
            HStack(spacing: 10) {
                // Keep local
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        onKeepLocal()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "iphone")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Keep Mine")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(LGradients.blue)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                // Use external
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        onUseExternal()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Use Calendar's")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .foregroundStyle(LColors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(LColors.glassBorder, lineWidth: 1))
    }
}
