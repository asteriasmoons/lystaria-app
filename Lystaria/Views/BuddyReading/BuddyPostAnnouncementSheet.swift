//
//  BuddyPostAnnouncementSheet.swift
//  Lystaria
//

import SwiftUI
import SwiftData

struct BuddyPostAnnouncementSheet: View {
    let userId: String
    let displayName: String
    var onClose: (() -> Void)?
    var onPost: ((BuddyAnnouncement) -> Void)?

    @Query(sort: \Book.updatedAt, order: .reverse) private var books: [Book]

    @State private var bookTitle: String = ""
    @State private var bookAuthor: String = ""
    @State private var message: String = ""
    @State private var maxMembers: Int = 2
    @State private var currentChapterText: String = ""
    @State private var isPosting = false
    @State private var errorMessage: String? = nil

    private var readingBooks: [Book] {
        books.filter { $0.status == .reading && $0.deletedAt == nil }
    }

    private var trimmedTitle: String {
        bookTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canPost: Bool { !trimmedTitle.isEmpty && !isPosting }

    private var closeAction: () -> Void { onClose ?? {} }

    var body: some View {
        LystariaOverlayPopup(
            onClose: { closeAction() },
            width: 640,
            heightRatio: 0.72,
            header: {
                HStack {
                    GradientTitle(text: "Post Announcement", font: .title2.bold())
                    Spacer()
                    Button { closeAction() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(LColors.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            },
            content: {
                // Quick-fill from currently reading books
                if !readingBooks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CURRENTLY READING")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LColors.textSecondary)
                            .tracking(0.5)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(readingBooks) { book in
                                    Button {
                                        bookTitle = book.title
                                        bookAuthor = book.author
                                        if let chapter = book.currentPage {
                                            currentChapterText = "\(chapter)"
                                        }
                                    } label: {
                                        Text(book.title)
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(LColors.textPrimary)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .background(Color.white.opacity(0.08))
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(LColors.glassBorder, lineWidth: 1))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("BOOK TITLE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)
                    LystariaTextField(placeholder: "Book title", text: $bookTitle)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("AUTHOR")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)
                    LystariaTextField(placeholder: "Author (optional)", text: $bookAuthor)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("CURRENT CHAPTER / PAGE")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)
                    LystariaNumberField(placeholder: "e.g. 5", text: $currentChapterText)
                        .numericKeyboardIfAvailable()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("MAX BUDDIES")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)

                    HStack(spacing: 10) {
                        ForEach(2...4, id: \.self) { count in
                            Button {
                                maxMembers = count
                            } label: {
                                Text("\(count)")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(maxMembers == count ? .white : LColors.textPrimary)
                                    .frame(width: 44, height: 44)
                                    .background(maxMembers == count ? LColors.accent : Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(maxMembers == count ? LColors.accent : LColors.glassBorder, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("NOTE (OPTIONAL)")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LColors.textSecondary)
                        .tracking(0.5)
                    LystariaTextArea(placeholder: "e.g. Looking to discuss themes and theories!", text: $message)
                }

                if let error = errorMessage {
                    Text(error)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.85))
                }
            },
            footer: {
                Button { Task { await post() } } label: {
                    Group {
                        if isPosting {
                            ProgressView().tint(.white)
                        } else {
                            Text("Post to Board")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canPost ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.gray.opacity(0.3)))
                    .clipShape(RoundedRectangle(cornerRadius: LSpacing.buttonRadius))
                    .shadow(color: canPost ? LColors.accent.opacity(0.3) : .clear, radius: 12, y: 6)
                }
                .buttonStyle(.plain)
                .disabled(!canPost)
            }
        )
    }

    private func post() async {
        guard canPost else { return }
        isPosting = true
        errorMessage = nil

        let chapter = Int(currentChapterText.filter(\.isNumber))

        let body = PostAnnouncementBody(
            ownerUserId: userId,
            ownerDisplayName: displayName,
            bookTitle: trimmedTitle,
            bookAuthor: bookAuthor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : bookAuthor,
            bookCoverUrl: nil,
            bookKey: nil,
            message: message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : message,
            currentChapter: chapter,
            currentPage: nil,
            maxMembers: maxMembers
        )

        do {
            let announcement = try await BuddyService.shared.postAnnouncement(body: body)
            onPost?(announcement)
        } catch {
            errorMessage = "Failed to post. Please try again."
        }

        isPosting = false
    }
}
