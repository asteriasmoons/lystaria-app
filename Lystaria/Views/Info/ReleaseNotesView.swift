//  Created by Asteria Moon on 5/3/26.

import SwiftUI
import SwiftData

struct ReleaseNotesView: View {
    @Environment(\.dismiss) private var dismiss

    @Query private var notes: [ReleaseNote]

    private var sortedNotes: [ReleaseNote] {
        var seenIDs = Set<String>()

        return notes
            .filter { $0.isPublished }
            .sorted { lhs, rhs in
                if lhs.sortOrder == rhs.sortOrder {
                    return lhs.createdAt > rhs.createdAt
                }

                return lhs.sortOrder > rhs.sortOrder
            }
            .filter { note in
                guard seenIDs.contains(note.id) == false else { return false }
                seenIDs.insert(note.id)
                return true
            }
    }

    var body: some View {
        ZStack {
            LystariaBackground()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header

                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(sortedNotes) { note in
                            ReleaseNoteCard(
                                note: note,
                                isNewest: note.id == sortedNotes.first?.id
                            )
                        }
                    }
                    .padding(.horizontal, LSpacing.pageHorizontal)
                    .padding(.top, 18)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            HStack {
                GradientTitle(text: "Release Notes", size: 28)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image("checkfill")
                        .renderingMode(.template)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .foregroundStyle(.white)
                        .foregroundColor(.white)
                        .frame(width: 38, height: 38)
                        .background(
                            Circle()
                                .fill(.white.opacity(0.10))
                                .overlay(
                                    Circle()
                                        .stroke(LColors.glassBorder, lineWidth: 1)
                                )
                        )
                }
                .buttonStyle(.plain)
            }

            Rectangle()
                .fill(LColors.glassBorder)
                .frame(height: 1)
        }
        .padding(.horizontal, LSpacing.pageHorizontal)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }
}

// MARK: - Release Note Card

private struct ReleaseNoteCard: View {
    let note: ReleaseNote
    let isNewest: Bool

    @State private var isExpanded: Bool

    init(note: ReleaseNote, isNewest: Bool) {
        self.note = note
        self.isNewest = isNewest
        _isExpanded = State(initialValue: isNewest)
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    guard !isNewest else { return }

                    withAnimation(.easeInOut(duration: 0.22)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image("starnote")
                            .renderingMode(.template)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 18, height: 18)
                            .foregroundStyle(.white)
                            .foregroundColor(.white)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(note.version.uppercased())
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(LColors.textPrimary)
                                .tracking(1.1)

                            Text(note.dateText.uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(LColors.textSecondary)
                                .tracking(0.8)
                        }

                        Spacer()

                        if isNewest {
                            Text("NEWEST")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(LColors.accent)
                                .tracking(1)
                        } else {
                            Image(isExpanded ? "chevronupfill" : "chevrondownfill")
                                .renderingMode(.template)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                                .foregroundStyle(.white)
                                .foregroundColor(.white)
                        }
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    Rectangle()
                        .fill(LColors.glassBorder)
                        .frame(height: 1)

                    VStack(alignment: .leading, spacing: 10) {
                        Text(note.title.uppercased())
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(LColors.textPrimary)
                            .tracking(1)

                        ForEach(note.items, id: \.self) { item in
                            ReleaseNoteBullet(text: item)
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

// MARK: - Release Note Bullet

private struct ReleaseNoteBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Circle()
                .fill(LGradients.blue)
                .frame(width: 7, height: 7)
                .padding(.top, 6)

            Text(text.uppercased())
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LColors.textSecondary)
                .lineSpacing(4)
                .tracking(0.6)
        }
    }
}

#Preview {
    ReleaseNotesView()
        .modelContainer(for: ReleaseNote.self, inMemory: true)
        .preferredColorScheme(.dark)
}
