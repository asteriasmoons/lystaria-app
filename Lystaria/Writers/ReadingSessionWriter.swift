//
//  ReadingSessionWriter.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/31/26.
//

import Foundation
import SwiftData

@MainActor
enum ReadingSessionWriter {
    static func saveSession(
        book: Book,
        startPage: Int?,
        endPage: Int?,
        minutesRead: Int,
        sessionDate: Date,
        currentUserId: String,
        modelContext: ModelContext
    ) throws {
        let safeMinutes = max(minutesRead, 0)
        let safeStart = startPage
        let safeEnd = endPage

        let pagesRead: Int = {
            guard let start = safeStart, let end = safeEnd else { return 0 }
            return max(end - start, 0)
        }()

        let session = ReadingSession(
            book: book,
            startPage: safeStart,
            endPage: safeEnd,
            minutesRead: safeMinutes,
            pagesRead: pagesRead,   // ← ADD THIS
            sessionDate: sessionDate
        )

        modelContext.insert(session)

        if let end = safeEnd {
            book.currentPage = end

            if let total = book.totalPages, total > 0 {
                if end >= total {
                    book.currentPage = total
                    book.status = .finished
                    book.finishedAt = sessionDate
                } else {
                    if book.startedAt == nil {
                        book.startedAt = sessionDate
                    }
                    if book.status == .tbr || book.status == .paused {
                        book.status = .reading
                    }
                    book.finishedAt = nil
                }
            } else {
                if book.startedAt == nil {
                    book.startedAt = sessionDate
                }
                if book.status == .tbr || book.status == .paused {
                    book.status = .reading
                }
            }
        }

        if !currentUserId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let dayStart = Calendar.current.startOfDay(for: sessionDate)

            let progressDescriptor = FetchDescriptor<DailyReadingProgress>(
                predicate: #Predicate<DailyReadingProgress> { progress in
                    progress.userId == currentUserId &&
                    progress.date == dayStart
                }
            )

            let progressRecord: DailyReadingProgress
            if let existing = try modelContext.fetch(progressDescriptor).first {
                progressRecord = existing
            } else {
                let created = DailyReadingProgress(
                    userId: currentUserId,
                    date: dayStart,
                    pagesRead: 0,
                    minutesRead: 0
                )
                modelContext.insert(created)
                progressRecord = created
            }

            progressRecord.pagesRead += pagesRead
            progressRecord.minutesRead += safeMinutes
            progressRecord.updatedAt = Date()
        }

        let goalDescriptor = FetchDescriptor<ReadingGoal>(
            predicate: #Predicate<ReadingGoal> { goal in
                goal.userId == currentUserId && goal.isActive == true
            }
        )

        if let activeGoal = try modelContext.fetch(goalDescriptor).first {
            if sessionDate.isWithinReadingGoalPeriod(activeGoal.period) {
                switch activeGoal.metric {
                case .minutes:
                    activeGoal.progressValue += safeMinutes
                case .hours:
                    activeGoal.progressValue += safeMinutes / 60
                case .pages:
                    activeGoal.progressValue += pagesRead
                case .books:
                    if book.status == .finished {
                        activeGoal.progressValue += 1
                    }
                }
                activeGoal.updatedAt = Date()
            }
        }

        session.updatedAt = Date()
        book.updatedAt = Date()

        try modelContext.save()
    }
}

private extension Date {
    func isWithinReadingGoalPeriod(_ period: ReadingGoalPeriod) -> Bool {
        let calendar = Calendar.current
        let now = Date()

        switch period {
        case .daily:
            return calendar.isDate(self, inSameDayAs: now)

        case .weekly:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now) else { return false }
            return weekInterval.contains(self)

        case .monthly:
            let nowComponents = calendar.dateComponents([.year, .month], from: now)
            let selfComponents = calendar.dateComponents([.year, .month], from: self)
            return nowComponents.year == selfComponents.year &&
                   nowComponents.month == selfComponents.month

        case .yearly:
            let nowYear = calendar.component(.year, from: now)
            let selfYear = calendar.component(.year, from: self)
            return nowYear == selfYear
        }
    }
}
