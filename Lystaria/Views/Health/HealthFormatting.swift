//
//  HealthFormatting.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/17/26.
//

import Foundation

enum HealthFormatting {

    // MARK: - Blood Oxygen

    static func bloodOxygen(_ value: Double) -> String {
        guard value > 0 else { return "—" }
        return "\(Int(value))%"
    }

    // MARK: - Blood Pressure

    static func bloodPressure(systolic: Int, diastolic: Int) -> String {
        guard systolic > 0, diastolic > 0 else { return "—" }
        return "\(systolic)/\(diastolic)"
    }

    // MARK: - BPM

    static func bpm(_ value: Int) -> String {
        guard value > 0 else { return "—" }
        return "\(value)"
    }

    // MARK: - Temperature

    static func temperature(_ value: Double) -> String {
        guard value > 0 else { return "—" }
        return String(format: "%.1f°F", value)
    }

    // MARK: - Weight

    static func weight(_ value: Double) -> String {
        guard value > 0 else { return "—" }
        return String(format: "%.1f lb", value)
    }

    // MARK: - Exercise Name

    static func exerciseName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    // MARK: - Reps

    static func reps(_ value: Int) -> String {
        guard value > 0 else { return "—" }
        return "\(value)"
    }

    // MARK: - Duration

    static func duration(_ minutes: Int) -> String {
        guard minutes > 0 else { return "—" }
        return "\(minutes) min"
    }

    // MARK: - Date

    static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
}
