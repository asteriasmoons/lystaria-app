//
//  CheckInReadingIntent.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/14/26.
//

import AppIntents
import SwiftData

struct CheckInReadingIntent: AppIntent {
    static var title: LocalizedStringResource = "Reading Check-In"
    static var description = IntentDescription("Check in for today for your reading streak in Lystaria.")

    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let didCheckIn = try await MainActor.run {
            let context = ModelContext(LystariaApp.sharedModelContainer)

            // Fetch the signed-in user so we can use the same userId used elsewhere
            let descriptor = FetchDescriptor<AuthUser>()
            let users = try context.fetch(descriptor)

            guard let userId = users.first?.appleUserId else {
                throw NSError(domain: "ReadingCheckIn", code: 1, userInfo: [NSLocalizedDescriptionKey: "No signed-in user available."])
            }

            return try ReadingCheckInWriter.checkInToday(
                modelContext: context,
                userId: userId
            )
        }

        if didCheckIn {
            return .result(dialog: IntentDialog("Reading checked in for today."))
        } else {
            return .result(dialog: IntentDialog("You already checked in today."))
        }
    }
}
