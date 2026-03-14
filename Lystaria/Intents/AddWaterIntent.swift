//
//  AddWaterIntent.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/13/26.
//

import AppIntents

// MARK: - Add 8 fl oz

struct Add8OzIntent: AppIntent {
    static var title: LocalizedStringResource = "Add 8 fl oz of Water"
    static var description = IntentDescription("Log 8 fl oz of water in Lystaria.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let waterManager = await MainActor.run { WaterHealthKitManager.shared }
        await waterManager.addWater(flOz: 8)
        return .result(dialog: IntentDialog("8 fl oz added."))
    }
}

// MARK: - Add 20 fl oz

struct Add20OzIntent: AppIntent {
    static var title: LocalizedStringResource = "Add 20 fl oz of Water"
    static var description = IntentDescription("Log 20 fl oz of water in Lystaria.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let waterManager = await MainActor.run { WaterHealthKitManager.shared }
        await waterManager.addWater(flOz: 20)
        return .result(dialog: IntentDialog("20 fl oz added."))
    }
}

// MARK: - Add Custom Amount

struct AddCustomWaterIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Custom Water Amount"
    static var description = IntentDescription("Log a custom amount of water in Lystaria.")
    static var openAppWhenRun: Bool = false

    @Parameter(
        title: "Amount (fl oz)",
        requestValueDialog: IntentDialog("How many fluid ounces would you like to add?")
    )
    var amount: Double

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$amount) fl oz of water")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard amount > 0 else {
            return .result(dialog: IntentDialog("Please enter a valid amount."))
        }
        let waterManager = await MainActor.run { WaterHealthKitManager.shared }
        await waterManager.addWater(flOz: amount)
        return .result(dialog: IntentDialog("\(Int(amount)) fl oz added."))
    }
}
