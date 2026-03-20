//
//  JournalCardBlockPreviewSupport.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/18/26.
//

import Foundation

extension JournalEntry {
    var preferredCardPreviewText: String {
        let blockBased = blockPreviewText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !blockBased.isEmpty {
            return blockBased
        }

        let legacy = body.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(legacy.prefix(200))
    }
}
