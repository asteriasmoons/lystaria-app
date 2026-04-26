//
//  BuddyReadingView.swift
//  Lystaria
//

import SwiftUI

struct BuddyReadingView: View {
    @EnvironmentObject private var appState: AppState
    
    @State private var board: [BuddyAnnouncement] = []
    @State private var myAnnouncement: BuddyAnnouncement? = nil
    @State private var myGroup: BuddyGroup? = nil
    @State private var isLoading = false
    @State private var showPostSheet = false
    @State private var showGroupView = false
    @State private var errorMessage: String? = nil
    @State private var showSetDisplayName = false
    @State private var showChangeDisplayName = false
    @State private var localDisplayNameOverride: String = ""
    
    private var userId: String { appState.currentAppleUserId ?? "" }
    private var displayName: String {
        if !localDisplayNameOverride.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localDisplayNameOverride
        }
        return appState.currentUser?.displayName ?? ""
    }
    
    var body: some View {
        ZStack {
            LystariaBackground()
            mainContent
        }
        .navigationDestination(isPresented: $showGroupView) {
            if let group = myGroup {
                BuddyGroupView(group: group, userId: userId, displayName: displayName)
            }
        }
        .onAppear { Task { await loadAll() } }
        .overlay { postSheetOverlay }
        .overlay { displayNameOverlay }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showPostSheet)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showSetDisplayName)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showChangeDisplayName)
    }
    
    // MARK: - Main content
    
    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                myStatusSection
                boardSection
                Spacer(minLength: 96)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 140)
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                GradientTitle(text: "Buddy Reading", font: .largeTitle.bold())
                Spacer()
                
                Button {
                    showChangeDisplayName = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                            .frame(width: 34, height: 34)
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                
                Button {
                    Task { await loadAll() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                            .frame(width: 34, height: 34)
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 24)
            
            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)
                .padding(.top, 12)
        }
    }
    
    // MARK: - My status section
    
    private var myStatusSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    GradientTitle(text: "My Status", font: .system(size: 14, weight: .bold))
                    Spacer()
                }
                
                if let group = myGroup {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.2.fill")
                                .foregroundStyle(LColors.accent)
                            Text("Reading \(group.bookTitle) with \(group.joinedMembers.count) \(group.joinedMembers.count == 1 ? "buddy" : "buddies")")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        
                        HStack(spacing: 10) {
                            GradientCapsuleButton(title: "Open Chat", icon: "chatsfill") {
                                showGroupView = true
                            }
                            
                            Button {
                                Task { await leaveGroup() }
                            } label: {
                                Text("Leave Group")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textPrimary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(LColors.glassBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        
                        if !group.pendingMembers.isEmpty {
                            pendingRequestsBanner(group: group, pending: group.pendingMembers)
                        }
                    }
                    
                } else if let announcement = myAnnouncement {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Your announcement is live on the board")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(LColors.accent)
                            Text(announcement.bookTitle)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(LColors.textPrimary)
                        }
                        
                        if let msg = announcement.message, !msg.isEmpty {
                            Text("\"\(msg)\"")
                                .font(.subheadline)
                                .foregroundStyle(LColors.textSecondary)
                                .lineLimit(2)
                        }
                        
                        HStack(spacing: 10) {
                            Button {
                                Task { await removeMyAnnouncement() }
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: "minus.circle")
                                    Text("Remove")
                                        .font(.system(size: 13, weight: .semibold))
                                }
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Post what you're reading and find a buddy to read along with.")
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)
                        
                        Button {
                            showPostSheet = true
                        } label: {
                            HStack(spacing: 8) {
                                Image("pluswavy")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 14, height: 14)
                                Text("Post Announcement")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(LGradients.blue)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .shadow(color: LColors.accent.opacity(0.28), radius: 10, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.85))
                }
            }
        }
    }
    
    // MARK: - Pending requests banner
    
    private func pendingRequestsBanner(group: BuddyGroup, pending: [BuddyMember]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(pending.count) join \(pending.count == 1 ? "request" : "requests") waiting")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LColors.textPrimary)
            
            ForEach(pending) { member in
                HStack(spacing: 10) {
                    Text(member.displayName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textPrimary)
                    
                    Spacer()
                    
                    Button {
                        Task { await respond(groupId: group.id, targetUserId: member.userId, accept: true) }
                    } label: {
                        Text("Accept")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(LColors.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        Task { await respond(groupId: group.id, targetUserId: member.userId, accept: false) }
                    } label: {
                        Text("Decline")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(LColors.glassSurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.glassBorder, lineWidth: 1))
            }
        }
        .padding(.top, 4)
    }
    
    // MARK: - Display name overlay
    
    private var displayNameOverlay: some View {
        ZStack {
            if showSetDisplayName {
                SetDisplayNameSheet(
                    userId: userId,
                    isChanging: false,
                    onClose: nil,
                    onSaved: { newName in
                        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        localDisplayNameOverride = trimmed
                        applyUpdatedDisplayName(trimmed)
                        showSetDisplayName = false
                        Task { await loadAll() }
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(90)
            }
            if showChangeDisplayName {
                SetDisplayNameSheet(
                    userId: userId,
                    isChanging: true,
                    onClose: { showChangeDisplayName = false },
                    onSaved: { newName in
                        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
                        localDisplayNameOverride = trimmed
                        applyUpdatedDisplayName(trimmed)
                        showChangeDisplayName = false
                        Task { await loadAll() }
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(90)
            }
        }
    }
    
    // MARK: - Board
    
    private var boardSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                GradientTitle(text: "Announcement Board", font: .system(size: 16, weight: .bold))
                Spacer()
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                }
            }
            
            if board.isEmpty && !isLoading {
                GlassCard {
                    Text("No announcements yet. Be the first to post!")
                        .font(.subheadline)
                        .foregroundStyle(LColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                }
            } else {
                ForEach(board) { announcement in
                    BuddyAnnouncementCard(
                        announcement: announcement,
                        currentUserId: userId,
                        currentUserDisplayName: displayName,
                        myGroup: myGroup,
                        onRequestJoin: {
                            Task { await requestToJoin(announcement: announcement) }
                        }
                    )
                }
            }
        }
    }
    
    // MARK: - Post sheet overlay
    
    private var postSheetOverlay: some View {
        ZStack {
            if showPostSheet {
                BuddyPostAnnouncementSheet(
                    userId: userId,
                    displayName: displayName,
                    onClose: { showPostSheet = false },
                    onPost: { announcement in
                        myAnnouncement = announcement
                        showPostSheet = false
                        Task { await loadBoard() }
                    }
                )
                .preferredColorScheme(.dark)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(80)
            }
        }
    }
    
    // MARK: - Actions
    
    private func loadAll() async {
        isLoading = true
        errorMessage = nil
        async let board = loadBoard()
        async let myAnnouncement = loadMyAnnouncement()
        async let myGroup = loadMyGroup()
        _ = await (board, myAnnouncement, myGroup)
        isLoading = false
        
        if (appState.currentUser?.displayName ?? "").isEmpty {
            showSetDisplayName = true
        }
    }
    
    @discardableResult
    private func loadBoard() async -> Void {
        do {
            board = try await BuddyService.shared.getBoard(userId: userId)
        } catch {
            errorMessage = "Failed to load board"
        }
    }
    
    @discardableResult
    private func loadMyAnnouncement() async -> Void {
        myAnnouncement = try? await BuddyService.shared.getMyAnnouncement(userId: userId)
    }
    
    @discardableResult
    private func loadMyGroup() async -> Void {
        myGroup = try? await BuddyService.shared.getMyGroup(userId: userId)
    }
    
    private func removeMyAnnouncement() async {
        guard let id = myAnnouncement?.id else { return }
        do {
            try await BuddyService.shared.removeAnnouncement(id: id, userId: userId)
            myAnnouncement = nil
            await loadBoard()
        } catch {
            errorMessage = "Failed to remove announcement"
        }
    }
    
    private func requestToJoin(announcement: BuddyAnnouncement) async {
        guard myGroup == nil else { return }
        do {
            let currentDisplayName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            let body = RequestToJoinBody(
                announcementId: announcement.id,
                requesterUserId: userId,
                requesterDisplayName: currentDisplayName
            )
            myGroup = try await BuddyService.shared.requestToJoin(body: body)
        } catch {
            errorMessage = "Failed to send join request"
        }
    }
    
    private func respond(groupId: String, targetUserId: String, accept: Bool) async {
        guard let ownerId = myGroup?.members.first(where: { $0.isOwner })?.userId,
              ownerId == userId else { return }
        do {
            let body = RespondToJoinBody(actorUserId: userId, targetUserId: targetUserId, accept: accept)
            myGroup = try await BuddyService.shared.respondToJoinRequest(groupId: groupId, body: body)
        } catch {
            errorMessage = "Failed to respond to request"
        }
    }
    
    private func leaveGroup() async {
        guard let groupId = myGroup?.id else { return }
        do {
            try await BuddyService.shared.leaveGroup(groupId: groupId, userId: userId)
            myGroup = nil
            await loadAll()
        } catch {
            errorMessage = "Failed to leave group"
        }
    }
    
    private func applyUpdatedDisplayName(_ newName: String) {
        guard !newName.isEmpty else { return }
        localDisplayNameOverride = newName
    }
    
    // MARK: - Announcement card
    
    struct BuddyAnnouncementCard: View {
        let announcement: BuddyAnnouncement
        let currentUserId: String
        let currentUserDisplayName: String
        let myGroup: BuddyGroup?
        let onRequestJoin: () -> Void
        
        private var alreadyInGroup: Bool { myGroup != nil }
        private var spotsLeft: Int { announcement.maxMembers - 1 }
        
        private var ownerNameText: String {
            announcement.ownerUserId == currentUserId ? currentUserDisplayName : announcement.ownerDisplayName
        }
        
        var body: some View {
            GlassCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "book.closed.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(LColors.accent)
                                Text(announcement.bookTitle)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(LColors.textPrimary)
                            }
                            
                            if let author = announcement.bookAuthor, !author.isEmpty {
                                Text(author)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)
                            }
                        }
                        
                        Spacer()
                        
                        Text("\(announcement.maxMembers - 1) spot\(spotsLeft == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(LColors.textSecondary)
                        Text(ownerNameText)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                    }
                    
                    if let chapter = announcement.currentChapter {
                        Text("Currently on chapter \(chapter)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                    } else if let page = announcement.currentPage {
                        Text("Currently on page \(page)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                    }
                    
                    if let msg = announcement.message, !msg.isEmpty {
                        Text("\"\(msg)\"")
                            .font(.subheadline)
                            .foregroundStyle(LColors.textSecondary)
                            .lineLimit(3)
                    }
                    
                    HStack(spacing: 10) {
                        Button {
                            onRequestJoin()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "person.badge.plus")
                                Text("Request to Read Together")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(alreadyInGroup ? LColors.textSecondary : .white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(alreadyInGroup ? Color.white.opacity(0.05) : LColors.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(alreadyInGroup)
                        
                        Spacer()
                    }
                }
            }
        }
    }
}
