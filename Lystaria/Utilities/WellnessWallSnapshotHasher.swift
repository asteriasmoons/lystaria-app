//
//  WellnessWallSnapshotHasher.swift
//  Lystaria
//

import Foundation
import CryptoKit

struct WellnessWallSnapshotHasher {
    static func hash(_ snapshot: WellnessWallAISnapshot) -> String {
        let encoder = JSONEncoder()

        guard let data = try? encoder.encode(snapshot) else {
            return UUID().uuidString
        }

        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
