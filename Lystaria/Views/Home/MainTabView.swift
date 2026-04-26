// MainTabView.swift
// Lystaria

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @Binding var selectedTab: Tab
    @State private var showSignIn = false

    enum Tab: String, CaseIterable {
        case reminders = "Reminders"
        case calendar  = "Calendar"
        case journal   = "Journal"
        case reading   = "Reading"
        case profile   = "Profile"
        case info      = "Info"
        case dashboard = "Dashboard"

        var icon: String {
            switch self {
            case .reminders: return "bellfill"
            case .calendar:  return "calfill"
            case .journal:   return "notesfill"
            case .reading:   return "bookstack"
            case .profile:   return "userwavy"
            case .info:       return "infofill"
            case .dashboard: return "homeline"
            }
        }
    }

    var body: some View {
        ZStack {
            LystariaBackground().ignoresSafeArea()

            Group {
                switch selectedTab {
                case .reminders: RemindersView()
                case .calendar:  CalendarTabView()
                case .journal:   JournalTabView()
                case .reading:   ReadingTabView()
                case .profile:   ProfileTabView()
                case .info:      InfoTabView()
                case .dashboard: DashboardView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // This makes the nav “real” UI chrome instead of a layered overlay that can vanish.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomNav
                .zIndex(9999)
                .opacity(appState.isPopupPresented ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: appState.isPopupPresented)
        }
        .sheet(isPresented: $showSignIn) {
            SignInView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Bottom Nav

    private var bottomNav: some View {
        // Centered floating “cosmic liquid glass” capsule nav (DO NOT stretch edge-to-edge)
        HStack {
            Spacer(minLength: 0)

            HStack(spacing: 24) {
                ForEach(Tab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                    } label: {
                        Image(tab.icon)
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                            .foregroundStyle(.white)
                            .padding(.vertical, 12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .background(
                Capsule(style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        // Deep cosmic tint to keep readability on bright backgrounds
                        Capsule(style: .continuous)
                            .fill(Color(red: 18/255, green: 18/255, blue: 26/255).opacity(0.55))
                    )
                    .overlay(
                        // Soft “liquid” highlight wash
                        Capsule(style: .continuous)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.white.opacity(0.22), location: 0.0),
                                        .init(color: Color.white.opacity(0.06), location: 0.35),
                                        .init(color: Color.white.opacity(0.02), location: 1.0)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .blendMode(.screen)
                    )
                    .overlay(
                        // Cosmic glass rim
                        Capsule(style: .continuous)
                            .stroke(
                                LinearGradient(
                                    gradient: Gradient(stops: [
                                        .init(color: Color.white.opacity(0.25), location: 0.0),
                                        .init(color: LColors.accent.opacity(0.35), location: 0.55),
                                        .init(color: Color.white.opacity(0.18), location: 1.0)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
            )
            .clipShape(Capsule(style: .continuous))
            // Force the capsule to size to its contents (prevents any implicit stretching)
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: 0)
        }
        .padding(.bottom, 14)
    }
}

#Preview {
    MainTabView(selectedTab: .constant(.dashboard)).preferredColorScheme(.dark)
}
