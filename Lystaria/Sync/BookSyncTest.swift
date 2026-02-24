//
//  BookSyncTest.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/6/26.
//

import Foundation
import Supabase
import Auth

struct InsertBookRow: Encodable {
    let user_id: UUID
    let title: String
    let author: String?
    let status: String?
    let current_page: Int?
    let total_pages: Int?
    let summary: String?
    let rating: Int?
}

enum BookSyncTest {
    static func insertTestBook() async throws {
        let session = try await SupabaseManager.shared.client.auth.session
        let userID = session.user.id

        let row = InsertBookRow(
            user_id: userID,
            title: "Supabase Test Book",
            author: "Asteria",
            status: "reading",
            current_page: 10,
            total_pages: 100,
            summary: "First sync test",
            rating: 5
        )

        try await SupabaseManager.shared.client
            .from("books")
            .insert(row)
            .execute()
    }
}
