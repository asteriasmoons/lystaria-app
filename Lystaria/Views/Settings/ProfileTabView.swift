//
// ProfileTabView.swift
//
// Created By Asteria Moon
//

import SwiftUI
import SwiftData
import GoogleSignIn
import PhotosUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct ProfileTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var authUsers: [AuthUser]
    @Query private var userSettings: [UserSettings]

    @State private var isSyncing = false
    @State private var errorText: String? = nil
    @State private var syncMessage: String? = nil

#if os(macOS)
    @State private var profileImage: NSImage? = nil
#else
    @State private var profileImage: UIImage? = nil
#endif

#if os(iOS)
    @State private var selectedPhoto: PhotosPickerItem? = nil
#endif

    @AppStorage("profileImagePath") private var profileImagePathDefaults: String = ""

    @State private var selectedTimezoneIdentifier: String = TimeZone.current.identifier
    @State private var useSystemTimezone: Bool = true
    @State private var showTimezonePicker: Bool = false
    @State private var timezoneSearch: String = ""

    // Cached list of IANA timezones
    private let allTimezones: [String] = TimeZone.knownTimeZoneIdentifiers.sorted()

    private var currentUser: AuthUser? { authUsers.first }
    private var settings: UserSettings? { userSettings.first }

    private func ensureSettings() -> UserSettings {
        if let s = settings { return s }
        let s = UserSettings()
        modelContext.insert(s)
        return s
    }

    private var effectiveTimezoneLabel: String {
        useSystemTimezone ? "System (\(TimeZone.current.identifier))" : selectedTimezoneIdentifier
    }

    private var filteredTimezones: [String] {
        let query = timezoneSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        if query.isEmpty { return allTimezones }
        return allTimezones.filter { $0.localizedCaseInsensitiveContains(query) }
    }

    private func saveTimezoneSettings() {
        let s = ensureSettings()
        s.useSystemTimezone = useSystemTimezone
        s.timezoneIdentifier = selectedTimezoneIdentifier
        s.updatedAt = Date()
        
        let defaults = UserDefaults.standard
        defaults.set(useSystemTimezone, forKey: "lystaria.useSystemTimezone")
        defaults.set(selectedTimezoneIdentifier, forKey: "lystaria.timezoneIdentifier")
    }

    var body: some View {
        ZStack {
            LystariaBackground()

            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 0) {
                        HStack {
                            Spacer()
                            GradientTitle(text: "Profile", font: .system(size: 28, weight: .bold))
                            Spacer()
                        }

                        Rectangle()
                            .fill(LColors.glassBorder)
                            .frame(height: 1)
                            .padding(.top, 6)
                    }

                    // Profile avatar + card
                    VStack(spacing: 14) {
                        // Avatar
                        ZStack {
                            if let img = profileImage {
                                #if os(macOS)
                                Image(nsImage: img)
                                    .resizable()
                                    .scaledToFill()
                                #else
                                Image(uiImage: img)
                                    .resizable()
                                    .scaledToFill()
                                #endif
                            } else {
                                if let path = currentUser?.profileImagePath, let url = URL(string: path) {
                                    #if os(macOS)
                                    if let img = NSImage(contentsOf: url) {
                                        Image(nsImage: img)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image(systemName: "person.crop.circle")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundStyle(LColors.textSecondary)
                                            .padding(14)
                                    }
                                    #else
                                    if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image(systemName: "person.crop.circle")
                                            .resizable()
                                            .scaledToFit()
                                            .foregroundStyle(LColors.textSecondary)
                                            .padding(14)
                                    }
                                    #endif
                                } else {
                                    Image(systemName: "person.crop.circle")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundStyle(LColors.textSecondary)
                                        .padding(14)
                                }
                            }
                        }
                        .frame(width: 96, height: 96)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)

                        #if os(macOS)
                        Button(action: { pickProfileImage() }) {
                            Text("Change Photo")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        #else
                        #if os(iOS)
                        PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                            Text("Change Photo")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textPrimary)
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .onChange(of: selectedPhoto) { _, newItem in
                            guard let newItem else { return }
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                                    self.profileImage = uiImage
                                    if saveUIImageToAppSupport(uiImage) != nil {
                                        // Always mirror to AppStorage
                                        self.profileImagePathDefaults = "profile.png"
                                        if let user = currentUser {
                                            user.profileImagePath = "profile.png"
                                            do {
                                                try modelContext.save()
                                                print("[ProfileTabView] Saved profileImagePath as filename after iOS pick")
                                            } catch {
                                                print("[ProfileTabView] Failed to save profileImagePath after iOS pick: \(error)")
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        #endif
                        #endif

                        Button(action: { removeProfileImage() }) {
                            Text("Remove Photo")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(LColors.danger)
                                .padding(.horizontal, 10).padding(.vertical, 6)
                                .background(Color.white.opacity(0.06))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(LColors.glassBorder, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .disabled(currentUser?.profileImagePath == nil && profileImage == nil)

                        // Info card
                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                if let user = currentUser {
                                    HStack(spacing: 10) {
                                        Image(systemName: "person.crop.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundStyle(LColors.accent)
                                        Text(signInProviderLabel(for: user))
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(LColors.textPrimary)
                                    }

                                    if let name = user.displayName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        labeledRow(label: "Name", value: name)
                                    }

                                    labeledRow(label: "Email", value: user.email ?? "(none)")

                                    if let gid = user.googleUserId { labeledRow(label: "Google ID", value: gid) }
                                    if let aid = user.appleUserId { labeledRow(label: "Apple ID", value: aid) }

                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Not signed in")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(LColors.textPrimary)
                                        Text("Sign in from the main view to sync across devices.")
                                            .font(.subheadline)
                                            .foregroundStyle(LColors.textSecondary)
                                    }
                                }
                            }
                        }

                        GlassCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Timezone")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(LColors.textSecondary)

                                // Use System Timezone toggle
                                HStack(spacing: 10) {
                                    Text("Use System Timezone")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)
                                    Spacer()
                                    Toggle("", isOn: Binding(get: { useSystemTimezone }, set: { newVal in
                                        useSystemTimezone = newVal
                                        saveTimezoneSettings()
                                    }))
                                    .labelsHidden()
                                }
                                .padding(10)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.glassBorder, lineWidth: 1))

                                // Picker for manual timezone when not using system
                                if !useSystemTimezone {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text("SELECT TIMEZONE")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(LColors.textSecondary)
                                            .tracking(0.5)

                                        #if os(iOS)
                                        // Search field
                                        TextField("Search timezones", text: $timezoneSearch)
                                            .textFieldStyle(.plain)
                                            .foregroundStyle(LColors.textPrimary)
                                            .padding(8)
                                            .background(Color.white.opacity(0.06))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                                        #endif

                                        // List of timezones (limited height)
                                        ScrollView {
                                            LazyVStack(alignment: .leading, spacing: 6) {
                                                ForEach(filteredTimezones, id: \.self) { tz in
                                                    let on = tz == selectedTimezoneIdentifier
                                                    Button(action: {
                                                        selectedTimezoneIdentifier = tz
                                                        saveTimezoneSettings()
                                                    }) {
                                                        HStack {
                                                            Text(tz)
                                                                .font(.system(size: 13))
                                                                .foregroundStyle(LColors.textPrimary)
                                                            Spacer()
                                                            if on { Image(systemName: "checkmark").foregroundStyle(LColors.accent) }
                                                        }
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 6)
                                                        .background(on ? Color.white.opacity(0.08) : Color.clear)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    }
                                                    .buttonStyle(.plain)
                                                }
                                            }
                                        }
                                        .frame(maxHeight: 150)
                                    }
                                    .padding(10)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.glassBorder, lineWidth: 1))
                                }

                                // Effective label
                                HStack(spacing: 8) {
                                    Image(systemName: "globe")
                                        .font(.caption)
                                        .foregroundStyle(LColors.textSecondary)
                                    Text(effectiveTimezoneLabel)
                                        .font(.subheadline)
                                        .foregroundStyle(LColors.textSecondary)
                                }
                            }
                        }
                    }

                    if let errorText { errorBanner(errorText) }
                    if let syncMessage { successBanner(syncMessage) }

                    GlassCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Actions")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)

                            HStack(spacing: 10) {
                                LButton(title: isSyncing ? "Syncing..." : "Sync Now", icon: "arrow.triangle.2.circlepath", style: .gradient) {
                                    triggerSync()
                                }
                                .disabled(isSyncing)

                                LButton(title: "Sign Out", icon: "rectangle.portrait.and.arrow.right", style: .danger) {
                                    signOut()
                                }
                                .disabled(currentUser == nil)
                            }
                        }
                    }

                    Spacer(minLength: 80)
                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, LSpacing.pageHorizontal)
                .padding(.vertical, 20)
                .onAppear {
                    if let s = settings {
                        self.useSystemTimezone = s.useSystemTimezone
                        self.selectedTimezoneIdentifier = s.timezoneIdentifier
                    } else {
                        // Ensure we have a settings row so subsequent saves persist
                        _ = ensureSettings()
                    }
                    let defaults = UserDefaults.standard
                    defaults.set(self.useSystemTimezone, forKey: "lystaria.useSystemTimezone")
                    defaults.set(self.selectedTimezoneIdentifier, forKey: "lystaria.timezoneIdentifier")
                    
                    #if os(iOS)
                    if let dir = appSupportURL() {
                        let url = dir.appendingPathComponent("profile.png")
                        let exists = FileManager.default.fileExists(atPath: url.path)
                        print("[ProfileTabView] DEBUG profile.png exists at launch:", exists, "->", url.path)
                    }
                    #endif
                    
                    loadProfileImage()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        if self.profileImage == nil {
                            print("[ProfileTabView] Retrying profile image load after delay")
                            loadProfileImage()
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                        if self.profileImage == nil {
                            print("[ProfileTabView] Retrying profile image load after second delay")
                            loadProfileImage()
                        }
                    }
                }
                .onChange(of: currentUser?.profileImagePath) {
                    loadProfileImage()
                }
                .onChange(of: profileImagePathDefaults) {
                    loadProfileImage()
                }
            }
        }
    }

    private func signInProviderLabel(for user: AuthUser) -> String {
        switch user.authProvider {
        case .google:
            return "Signed in with Google"
        case .email:
            return "Signed in with Email"
        case .apple:
            return "Signed in with Apple"
        }
    }

    private func labeledRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(LColors.textSecondary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 14))
                .foregroundStyle(LColors.textPrimary)
        }
    }

    private func errorBanner(_ text: String) -> some View {
        GlassCard {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(LColors.danger)
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.danger)
                Spacer()
            }
        }
    }

    private func successBanner(_ text: String) -> some View {
        GlassCard {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.textPrimary)
                Spacer()
            }
        }
    }

    private func triggerSync() {
        errorText = nil
        syncMessage = nil

        guard currentUser != nil else {
            errorText = "You need to be signed in before syncing."
            return
        }

        isSyncing = true
        print("[ProfileTabView] Starting full sync...")

        Task {
            do {
                try await SyncService.shared.syncBooks(context: modelContext)
                try SyncService.shared.forceReminderResync(context: modelContext)
                try await SyncService.shared.syncReminders(context: modelContext)
                try SyncService.shared.forceJournalBookResync(context: modelContext)
                try await SyncService.shared.syncJournalBooks(context: modelContext)
                try SyncService.shared.forceJournalEntryResync(context: modelContext)
                try await SyncService.shared.syncJournalEntries(context: modelContext)
                try await SyncService.shared.syncMoodLogs(context: modelContext)

                await MainActor.run {
                    syncMessage = "Sync complete. Reminders, journal data, and mood logs were synced."
                    isSyncing = false
                }
                print("[ProfileTabView] Full sync complete. Reminders, journal data, and mood logs were synced.")
            } catch {
                await MainActor.run {
                    errorText = error.localizedDescription
                    isSyncing = false
                }
                print("[ProfileTabView] Full sync failed: \(error)")
            }
        }
    }

    private func signOut() {
        errorText = nil
        // Google Sign-Out (safe on all platforms)
        GIDSignIn.sharedInstance.signOut()

        // Optionally clear local user record(s). If you want to keep the user
        // row for history, remove this block.
        if let user = currentUser {
            modelContext.delete(user)
        }
    }

    private func pickProfileImage() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.title = "Choose a profile picture"
        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [.png, .jpeg, .heic]
        } else {
            panel.allowedFileTypes = ["png","jpg","jpeg","heic"]
        }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.begin { response in
            if response == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
                self.profileImage = img
                if let user = currentUser {
                    user.profileImagePath = url.absoluteString
                    self.profileImagePathDefaults = url.absoluteString
                    do {
                        try modelContext.save()
                        print("[ProfileTabView] Saved profileImagePath after macOS pick")
                    } catch {
                        print("[ProfileTabView] Failed to save profileImagePath after macOS pick: \(error)")
                    }
                }
                // TODO: Persist image URL or data to your model if desired.
            }
        }
        #else
        // TODO: Implement PhotosPicker for iOS if needed.
        #endif
    }

    private func removeProfileImage() {
        #if os(macOS)
        self.profileImage = nil
        if let user = currentUser {
            user.profileImagePath = nil
            self.profileImagePathDefaults = ""
            do {
                try modelContext.save()
                print("[ProfileTabView] Saved profileImagePath removal")
            } catch {
                print("[ProfileTabView] Failed to save profileImagePath removal: \(error)")
            }
        }
        #else
        self.profileImage = nil
        // If you persist on iOS later, also clear the stored path here.
        if let user = currentUser {
            user.profileImagePath = nil
            self.profileImagePathDefaults = ""
            do {
                try modelContext.save()
                print("[ProfileTabView] Saved profileImagePath removal")
            } catch {
                print("[ProfileTabView] Failed to save profileImagePath removal: \(error)")
            }
        }
        #endif
    }

    private func loadProfileImage() {
        #if os(macOS)
        // Try SwiftData path first
        if let path = currentUser?.profileImagePath, let url = URL(string: path), let img = NSImage(contentsOf: url) {
            self.profileImage = img
            print("[ProfileTabView] Loaded profile image from SwiftData path: \(path)")
            return
        }
        // Fallback to AppStorage path
        if !self.profileImagePathDefaults.isEmpty, let url = URL(string: self.profileImagePathDefaults), let img = NSImage(contentsOf: url) {
            self.profileImage = img
            print("[ProfileTabView] Loaded profile image from AppStorage path: \(self.profileImagePathDefaults)")
            return
        }
        self.profileImage = nil
        print("[ProfileTabView] No profile image could be loaded (macOS)")
        #elseif os(iOS)
        print("[ProfileTabView] DEBUG currentUser?.profileImagePath =", currentUser?.profileImagePath ?? "nil")
        print("[ProfileTabView] DEBUG AppStorage profileImagePathDefaults =", profileImagePathDefaults.isEmpty ? "(empty)" : profileImagePathDefaults)
        // 1) Try AppStorage filename first
        if !self.profileImagePathDefaults.isEmpty, let dir = appSupportURL() {
            let url = dir.appendingPathComponent(self.profileImagePathDefaults)
            let exists = FileManager.default.fileExists(atPath: url.path)
            print("[ProfileTabView] DEBUG Trying AppStorage filename:", self.profileImagePathDefaults, "exists:", exists, "->", url.path)
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                self.profileImage = img
                print("[ProfileTabView] Loaded profile image from AppStorage filename")
                // Backfill SwiftData with filename if missing or absolute URL
                if let user = currentUser, (user.profileImagePath == nil || user.profileImagePath!.hasPrefix("file://")) {
                    user.profileImagePath = self.profileImagePathDefaults
                    do {
                        try modelContext.save()
                        print("[ProfileTabView] Backfilled SwiftData filename from AppStorage")
                    } catch {
                        print("[ProfileTabView] Failed to backfill SwiftData filename: \(error)")
                    }
                }
                return
            } else {
                print("[ProfileTabView] DEBUG AppStorage filename failed to load")
            }
        }
        // 2) Try SwiftData stored value (filename preferred, legacy absolute tolerated)
        if let stored = currentUser?.profileImagePath, !stored.isEmpty {
            if stored.hasPrefix("file://"), let legacyURL = URL(string: stored) {
                print("[ProfileTabView] DEBUG Trying legacy SwiftData absolute URL:", legacyURL.absoluteString)
                if let data = try? Data(contentsOf: legacyURL), let img = UIImage(data: data) {
                    self.profileImage = img
                    print("[ProfileTabView] Loaded profile image from legacy SwiftData URL")
                    return
                } else {
                    print("[ProfileTabView] DEBUG Legacy SwiftData URL failed to load")
                }
            } else if let dir = appSupportURL() {
                let url = dir.appendingPathComponent(stored)
                let exists = FileManager.default.fileExists(atPath: url.path)
                print("[ProfileTabView] DEBUG Trying SwiftData filename:", stored, "exists:", exists, "->", url.path)
                if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                    self.profileImage = img
                    print("[ProfileTabView] Loaded profile image from SwiftData filename")
                    return
                } else {
                    print("[ProfileTabView] DEBUG SwiftData filename failed to load")
                }
            }
        }
        self.profileImage = nil
        print("[ProfileTabView] No profile image could be loaded (iOS)")
        #endif
    }

    #if os(iOS)
    private func appSupportURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    }

    private func ensureAppSupportExists() {
        if let dir = appSupportURL() {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
    }

    private func saveUIImageToAppSupport(_ image: UIImage) -> URL? {
        ensureAppSupportExists()
        guard let dir = appSupportURL(), let data = image.pngData() else { return nil }
        let stableURL = dir.appendingPathComponent("profile.png")
        do {
            try data.write(to: stableURL, options: .atomic)
            return stableURL
        } catch {
            print("❌ Failed to save image (stable): \(error)")
            return nil
        }
    }
    #endif
}
