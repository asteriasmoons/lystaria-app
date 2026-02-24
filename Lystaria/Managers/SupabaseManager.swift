//
//  SupabaseManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/6/26.
//

import Foundation
import Supabase

final class SupabaseManager {
    static let shared = SupabaseManager()

    let client: SupabaseClient
    let url: URL
    let key: String

    private init() {
        self.url = URL(string: "https://ytmjhcljifthhurwimtc.supabase.co")!
        self.key = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl0bWpoY2xqaWZ0aGh1cndpbXRjIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzI4MjA2MDksImV4cCI6MjA4ODM5NjYwOX0.4uYgR27f0OTjw-EQK8qjbhilEYMZXLoOuYi3Nep0uCA"

        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: key
        )
    }

    var auth: AuthClient {
        client.auth
    }


    var storage: SupabaseStorageClient {
        client.storage
    }
}
