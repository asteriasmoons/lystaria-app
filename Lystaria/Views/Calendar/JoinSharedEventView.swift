//
//  JoinSharedEventView.swift
//  Lystaria

import SwiftUI
import SwiftData

struct JoinSharedEventView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var authUsers: [AuthUser]

    @State private var joinCodeInput: String = ""
    @State private var statusMessage: String = ""
    @State private var isLoading: Bool = false
    @State private var joinedEvent: CalendarEvent? = nil
    @State private var showDetailForJoined: Bool = false

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

    private var trimmedCode: String {
        joinCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {

                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            GradientTitle(text: "Join Event", size: 26)
                            Text("Enter a code shared by an event host.")
                                .font(.system(size: 14))
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

                    // Icon lockup
                    ZStack {
                        Circle()
                            .fill(LColors.accent.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Image(systemName: "person.2.badge.key.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(LColors.accent)
                    }

                    // Code entry
                    VStack(alignment: .leading, spacing: 10) {
                        Text("JOIN CODE")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        TextField("e.g. AB12CD34", text: $joinCodeInput)
                            .textFieldStyle(.plain)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                            .multilineTextAlignment(.center)
                            .tracking(4)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                            .onChange(of: joinCodeInput) { _, new in
                                let sanitized = new.uppercased().filter { $0.isLetter || $0.isNumber }
                                if sanitized != new || new.count > 8 {
                                    joinCodeInput = String(sanitized.prefix(8))
                                }
                                statusMessage = ""
                            }
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
                    }

                    // Status
                    if !statusMessage.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: statusMessage.lowercased().contains("joined") ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(statusMessage.lowercased().contains("joined") ? LColors.success : LColors.danger)
                            Text(statusMessage)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Join button
                    Button {
                        Task { await joinByCode() }
                    } label: {
                        HStack(spacing: 10) {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Join Event")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundStyle(trimmedCode.count < 8 ? LColors.textSecondary : .white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background {
                            if trimmedCode.count < 8 {
                                Color.white.opacity(0.06)
                            } else {
                                LGradients.blue
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 14))
    
                    }
                    .buttonStyle(.plain)
                    .disabled(trimmedCode.count < 8 || isLoading)

                    // View joined event link
                    if let joined = joinedEvent {
                        Button {
                            showDetailForJoined = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar.badge.checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("View Event: \(joined.title)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(LColors.accent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(LColors.accent.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.accent.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(isPresented: $showDetailForJoined) {
            if let joined = joinedEvent {
                SharedEventDetailView(event: joined)
                    .preferredColorScheme(.dark)
            }
        }
    }

    // MARK: - Join Logic

    private func joinByCode() async {
        let code = trimmedCode
        guard !code.isEmpty else { return }

        isLoading = true
        statusMessage = ""
        defer { isLoading = false }

        do {
            let lookupResponse = try await SharedEventsAPIService.shared.fetchSharedEventByJoinCode(
                joinCode: code,
                currentUserId: currentUserId
            )
            let dto = lookupResponse.event

            let joinResponse = try await SharedEventsAPIService.shared.joinSharedEventByCode(
                JoinSharedEventByCodeRequestDTO(
                    joinCode: code,
                    userId: currentUserId,
                    displayName: currentUserName
                )
            )

            let localEventId = dto.localEventId
            let descriptor = FetchDescriptor<CalendarEvent>(
                predicate: #Predicate { $0.localEventId == localEventId }
            )
            let existingLocal = try? modelContext.fetch(descriptor).first

            let isoParser: DateFormatter = {
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
                return df
            }()
            let parsedStart = isoParser.date(from: dto.startDate) ?? Date()
            let parsedEnd = dto.endDate.flatMap { isoParser.date(from: $0) }

            let localEvent: CalendarEvent
            if let existing = existingLocal {
                existing.participationStatus = .joined
                existing.serverId = dto.id
                existing.joinCode = dto.joinCode
                existing.attendeeCount = joinResponse.event.attendeeCount
                existing.updatedAt = Date()
                localEvent = existing
            } else {
                let newEvent = CalendarEvent(
                    title: dto.title,
                    startDate: parsedStart,
                    endDate: parsedEnd,
                    allDay: dto.allDay,
                    eventDescription: dto.eventDescription,
                    color: dto.color,
                    meetingUrl: dto.meetingUrl,
                    location: dto.location,
                    recurrenceRRule: dto.recurrenceRRule,
                    timeZoneId: dto.timeZoneId,
                    recurrence: nil,
                    recurrenceExceptions: [],
                    calendarId: dto.calendarId,
                    serverId: dto.id,
                    localEventId: dto.localEventId,
                    syncState: .synced,
                    isSharedEvent: true,
                    isJoinable: dto.isJoinable,
                    shareMode: CalendarEventShareMode(rawValue: dto.shareMode) ?? .shared,
                    participationStatus: .joined,
                    ownerUserId: dto.ownerUserId,
                    ownerDisplayName: dto.ownerDisplayName,
                    joinCode: dto.joinCode,
                    attendeeCount: joinResponse.event.attendeeCount
                )
                modelContext.insert(newEvent)
                localEvent = newEvent
            }

            try? modelContext.save()

            joinedEvent = localEvent
            statusMessage = "You joined \"\(dto.title)\"."
            joinCodeInput = ""

        } catch SharedEventsAPIError.httpError(_, let message) {
            switch message {
            case "HOST_ALREADY_MEMBER":
                statusMessage = "You're already the host of this event."
            case "EVENT_NOT_JOINABLE":
                statusMessage = "This event is not open to joining."
            case "EVENT_NOT_FOUND":
                statusMessage = "No event found with that code. Check and try again."
            default:
                statusMessage = "Error: \(message)"
            }
        } catch {
            statusMessage = "Could not join: \(error.localizedDescription)"
        }
    }
}
