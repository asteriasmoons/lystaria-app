//
//  Medication.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/24/26.
//

import Foundation
import SwiftData

@Model
final class Medication {
    
    // MARK: - Core Info
    var id: UUID = UUID()
    var name: String = ""
    var dosage: String = "" // "10mg", "2 pills", etc
    
    // MARK: - Supply Tracking
    var currentAmount: Int = 0
    var supplyAmount: Int = 0
    
    // MARK: - Refill
    var refillDate: Date? = nil
    
    // MARK: - Usage
    var timesPerDay: Int = 1
    var lastTakenAt: Date? = nil
    
    // MARK: - State
    var isActive: Bool = true
    
    // MARK: - Metadata
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    
    @Relationship(deleteRule: .cascade, inverse: \MedicationHistoryEntry.medication)
    var historyEntries: [MedicationHistoryEntry]? = []
    
    // MARK: - Init
    init(
        name: String,
        dosage: String,
        currentAmount: Int,
        supplyAmount: Int,
        refillDate: Date? = nil,
        timesPerDay: Int = 1
    ) {
        self.id = UUID()
        self.name = name
        self.dosage = dosage
        self.currentAmount = currentAmount
        self.supplyAmount = supplyAmount
        self.refillDate = refillDate
        self.timesPerDay = timesPerDay
        self.lastTakenAt = nil
        self.isActive = true
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class MedicationHistoryEntry {
    var id: UUID = UUID()
    var typeRaw: String = "taken"
    var amountText: String = ""
    var details: String = ""
    var createdAt: Date = Date()
    var medication: Medication?

    enum EntryType: String, Codable {
        case taken = "taken"
        case refilled = "refilled"
        case edited = "edited"
    }

    var type: EntryType {
        get { EntryType(rawValue: typeRaw) ?? .taken }
        set { typeRaw = newValue.rawValue }
    }

    init(
        type: EntryType,
        amountText: String,
        details: String,
        createdAt: Date = Date(),
        medication: Medication? = nil
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.amountText = amountText
        self.details = details
        self.createdAt = createdAt
        self.medication = medication
    }
}
