import SwiftUI

struct DailyIntentionCard: View {
    @AppStorage("dailyIntentionText") private var storedIntention: String = ""
    @State private var text: String = ""
    @State private var pendingSaveWorkItem: DispatchWorkItem? = nil
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        #if canImport(SwiftUI)
                        .foregroundStyle(LColors.accent)
                        #else
                        .foregroundColor(.accentColor)
                        #endif
                    Text("Daily Intention")
                        .font(.system(size: 16, weight: .bold))
                        #if canImport(SwiftUI)
                        .foregroundStyle(LColors.textPrimary)
                        #else
                        .foregroundColor(.primary)
                        #endif
                    Spacer()
                    Button(action: saveNow) {
                        Text("Save")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            #if canImport(SwiftUI)
                            .background(LColors.accent)
                            #else
                            .background(Color.accentColor)
                            #endif
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && storedIntention.isEmpty)
                }

                ZStack(alignment: .topLeading) {
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Set an intention for today…")
                            .font(.system(size: 14))
                            #if canImport(SwiftUI)
                            .foregroundStyle(LColors.textSecondary)
                            #else
                            .foregroundColor(.secondary)
                            #endif
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                    }
                    TextEditor(text: $text)
                        .scrollContentBackground(.hidden)
                        .font(.system(size: 14))
                        #if canImport(SwiftUI)
                        .foregroundStyle(LColors.textPrimary)
                        #else
                        .foregroundColor(.primary)
                        #endif
                        .frame(minHeight: 80)
                        .padding(6)
                        .background(Color.white.opacity(0.02))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onChange(of: text) { _, _ in
                            scheduleAutoSave()
                        }
                }

                HStack {
                    Spacer()
                    Text(helperFooter)
                        .font(.system(size: 11, weight: .semibold))
                        #if canImport(SwiftUI)
                        .foregroundStyle(LColors.textSecondary)
                        #else
                        .foregroundColor(.secondary)
                        #endif
                }
            }
        }
        .onAppear {
            self.text = storedIntention
        }
        .onDisappear {
            // Ensure the latest text is persisted even if autosave didn't fire yet.
            saveNow()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // If the app is backgrounded/closed before the delayed autosave runs,
            // force a write so it survives relaunch.
            if newPhase == .inactive || newPhase == .background {
                saveNow()
                pendingSaveWorkItem?.cancel()
            }
        }
    }

    private var helperFooter: String {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return "No intention set" }
        return "Saved locally"
    }

    private func scheduleAutoSave() {
        pendingSaveWorkItem?.cancel()
        let work = DispatchWorkItem { saveNow() }
        pendingSaveWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func saveNow() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        storedIntention = trimmed
        UserDefaults.standard.set(trimmed, forKey: "dailyIntentionText")
    }
}

#Preview {
    ZStack {
        LystariaBackground()
        DailyIntentionCard()
            .padding()
    }
    .preferredColorScheme(.dark)
}
