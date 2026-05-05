//
//  WellnessWallAIModels.swift
//  Lystaria
//

import Foundation

struct WellnessWallAISnapshot: Codable {
    let journal: JournalSnapshot
    let water: WaterSnapshot
    let steps: StepsSnapshot
    let habits: HabitsSnapshot

    struct JournalSnapshot: Codable {
        let entryCount: Int
        let topTags: [String]
    }

    struct WaterSnapshot: Codable {
        let currentOz: Double
        let goalOz: Double
        let progress: Double
    }

    struct StepsSnapshot: Codable {
        let currentSteps: Int
        let goalSteps: Int
        let progress: Double
    }

    struct HabitsSnapshot: Codable {
        let completedActions: Int
        let targetActions: Int
        let progress: Double
    }
}

struct WellnessWallAIResponse: Codable {
    let journal: String?
    let water: String?
    let steps: String?
    let habits: String?
}
