//
//  ReadingTimerActivityAttributes.swift
//  Lystaria
//

import Foundation
import ActivityKit

struct ReadingTimerActivityAttributes: ActivityAttributes {
    
    public struct ContentState: Codable, Hashable {
        
        // MARK: - Timer Core
        var endDate: Date
        
        // MARK: - Display
        var bookTitle: String
        
        // MARK: - Optional extras (future-proofing your system)
        var minutesTotal: Int
    }
    
    // MARK: - Static Attributes (don’t change after start)
    var bookTitle: String
}
