import SwiftUI
import SwiftData

struct WatchJournalEntriesListView: View {

    @Query(sort: \JournalEntry.createdAt, order: .reverse)
    private var entries: [JournalEntry]

    var body: some View {
        ZStack {
            WatchLystariaBackground()

            if entries.isEmpty {
                Text("No Entries")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.8))
            } else {

                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(entries) { entry in
                            NavigationLink {
                                WatchJournalDetailView(entry: entry)
                            } label: {
                                WatchJournalEntryRow(
                                    title: entry.title,
                                    dateText: formatDate(entry.createdAt)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
        }
        .navigationTitle("Entries")
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d yyyy"
        return formatter.string(from: date)
    }
}
