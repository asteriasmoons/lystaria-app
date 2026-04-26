//
// ProfileTabView.swift
//
// Created By Asteria Moon
//

import SwiftUI
import SwiftData
import PhotosUI
#if os(macOS)
import AppKit
import UniformTypeIdentifiers
#endif

struct ProfileTabView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appState: AppState
    @Query private var authUsers: [AuthUser]
    @Query private var userSettings: [UserSettings]

    // MARK: - Profile state

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
    @State private var timezoneSearch: String = ""
    @AppStorage("isAdminMode") private var isAdminMode: Bool = false
    @AppStorage("isPremiumDevBypass") private var isPremiumDevBypass: Bool = false
    @AppStorage("settings.showOnboardingNextLaunch") private var showOnboardingNextLaunch: Bool = false
    @AppStorage("hasSeenWelcome") private var hasSeenWelcome: Bool = true

    // MARK: - Computed

    private let allTimezones: [String] = TimeZone.knownTimeZoneIdentifiers.sorted()
    private var currentUser: AuthUser? { authUsers.first }
    private var isAdminUser: Bool {
        currentUser?.appleUserId == "001664.f2fefbb84f024544b98e865fa6c6b49e.1524"
    }
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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()

                ScrollView {
                    mainContent
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarHidden(true)
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 14) {
            headerSection
            profileSection
            actionsSection
            watchComplicationSection
            onboardingSection
            Spacer(minLength: 80)
        }
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, LSpacing.pageHorizontal)
        .padding(.vertical, 20)
        .onAppear {
            if let s = settings {
                self.useSystemTimezone = s.useSystemTimezone
                self.selectedTimezoneIdentifier = s.timezoneIdentifier
            } else {
                _ = ensureSettings()
            }
            let defaults = UserDefaults.standard
            defaults.set(self.useSystemTimezone, forKey: "lystaria.useSystemTimezone")
            defaults.set(self.selectedTimezoneIdentifier, forKey: "lystaria.timezoneIdentifier")
            loadProfileImage()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                if self.profileImage == nil { loadProfileImage() }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
                if self.profileImage == nil { loadProfileImage() }
            }
        }
        .onChange(of: currentUser?.profileImagePath) { loadProfileImage() }
        .onChange(of: profileImagePathDefaults) { loadProfileImage() }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                GradientTitle(text: "Profile & Settings", font: .system(size: 28, weight: .bold))
                Spacer()
            }
            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)
                .padding(.top, 6)
        }
    }

    private var profileSection: some View {
        VStack(spacing: 12) {
            avatarSection
            photoButtonsSection
            infoCardSection
            timezoneCardSection
        }
    }

    @ViewBuilder
    private var avatarSection: some View {
        ZStack {
            if let img = profileImage {
                #if os(macOS)
                Image(nsImage: img).resizable().scaledToFill()
                #else
                Image(uiImage: img).resizable().scaledToFill()
                #endif
            } else {
                if let path = currentUser?.profileImagePath, let url = URL(string: path) {
                    #if os(macOS)
                    if let img = NSImage(contentsOf: url) {
                        Image(nsImage: img).resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle").resizable().scaledToFit()
                            .foregroundStyle(LColors.textSecondary).padding(14)
                    }
                    #else
                    if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                        Image(uiImage: img).resizable().scaledToFill()
                    } else {
                        Image(systemName: "person.crop.circle").resizable().scaledToFit()
                            .foregroundStyle(LColors.textSecondary).padding(14)
                    }
                    #endif
                } else {
                    Image(systemName: "person.crop.circle").resizable().scaledToFit()
                        .foregroundStyle(LColors.textSecondary).padding(14)
                }
            }
        }
        .frame(width: 96, height: 96)
        .background(Color.white.opacity(0.08))
        .clipShape(Circle())
        .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
    }

    @ViewBuilder
    private var photoButtonsSection: some View {
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
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    self.profileImage = uiImage
                    if saveUIImageToAppSupport(uiImage) != nil {
                        self.profileImagePathDefaults = "profile.png"
                        if let user = currentUser {
                            user.profileImagePath = "profile.png"
                            try? modelContext.save()
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
    }

    private var infoCardSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                if let user = currentUser {
                    if let name = user.displayName, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        labeledRow(label: "Name", value: name)
                    } else {
                        Text("Signed in")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                    }
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
    }

    private var timezoneCardSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Timezone")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)

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
                .padding(.horizontal, 12).padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(LColors.glassBorder, lineWidth: 1))

                if !useSystemTimezone {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SELECT TIMEZONE")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        #if os(iOS)
                        TextField("Search timezones", text: $timezoneSearch)
                            .textFieldStyle(.plain)
                            .foregroundStyle(LColors.textPrimary)
                            .padding(8)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(LColors.glassBorder, lineWidth: 1))
                        #endif

                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(filteredTimezones, id: \.self) { tz in
                                    let on = tz == selectedTimezoneIdentifier
                                    Button(action: {
                                        selectedTimezoneIdentifier = tz
                                        saveTimezoneSettings()
                                    }) {
                                        HStack {
                                            Text(tz).font(.system(size: 13)).foregroundStyle(LColors.textPrimary)
                                            Spacer()
                                            if on { Image(systemName: "checkmark").foregroundStyle(LColors.accent) }
                                        }
                                        .padding(.horizontal, 8).padding(.vertical, 6)
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

                HStack(spacing: 8) {
                    Image(systemName: "globe").font(.caption).foregroundStyle(LColors.textSecondary)
                    Text(effectiveTimezoneLabel).font(.subheadline).foregroundStyle(LColors.textSecondary)
                }
            }
            .padding(.horizontal, 2).padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private var actionsSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Actions")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LColors.textSecondary)

                if isAdminUser {
                    Toggle(isOn: $isAdminMode) {
                        HStack(spacing: 10) {
                            Image("shieldstar").renderingMode(.template).resizable()
                                .scaledToFit().frame(width: 18, height: 18).foregroundStyle(.white)
                            Text("Admin Mode").font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(LColors.textPrimary)
                    }
                    .tint(LColors.accent).padding(.horizontal, 14).frame(minHeight: 56)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))

                    Toggle(isOn: $isPremiumDevBypass) {
                        HStack(spacing: 10) {
                            Image(systemName: "crown.fill").font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                            Text("Premium Dev Bypass").font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(LColors.textPrimary)
                    }
                    .tint(LColors.accent).padding(.horizontal, 14).frame(minHeight: 56)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(LColors.glassBorder, lineWidth: 1))
                }

                Button(action: { signOut() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out").font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(minHeight: 56)
                    .background(LinearGradient(
                        colors: [Color(red: 0.86, green: 0.12, blue: 0.74), Color(red: 1.0, green: 0.20, blue: 0.78)],
                        startPoint: .leading, endPoint: .trailing
                    ))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
                .disabled(currentUser == nil)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 2).padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity)
    }

    private var watchComplicationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Watch Complication", icon: "applewatch")

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(Circle().stroke(LColors.glassBorder, lineWidth: 1))
                                .frame(width: 40, height: 40)
                            Image("sparklefill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Lystaria Complication")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(LColors.textPrimary)
                            Text("Flow state, steps, and water on your watch face.")
                                .font(.caption)
                                .foregroundStyle(LColors.textSecondary)
                        }
                    }

                    Divider().background(LColors.glassBorder)

                    VStack(alignment: .leading, spacing: 10) {
                        watchStep(number: 1, text: "Open the Watch app on your iPhone.")
                        watchStep(number: 2, text: "Tap \"My Watch\" → \"Face Gallery\" and choose a face, or long-press your current face on your watch and tap \"Edit\".")
                        watchStep(number: 3, text: "Tap any rectangular complication slot.")
                        watchStep(number: 4, text: "Scroll down and select \"Lystaria\".")
                    }

                    Button {
                        if let url = URL(string: "itms-watchface://") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "applewatch")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Open Watch App")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(LGradients.blue)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Text("The Lystaria complication works on Modular, Modular Duo, Infograph Modular, and Smart Stack watch faces — any face that has a rectangular slot.")
                        .font(.caption)
                        .foregroundStyle(LColors.textSecondary)
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
        }
    }

    private func watchStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            ZStack {
                Circle()
                    .fill(LGradients.blue)
                    .frame(width: 20, height: 20)
                Text("\(number)")
                    .font(.system(size: 10, weight: .black))
                    .foregroundStyle(.white)
            }
            .padding(.top, 1)

            Text(text)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(LColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var onboardingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "App Guides", icon: "sparkles")

            GlassCard {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Run Feature Tour Again")
                                .font(.subheadline).fontWeight(.medium).foregroundStyle(LColors.textPrimary)
                            Text("Show icon explanations again the next time you open each page.")
                                .font(.caption).foregroundStyle(LColors.textSecondary)
                        }
                        Spacer()
                        Toggle("", isOn: $showOnboardingNextLaunch).labelsHidden().tint(LColors.accent)
                    }

                    Divider().background(LColors.glassBorder)

                    HStack {
                        Spacer()
                        LButton(title: "View Welcome Screens", icon: "sparkles", style: .gradient) {
                            hasSeenWelcome = false
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func labeledRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold)).foregroundStyle(LColors.textSecondary).tracking(0.5)
            Text(value).font(.system(size: 14)).foregroundStyle(LColors.textPrimary)
        }
    }

    private func signOut() {
        appState.signOut()
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
                    try? modelContext.save()
                }
            }
        }
        #endif
    }

    private func removeProfileImage() {
        self.profileImage = nil
        if let user = currentUser {
            user.profileImagePath = nil
            self.profileImagePathDefaults = ""
            try? modelContext.save()
        }
    }

    private func loadProfileImage() {
        #if os(macOS)
        if let path = currentUser?.profileImagePath, let url = URL(string: path), let img = NSImage(contentsOf: url) {
            self.profileImage = img; return
        }
        if !self.profileImagePathDefaults.isEmpty, let url = URL(string: self.profileImagePathDefaults), let img = NSImage(contentsOf: url) {
            self.profileImage = img; return
        }
        self.profileImage = nil
        #elseif os(iOS)
        if !self.profileImagePathDefaults.isEmpty, let dir = appSupportURL() {
            let url = dir.appendingPathComponent(self.profileImagePathDefaults)
            if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                self.profileImage = img
                if let user = currentUser, (user.profileImagePath == nil || user.profileImagePath!.hasPrefix("file://")) {
                    user.profileImagePath = self.profileImagePathDefaults
                    try? modelContext.save()
                }
                return
            }
        }
        if let stored = currentUser?.profileImagePath, !stored.isEmpty {
            if stored.hasPrefix("file://"), let legacyURL = URL(string: stored),
               let data = try? Data(contentsOf: legacyURL), let img = UIImage(data: data) {
                self.profileImage = img; return
            } else if let dir = appSupportURL() {
                let url = dir.appendingPathComponent(stored)
                if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                    self.profileImage = img; return
                }
            }
        }
        self.profileImage = nil
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
            print("❌ Failed to save image: \(error)")
            return nil
        }
    }
    #endif
}
