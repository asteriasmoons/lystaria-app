//
//  DocumentInlinePropertyViewSheet.swift
//  Lystaria
//
//  Created by Asteria Moon on 5/8/26.
//

import SwiftUI

struct DocumentInlinePropertyViewSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var property: DocumentInlineProperty

    @State private var textValue: String
    @State private var numberValue: String
    @State private var urlValue: String
    @State private var booleanValue: Bool
    @State private var checkboxValue: Bool
    @State private var dateValue: Date
    @State private var selectedOption: String
    @State private var selectedOptions: Set<String>
    @State private var isEditingPropertyDefinition = false
    @State private var editedPropertyName: String
    @State private var editedOptions: [DocumentPropertyOptionDraft]

    init(property: DocumentInlineProperty) {
        self.property = property

        let type = property.type

        _textValue = State(initialValue: type == .text ? property.valueStorage : "")
        _numberValue = State(initialValue: type == .number ? property.valueStorage : "")
        _urlValue = State(initialValue: type == .url ? property.valueStorage : "")
        _booleanValue = State(initialValue: property.valueStorage == "true")
        _checkboxValue = State(initialValue: property.valueStorage == "true")
        _dateValue = State(initialValue: Self.decodeDate(property.valueStorage) ?? Date())
        _selectedOption = State(initialValue: type == .select ? property.valueStorage : "")
        _selectedOptions = State(initialValue: Set(Self.decodeStringArray(property.valueStorage)))
        _editedPropertyName = State(initialValue: property.name)
        _editedOptions = State(initialValue: Self.decodePropertyOptions(property.optionsStorage))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerSection
                        if isEditingPropertyDefinition {
                            editDefinitionSection
                        } else {
                            valueSection
                            optionsSectionIfNeeded
                        }
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.75))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(isEditingPropertyDefinition ? "Done" : "Save") {
                        if isEditingPropertyDefinition {
                            savePropertyDefinitionEdits()
                            isEditingPropertyDefinition = false
                        } else {
                            saveValue()
                            dismiss()
                        }
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private var headerSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text(property.name.isEmpty ? property.type.rawValue : property.name)
                    .font(.custom("Lily Script One", size: 30))
                    .foregroundStyle(LGradients.blue)

                HStack(spacing: 8) {
                    Text(property.type.rawValue)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white.opacity(0.78))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.08))
                        .clipShape(Capsule())

                    if !property.colorHex.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Circle()
                            .fill(Color(hex: property.colorHex) ?? LColors.accent)
                            .frame(width: 18, height: 18)
                            .overlay(Circle().stroke(.white.opacity(0.24), lineWidth: 1))
                    }
                }

                Text(isEditingPropertyDefinition ? "Edit the property name and available options." : "Edit this inline property value.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.68))

                Button {
                    isEditingPropertyDefinition.toggle()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: isEditingPropertyDefinition ? "slider.horizontal.3" : "pencil")
                        Text(isEditingPropertyDefinition ? "Edit Value" : "Edit Property")
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.10))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var editDefinitionSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Property Name")
                        .font(.headline)
                        .foregroundStyle(.white)

                    TextField("Property name", text: $editedPropertyName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
            }

            if property.type == .select || property.type == .multiSelect {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Options")
                                .font(.headline)
                                .foregroundStyle(.white)

                            Spacer()

                            Button {
                                editedOptions.append(DocumentPropertyOptionDraft(name: "", colorHex: "#6055F7"))
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(LColors.accent)
                            }
                        }

                        if editedOptions.isEmpty {
                            Text("Add options for this property.")
                                .font(.callout)
                                .foregroundStyle(.white.opacity(0.65))
                        } else {
                            ForEach(editedOptions.indices, id: \.self) { index in
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 10) {
                                        TextField("Option name", text: bindingForEditedOptionName(at: index))
                                            .textFieldStyle(.plain)
                                            .padding(12)
                                            .background(.white.opacity(0.08))
                                            .clipShape(RoundedRectangle(cornerRadius: 14))
                                            .foregroundStyle(.white)

                                        Button {
                                            removeEditedOption(at: index)
                                        } label: {
                                            Image(systemName: "trash.fill")
                                                .foregroundStyle(.red.opacity(0.85))
                                        }
                                    }

                                    ColorPicker("Option Color", selection: bindingForEditedOptionColor(at: index), supportsOpacity: false)
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.76))
                                        .tint(LColors.accent)
                                }
                                .padding(10)
                                .background(.white.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                }
            }
        }
    }
    private func bindingForEditedOptionName(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard editedOptions.indices.contains(index) else { return "" }
                return editedOptions[index].name
            },
            set: { newValue in
                guard editedOptions.indices.contains(index) else { return }
                editedOptions[index].name = newValue
            }
        )
    }

    private func bindingForEditedOptionColor(at index: Int) -> Binding<Color> {
        Binding(
            get: {
                guard editedOptions.indices.contains(index) else { return LColors.accent }
                return Color(hex: editedOptions[index].colorHex) ?? LColors.accent
            },
            set: { newValue in
                guard editedOptions.indices.contains(index) else { return }
                editedOptions[index].colorHex = Self.hexString(from: newValue)
            }
        )
    }

    private func removeEditedOption(at index: Int) {
        guard editedOptions.indices.contains(index) else { return }

        let removedName = editedOptions[index].name
        editedOptions.remove(at: index)
        selectedOptions.remove(removedName)

        if selectedOption == removedName {
            selectedOption = ""
            property.valueStorage = ""
            property.colorHex = ""
        }
    }

    private func savePropertyDefinitionEdits() {
        let oldName = property.name
        let cleanedName = editedPropertyName.trimmingCharacters(in: .whitespacesAndNewlines)
        property.name = cleanedName

        if property.type == .select || property.type == .multiSelect {
            let cleanedOptions = editedOptions
                .map {
                    DocumentPropertyOptionDraft(
                        id: $0.id,
                        name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                        colorHex: $0.colorHex
                    )
                }
                .filter { !$0.name.isEmpty }

            property.optionsStorage = Self.encodePropertyOptions(cleanedOptions)
            editedOptions = cleanedOptions

            if property.type == .select {
                if let selected = cleanedOptions.first(where: { $0.name == property.valueStorage }) {
                    property.colorHex = selected.colorHex
                } else if !property.valueStorage.isEmpty {
                    property.valueStorage = ""
                    selectedOption = ""
                    property.colorHex = ""
                }
            }

            if property.type == .multiSelect {
                let validNames = Set(cleanedOptions.map(\.name))
                let filteredSelected = selectedOptions.filter { validNames.contains($0) }
                selectedOptions = filteredSelected
                property.valueStorage = Self.encodeStringArray(Array(filteredSelected))
                property.colorHex = cleanedOptions.first(where: { filteredSelected.contains($0.name) })?.colorHex ?? ""
            }
        }

        syncPropertyTextIntoBlock(previousName: oldName)
        property.touch()
    }

    @ViewBuilder
    private var valueSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Value")
                    .font(.headline)
                    .foregroundStyle(.white)

                switch property.type {
                case .boolean:
                    Toggle("Enabled", isOn: $booleanValue)
                        .tint(LColors.accent)

                case .checkbox:
                    Toggle("Checked", isOn: $checkboxValue)
                        .tint(LColors.accent)

                case .text:
                    TextField("Enter text...", text: $textValue)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)

                case .number:
                    TextField("Enter number...", text: $numberValue)
                        .keyboardType(.decimalPad)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)

                case .date:
                    DatePicker("Date", selection: $dateValue, displayedComponents: [.date])
                        .datePickerStyle(.compact)
                        .tint(LColors.accent)

                case .url:
                    TextField("https://example.com", text: $urlValue)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)

                case .select:
                    selectValuePicker

                case .multiSelect:
                    multiSelectValuePicker
                }
            }
        }
    }

    @ViewBuilder
    private var optionsSectionIfNeeded: some View {
        if property.type == .select || property.type == .multiSelect {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Available Options")
                        .font(.headline)
                        .foregroundStyle(.white)

                    if decodedOptions.isEmpty {
                        Text("No options have been defined for this property yet.")
                            .font(.callout)
                            .foregroundStyle(.white.opacity(0.65))
                    } else {
                        ForEach(decodedOptions) { option in
                            optionPreviewRow(option)
                        }
                    }
                }
            }
        }
    }

    private var selectValuePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if decodedOptions.isEmpty {
                Text("No options available.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                ForEach(decodedOptions) { option in
                    Button {
                        selectedOption = option.name
                        property.colorHex = option.colorHex
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: option.colorHex) ?? LColors.accent)
                                .frame(width: 12, height: 12)

                            Text(option.name)
                                .font(.callout)
                                .foregroundStyle(.white)

                            Spacer()

                            if selectedOption == option.name {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(LColors.accent)
                            }
                        }
                        .padding(12)
                        .background(.white.opacity(selectedOption == option.name ? 0.14 : 0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var multiSelectValuePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if decodedOptions.isEmpty {
                Text("No options available.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                ForEach(decodedOptions) { option in
                    Button {
                        if selectedOptions.contains(option.name) {
                            selectedOptions.remove(option.name)
                        } else {
                            selectedOptions.insert(option.name)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: option.colorHex) ?? LColors.accent)
                                .frame(width: 12, height: 12)

                            Text(option.name)
                                .font(.callout)
                                .foregroundStyle(.white)

                            Spacer()

                            if selectedOptions.contains(option.name) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(LColors.accent)
                            }
                        }
                        .padding(12)
                        .background(.white.opacity(selectedOptions.contains(option.name) ? 0.14 : 0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func optionPreviewRow(_ option: DocumentPropertyOptionDraft) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(hex: option.colorHex) ?? LColors.accent)
                .frame(width: 12, height: 12)

            Text(option.name)
                .font(.callout)
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(12)
        .background(.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var decodedOptions: [DocumentPropertyOptionDraft] {
        Self.decodePropertyOptions(property.optionsStorage)
    }

    private func saveValue() {
        switch property.type {
        case .boolean:
            property.valueStorage = booleanValue ? "true" : "false"

        case .checkbox:
            property.valueStorage = checkboxValue ? "true" : "false"

        case .text:
            property.valueStorage = textValue

        case .number:
            property.valueStorage = numberValue

        case .date:
            property.valueStorage = Self.encodeDate(dateValue)

        case .url:
            property.valueStorage = urlValue

        case .select:
            property.valueStorage = selectedOption
            if let selected = decodedOptions.first(where: { $0.name == selectedOption }) {
                property.colorHex = selected.colorHex
            }

        case .multiSelect:
            let selected = decodedOptions.filter { selectedOptions.contains($0.name) }
            property.valueStorage = Self.encodeStringArray(selected.map(\.name))
            property.colorHex = selected.first?.colorHex ?? ""
        }

        syncPropertyTextIntoBlock()
        property.touch()
    }

    private func syncPropertyTextIntoBlock(previousName: String? = nil) {
        guard let block = property.block else { return }

        let currentText = block.text as NSString
        let textLength = currentText.length
        guard textLength > 0 else {
            let replacement = displayTextForCurrentPropertyValue(previousName: previousName)
            block.text = replacement
            property.rangeLocation = 0
            property.rangeLength = (replacement as NSString).length
            block.touch()
            return
        }

        let start = max(0, min(property.rangeLocation, textLength))
        let length = max(0, min(property.rangeLength, textLength - start))
        let replacement = displayTextForCurrentPropertyValue(previousName: previousName)
        let updatedText = currentText.replacingCharacters(in: NSRange(location: start, length: length), with: replacement)
        let delta = (replacement as NSString).length - length

        block.text = updatedText
        property.rangeLocation = start
        property.rangeLength = (replacement as NSString).length

        if let inlineProperties = block.inlineProperties {
            for inlineProperty in inlineProperties where inlineProperty.id != property.id && inlineProperty.rangeLocation > start {
                inlineProperty.rangeLocation = max(0, inlineProperty.rangeLocation + delta)
                inlineProperty.touch()
            }
        }

        block.touch()
    }

    private func displayTextForCurrentPropertyValue(previousName: String? = nil) -> String {
        let trimmedName = property.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = trimmedName.isEmpty ? property.type.rawValue : trimmedName
        let value = displayValueForCurrentPropertyValue()
        return value.isEmpty ? name : "\(name): \(value)"
    }

    private func displayValueForCurrentPropertyValue() -> String {
        switch property.type {
        case .boolean:
            return property.valueStorage == "true" ? "True" : "False"
        case .checkbox:
            return property.valueStorage == "true" ? "Checked" : "Unchecked"
        case .text, .number, .url, .select:
            return property.valueStorage.trimmingCharacters(in: .whitespacesAndNewlines)
        case .date:
            guard let date = Self.decodeDate(property.valueStorage) else { return "" }
            return date.formatted(date: .abbreviated, time: .omitted)
        case .multiSelect:
            return Self.decodeStringArray(property.valueStorage).joined(separator: ", ")
        }
    }

    private static func encodeStringArray(_ values: [String]) -> String {
        guard let data = try? JSONEncoder().encode(values),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return string
    }

    private static func decodeStringArray(_ storage: String) -> [String] {
        guard let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        return decoded
    }

    private static func encodeDate(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func decodeDate(_ storage: String) -> Date? {
        ISO8601DateFormatter().date(from: storage)
    }

    private static func decodePropertyOptions(_ storage: String) -> [DocumentPropertyOptionDraft] {
        guard let data = storage.data(using: .utf8) else { return [] }

        if let decoded = try? JSONDecoder().decode([DocumentPropertyOptionDraft].self, from: data) {
            return decoded
        }

        if let legacy = try? JSONDecoder().decode([String].self, from: data) {
            return legacy.map {
                DocumentPropertyOptionDraft(
                    name: $0,
                    colorHex: ""
                )
            }
        }

        return []
    }

    private static func encodePropertyOptions(_ options: [DocumentPropertyOptionDraft]) -> String {
        guard let data = try? JSONEncoder().encode(options),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return string
    }

    private static func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#6055F7"
        }

        let r = Int(round(red * 255))
        let g = Int(round(green * 255))
        let b = Int(round(blue * 255))

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

struct DocumentPropertyOptionDraft: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String = ""
}
