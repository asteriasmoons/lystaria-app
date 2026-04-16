//
//  CalendarEventDetailOverlay.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/14/26.
//

import SwiftUI
import SwiftData

struct CalendarEventDetailOverlay: View {
    let event: CalendarEvent
    let occurrenceStart: Date
    let occurrenceEnd: Date?
    let onClose: () -> Void
    @Environment(\.openURL) private var openURL
    @Query(sort: \CalendarEvent.startDate) private var allEvents: [CalendarEvent]
    @State private var showingOverview = false
    @State private var showingSharedDetail = false

    private var displayTimeZone: TimeZone {
        TimeZone(identifier: NotificationManager.shared.effectiveTimezoneID) ?? .current
    }

    private var formattedTime: String {
        if event.allDay { return "All Day" }
        let df = DateFormatter()
        df.timeZone = displayTimeZone
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("h:mm a")
        let start = df.string(from: occurrenceStart)
        if let occurrenceEnd {
            return "\(start) – \(df.string(from: occurrenceEnd))"
        }
        return start
    }

    private var parsedRecurrence: ParsedRRule? {
        guard let rule = event.recurrenceRRule else { return nil }
        return ParsedRRule.parse(rule)
    }

    private var recurrenceText: String? {
        guard let parsedRecurrence else { return nil }
        let interval = max(1, parsedRecurrence.interval)
        switch parsedRecurrence.freq {
        case .daily:   return interval == 1 ? "Repeats daily"   : "Repeats every \(interval) days"
        case .weekly:  return interval == 1 ? "Repeats weekly"  : "Repeats every \(interval) weeks"
        case .monthly: return interval == 1 ? "Repeats monthly" : "Repeats every \(interval) months"
        case .yearly:  return interval == 1 ? "Repeats yearly"  : "Repeats every \(interval) years"
        }
    }

    private var locationName: String? {
        guard let loc = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !loc.isEmpty else { return nil }
        return loc.components(separatedBy: " — ").first?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var locationAddress: String? {
        guard let loc = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !loc.isEmpty else { return nil }
        let parts = loc.components(separatedBy: " — ")
        guard parts.count > 1 else { return nil }
        let address = parts.dropFirst().joined(separator: " — ").trimmingCharacters(in: .whitespacesAndNewlines)
        return address.isEmpty ? nil : address
    }

    private var trimmedDescription: String? {
        guard let text = event.eventDescription?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return text
    }

    private var meetingURLValue: URL? {
        guard let raw = event.meetingUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
        if let direct = URL(string: raw), direct.scheme != nil { return direct }
        return URL(string: "https://\(raw)")
    }

    private var hasReminder: Bool { event.reminderServerId != nil }

    var body: some View {
        ZStack {
            // Dimmed backdrop — tapping it closes the popup
            Color.black.opacity(0.62)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            // Popup card
            VStack(alignment: .leading, spacing: 18) {

                // Title row
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color(ly_hex: event.color ?? "#5b8def"))
                        .frame(width: 14, height: 14)
                        .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 6) {
                        GradientTitle(text: event.title, size: 24)
                            .fixedSize(horizontal: false, vertical: true)
                        if event.allDay {
                            Text("All-day event")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                        }
                    }

                    Spacer()

                    Button { onClose() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                // Detail rows
                VStack(alignment: .leading, spacing: 14) {
                    DetailRow(icon: .asset("fillalarm"), title: "Time", primaryText: formattedTime)

                    if let recurrenceText {
                        DetailRow(icon: .system("repeat.circle.fill"), title: "Repeat", primaryText: recurrenceText)
                    }

                    if hasReminder {
                        DetailRow(icon: .asset("bellfill"), title: "Reminder", primaryText: "Reminder enabled")
                    }

                    if let locationName {
                        DetailRow(icon: .asset("heartpinfill"), title: "Location", primaryText: locationName, secondaryText: locationAddress)
                    }

                    if let meetingURLValue {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(alignment: .top, spacing: 12) {
                                Image("linkfill")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(.white)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("LINK")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(LColors.textSecondary)
                                        .tracking(0.6)

                                    Button {
                                        openURL(meetingURLValue)
                                    } label: {
                                        Text("Open Event Link")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 10)
                                            .background(LGradients.blue)
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    if let trimmedDescription {
                        DetailRow(icon: .asset("stickyfill"), title: "Description", primaryText: trimmedDescription, multiline: true)
                    }

                    if event.isSharedEvent {
                        // Shared event row — icon + capsule badge + tap to open full detail
                        Button {
                            showingSharedDetail = true
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "person.2.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 18, height: 18)
                                    .foregroundStyle(LColors.accent)
                                    .padding(.top, 2)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("SHARED EVENT")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(LColors.textSecondary)
                                        .tracking(0.6)

                                    HStack(spacing: 8) {
                                        Text("Shared")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(LColors.accent)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(LColors.accent.opacity(0.12))
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(LColors.accent.opacity(0.3), lineWidth: 1))

                                        if event.attendeeCount > 0 {
                                            Text("\(event.attendeeCount) attendee\(event.attendeeCount == 1 ? "" : "s")")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(LColors.textSecondary)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(Color.white.opacity(0.08))
                                                .clipShape(Capsule())
                                                .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                                        }

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(LColors.textSecondary)
                                    }
                                }

                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                    }

                } // end detail rows VStack

                // Overview button
                Button { showingOverview = true } label: {
                    HStack(spacing: 10) {
                        Image("calfill")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.white)
                        Text("Overview")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(22)
            .frame(maxWidth: 420)
            .background(ZStack {
                LystariaBackground()
                Color.black.opacity(0.28)
            })
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(LColors.glassBorder, lineWidth: 1))
            .padding(.horizontal, 20)
            .shadow(color: .black.opacity(0.25), radius: 24, x: 0, y: 10)
            .sheet(isPresented: $showingOverview) {
                CalendarOverviewSheet(allEvents: allEvents)
                    .preferredColorScheme(.dark)
            }
            .sheet(isPresented: $showingSharedDetail) {
                SharedEventDetailView(event: event)
                    .preferredColorScheme(.dark)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

private struct DetailRow: View {
    enum IconKind {
        case system(String)
        case asset(String)
    }

    let icon: IconKind
    let title: String
    let primaryText: String
    var secondaryText: String? = nil
    var multiline: Bool = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            iconView
                .frame(width: 18, height: 18)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LColors.textSecondary)
                    .tracking(0.6)

                Text(primaryText)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: multiline)

                if let secondaryText, !secondaryText.isEmpty {
                    Text(secondaryText)
                        .font(.system(size: 13))
                        .foregroundStyle(LColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var iconView: some View {
        switch icon {
        case .system(let name):
            Image(systemName: name).resizable().scaledToFit().foregroundStyle(.white)
        case .asset(let name):
            Image(name).renderingMode(.template).resizable().scaledToFit().foregroundStyle(.white)
        }
    }
}
