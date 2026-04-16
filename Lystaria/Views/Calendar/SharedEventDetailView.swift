//
//  SharedEventDetailView.swift
//  Lystaria

import SwiftUI
import SwiftData

struct SharedEventDetailView: View {
    let event: CalendarEvent

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var authUsers: [AuthUser]

    @State private var apiAttendees: [SharedEventAttendeeDTO] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    @State private var statusMessage: String = ""

    private var currentUserId: String {
        if let id = authUsers.first?.serverId, !id.isEmpty { return id }
        let key = "LystariaCurrentUserId"
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty { return existing }
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: key)
        return newId
    }

    private var currentUserName: String {
        if let name = authUsers.first?.displayName,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return name }
        if let saved = UserDefaults.standard.string(forKey: "LystariaDisplayName"),
           !saved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return saved }
        return UIDevice.current.name
    }

    private var myAttendee: SharedEventAttendeeDTO? {
        apiAttendees.first(where: { $0.userId == currentUserId })
    }

    private var canAccept: Bool {
        guard let me = myAttendee else { return false }
        return !me.isHost && me.status == "invited"
    }

    private var canLeave: Bool {
        guard let me = myAttendee else { return false }
        return !me.isHost && me.status == "joined"
    }

    private var joinCode: String {
        event.joinCode.isEmpty ? "—" : event.joinCode
    }

    private var displayTimeZone: TimeZone {
        TimeZone(identifier: NotificationManager.shared.effectiveTimezoneID) ?? .current
    }

    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.timeZone = displayTimeZone
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("EEE MMM d, h:mm a")
        return df.string(from: date)
    }

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            GradientTitle(text: event.title, size: 26)
                            Text(formattedDate(event.startDate))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                        }
                        Spacer()
                        Button { dismiss() } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 22))
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    // Shared badge
                    HStack(spacing: 8) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.accent)
                        Text("Shared Event")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(LColors.accent)
                        Spacer()
                        if !isLoading {
                            Text("\(apiAttendees.count) attendee\(apiAttendees.count == 1 ? "" : "s")")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                        }
                    }
                    .padding(14)
                    .background(LColors.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.accent.opacity(0.25), lineWidth: 1))

                    // Join code card
                    GlassCard(padding: 16) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("JOIN CODE")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .tracking(0.5)

                            Text(joinCode)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(LColors.textPrimary)
                                .tracking(4)

                            HStack(spacing: 10) {
                                Button {
                                    UIPasteboard.general.string = joinCode
                                    statusMessage = "Join code copied."
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "doc.on.doc.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text("Copy")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(LGradients.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                .buttonStyle(.plain)

                                ShareLink(
                                    item: "Join my Lystaria event \"\(event.title)\" using code: \(joinCode)",
                                    subject: Text(event.title),
                                    message: Text("Use this join code in Lystaria: \(joinCode)")
                                ) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "square.and.arrow.up.fill")
                                            .font(.system(size: 12, weight: .semibold))
                                        Text("Share")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundStyle(LColors.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                                }
                            }
                        }
                    }

                    // Status message
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(LColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Accept / Leave actions
                    if canAccept || canLeave {
                        GlassCard(padding: 16) {
                            VStack(alignment: .leading, spacing: 10) {
                                if canAccept {
                                    Button {
                                        Task { await acceptInvite() }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 13, weight: .semibold))
                                            Text("Join Event")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(LGradients.blue)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    .buttonStyle(.plain)
                                }

                                if canLeave {
                                    Button {
                                        Task { await leaveEvent() }
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 13, weight: .semibold))
                                            Text("Leave Event")
                                                .font(.system(size: 14, weight: .semibold))
                                        }
                                        .foregroundStyle(LColors.danger)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 13)
                                        .background(LColors.danger.opacity(0.10))
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.danger.opacity(0.3), lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Attendees
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ATTENDEES")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        if isLoading {
                            HStack {
                                Spacer()
                                ProgressView().tint(LColors.accent)
                                Spacer()
                            }
                            .padding(.vertical, 20)
                        } else if let err = errorMessage {
                            Text(err)
                                .font(.system(size: 13))
                                .foregroundStyle(LColors.danger)
                        } else if apiAttendees.isEmpty {
                            Text("No attendees yet.")
                                .font(.system(size: 13))
                                .foregroundStyle(LColors.textSecondary)
                        } else {
                            VStack(spacing: 8) {
                                ForEach(apiAttendees) { person in
                                    attendeeRow(person)
                                }
                            }
                        }
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollIndicators(.hidden)
        }
        .task { await loadAttendees() }
    }

    // MARK: - Attendee Row

    private func attendeeRow(_ person: SharedEventAttendeeDTO) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(person.isHost ? LColors.accent.opacity(0.20) : Color.white.opacity(0.08))
                    .frame(width: 38, height: 38)
                Text(String(person.displayName.prefix(1)).uppercased())
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(person.isHost ? LColors.accent : LColors.textPrimary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(person.displayName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
                    .lineLimit(1)

                Text(person.status.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(LColors.textSecondary)
            }

            Spacer()

            if person.isHost {
                Text("HOST")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(LGradients.blue)
                    .clipShape(Capsule())
            } else {
                statusCapsule(for: person.status)
            }
        }
        .padding(12)
        .background(person.userId == currentUserId ? LColors.accent.opacity(0.06) : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(person.userId == currentUserId ? LColors.accent.opacity(0.25) : LColors.glassBorder, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statusCapsule(for status: String) -> some View {
        let (label, color): (String, Color) = {
            switch status {
            case "joined":   return ("Joined", LColors.success)
            case "invited":  return ("Invited", LColors.accent)
            case "declined": return ("Declined", LColors.danger)
            case "left":     return ("Left", LColors.textSecondary)
            default:         return (status.capitalized, LColors.textSecondary)
            }
        }()

        Text(label)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 1))
    }

    // MARK: - API Actions

    private func loadAttendees() async {
        guard let eventId = event.serverId, !eventId.isEmpty else {
            isLoading = false
            errorMessage = "This event has not been synced to the server yet."
            return
        }
        do {
            let fetched = try await SharedEventsAPIService.shared.fetchAttendees(eventId: eventId)
            apiAttendees = fetched
            isLoading = false
        } catch {
            isLoading = false
            errorMessage = "Could not load attendees: \(error.localizedDescription)"
        }
    }

    private func acceptInvite() async {
        guard let eventId = event.serverId, !eventId.isEmpty else {
            statusMessage = "Event not yet synced to server."
            return
        }
        do {
            let response = try await SharedEventsAPIService.shared.acceptInvite(
                eventId: eventId,
                request: AcceptSharedEventInviteRequestDTO(userId: currentUserId, displayName: currentUserName)
            )
            apiAttendees = response.attendees
            event.participationStatus = .joined
            event.attendeeCount = response.event.attendeeCount
            event.updatedAt = Date()
            try? modelContext.save()
            statusMessage = "You joined the event."
        } catch {
            statusMessage = "Failed to join: \(error.localizedDescription)"
        }
    }

    private func leaveEvent() async {
        guard let eventId = event.serverId, !eventId.isEmpty else {
            statusMessage = "Event not yet synced to server."
            return
        }
        do {
            let response = try await SharedEventsAPIService.shared.leaveSharedEvent(
                eventId: eventId,
                request: LeaveSharedEventRequestDTO(userId: currentUserId)
            )
            apiAttendees = response.attendees
            event.participationStatus = .left
            event.attendeeCount = response.event.attendeeCount
            event.updatedAt = Date()
            try? modelContext.save()
            statusMessage = "You left the event."
        } catch {
            statusMessage = "Failed to leave: \(error.localizedDescription)"
        }
    }
}
