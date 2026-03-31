//
//  DistractionBubble.swift
//  Lystaria
//

import Foundation
import SwiftUI
import SwiftData

@Model
final class DistractionBubble {
    var id: UUID = UUID()
    var xPosition: Double = 0.5
    var yPosition: Double = 1.1
    var size: Double = 52
    var speed: Double = 0.003
    var drift: Double = 0
    var opacity: Double = 0.85
    var scale: Double = 1.0
    var isPopping: Bool = false
    var popProgress: Double = 0.0

    init(
        id: UUID = UUID(),
        xPosition: Double = 0.5,
        yPosition: Double = 1.1,
        size: Double = 52,
        speed: Double = 0.003,
        drift: Double = 0,
        opacity: Double = 0.85,
        scale: Double = 1.0,
        isPopping: Bool = false,
        popProgress: Double = 0.0
    ) {
        self.id = id
        self.xPosition = xPosition
        self.yPosition = yPosition
        self.size = size
        self.speed = speed
        self.drift = drift
        self.opacity = opacity
        self.scale = scale
        self.isPopping = isPopping
        self.popProgress = popProgress
    }

    static func random() -> DistractionBubble {
        DistractionBubble(
            xPosition: Double.random(in: 0.1...0.9),
            yPosition: Double.random(in: 1.05...1.35),
            size: Double.random(in: 28...88),
            speed: Double.random(in: 0.0018...0.0042),
            drift: Double.random(in: -0.0009...0.0009),
            opacity: Double.random(in: 0.55...0.95)
        )
    }
}
