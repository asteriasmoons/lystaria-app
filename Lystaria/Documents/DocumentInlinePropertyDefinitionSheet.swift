//
//  DocumentInlinePropertyDefinitionSheet.swift
//  Lystaria
//
//  Created by Asteria Moon on 5/8/26.
//

import SwiftUI

struct DocumentInlinePropertyDefinitionSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingProperty: DocumentInlineProperty?
    let onSave: (DocumentInlinePropertyDraft) -> Void

    @State private var name: String
    @State private var type: DocumentInlinePropertyType
    @State private var textValue: String
    @State private var numberValue: String
    @State private var urlValue: String
    @State private var booleanValue: Bool
    @State private var checkboxValue: Bool
    @State private var dateValue: Date
    @State private var options: [DocumentPropertyOptionDraft]
    @State private var selectedOption: String
    @State private var selectedOptions: Set<String>
    @State private var colorHex: String

    init(
        existingProperty: DocumentInlineProperty? = nil,
        onSave: @escaping (DocumentInlinePropertyDraft) -> Void
    ) {
        self.existingProperty = existingProperty
        self.onSave = onSave

        let decodedOptions = DocumentInlinePropertyDefinitionSheet.decodePropertyOptions(
            existingProperty?.optionsStorage ?? ""
        )

        let decodedType = DocumentInlinePropertyType(
            rawValue: existingProperty?.typeRaw ?? ""
        ) ?? .text

        _name = State(initialValue: existingProperty?.name ?? "")
        _type = State(initialValue: decodedType)
        _textValue = State(initialValue: decodedType == .text ? existingProperty?.valueStorage ?? "" : "")
        _numberValue = State(initialValue: decodedType == .number ? existingProperty?.valueStorage ?? "" : "")
        _urlValue = State(initialValue: decodedType == .url ? existingProperty?.valueStorage ?? "" : "")
        _booleanValue = State(initialValue: existingProperty?.valueStorage == "true")
        _checkboxValue = State(initialValue: existingProperty?.valueStorage == "true")
        _dateValue = State(initialValue: Self.decodeDate(existingProperty?.valueStorage ?? "") ?? Date())
        _options = State(initialValue: decodedOptions)
        _selectedOption = State(initialValue: decodedType == .select ? existingProperty?.valueStorage ?? "" : "")
        _selectedOptions = State(initialValue: Set(Self.decodeOptions(existingProperty?.valueStorage ?? "")))
        _colorHex = State(initialValue: existingProperty?.colorHex ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        headerSection
                        nameSection
                        typeSection
                        valueSection
                        optionsSectionIfNeeded
                    }
                    .padding(20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(.white.opacity(0.75))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveProperty()
                    }
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(existingProperty == nil ? "New Property" : "Edit Property")
                .font(.custom("Lily Script One", size: 30))
                .foregroundStyle(LGradients.blue)

            Text("Create an inline property that can be placed anywhere inside a document block.")
                .font(.callout)
                .foregroundStyle(.white.opacity(0.72))
        }
    }

    private var nameSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("Property Name")
                    .font(.headline)
                    .foregroundStyle(.white)

                TextField("Status, Source, Priority, Due Date...", text: $name)
                    .textInputAutocapitalization(.words)
                    .padding(12)
                    .background(.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
        }
    }

    private var typeSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Property Type")
                    .font(.headline)
                    .foregroundStyle(.white)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 135), spacing: 10)], spacing: 10) {
                    ForEach(DocumentInlinePropertyType.allCases) { propertyType in
                        Button {
                            type = propertyType
                        } label: {
                            HStack {
                                Text(propertyType.rawValue)
                                    .font(.callout)
                                    .fontWeight(.medium)

                                Spacer()

                                if type == propertyType {
                                    Image(systemName: "checkmark.circle.fill")
                                }
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(type == propertyType ? LColors.accent.opacity(0.35) : .white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .stroke(type == propertyType ? LColors.accent.opacity(0.8) : .white.opacity(0.12), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var valueSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Default Value")
                    .font(.headline)
                    .foregroundStyle(.white)

                switch type {
                case .boolean:
                    Toggle("Enabled", isOn: $booleanValue)
                        .tint(LColors.accent)

                case .checkbox:
                    Toggle("Checked", isOn: $checkboxValue)
                        .tint(LColors.accent)

                case .text:
                    TextField("Enter text...", text: $textValue)
                        .padding(12)
                        .background(.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)

                case .number:
                    TextField("Enter number...", text: $numberValue)
                        .keyboardType(.decimalPad)
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
        if type == .select || type == .multiSelect {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Options")
                            .font(.headline)
                            .foregroundStyle(.white)

                        Spacer()

                        Button {
                            options.append(DocumentPropertyOptionDraft(name: "", colorHex: "#6055F7"))
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(LColors.accent)
                        }
                    }

                    ForEach(options.indices, id: \.self) { index in
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 10) {
                                TextField("Option name", text: bindingForOptionName(at: index))
                                    .padding(12)
                                    .background(.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .foregroundStyle(.white)

                                Button {
                                    removeOption(at: index)
                                } label: {
                                    Image(systemName: "trash.fill")
                                        .foregroundStyle(.red.opacity(0.85))
                                }
                            }

                            ColorPicker("Option Color", selection: bindingForOptionColor(at: index), supportsOpacity: false)
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

    private var selectValuePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if cleanedOptions.isEmpty {
                Text("Add options below before choosing a default.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                ForEach(cleanedOptions) { option in
                    Button {
                        selectedOption = option.name
                        colorHex = option.colorHex
                    } label: {
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color(hex: option.colorHex) ?? LColors.accent)
                                .frame(width: 12, height: 12)

                            Text(option.name)

                            Spacer()

                            if selectedOption == option.name {
                                Image(systemName: "checkmark")
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.white.opacity(selectedOption == option.name ? 0.16 : 0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var multiSelectValuePicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if cleanedOptions.isEmpty {
                Text("Add options below before choosing defaults.")
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.65))
            } else {
                ForEach(cleanedOptions) { option in
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

                            Spacer()

                            if selectedOptions.contains(option.name) {
                                Image(systemName: "checkmark")
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.white.opacity(selectedOptions.contains(option.name) ? 0.16 : 0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var cleanedOptions: [DocumentPropertyOptionDraft] {
        options
            .map {
                DocumentPropertyOptionDraft(
                    id: $0.id,
                    name: $0.name.trimmingCharacters(in: .whitespacesAndNewlines),
                    colorHex: $0.colorHex
                )
            }
            .filter { !$0.name.isEmpty }
    }

    private func bindingForOptionName(at index: Int) -> Binding<String> {
        Binding(
            get: {
                guard options.indices.contains(index) else { return "" }
                return options[index].name
            },
            set: { newValue in
                guard options.indices.contains(index) else { return }
                options[index].name = newValue
            }
        )
    }

    private func bindingForOptionColor(at index: Int) -> Binding<Color> {
        Binding(
            get: {
                guard options.indices.contains(index) else { return LColors.accent }
                return Color(hex: options[index].colorHex) ?? LColors.accent
            },
            set: { newValue in
                guard options.indices.contains(index) else { return }
                options[index].colorHex = Self.hexString(from: newValue)
            }
        )
    }

    private func removeOption(at index: Int) {
        guard options.indices.contains(index) else { return }

        let removed = options[index].name
        options.remove(at: index)
        selectedOptions.remove(removed)

        if selectedOption == removed {
            selectedOption = ""
        }
    }

    private func saveProperty() {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedOptionList = cleanedOptions

        let valueStorage: String

        switch type {
        case .boolean:
            valueStorage = booleanValue ? "true" : "false"
        case .checkbox:
            valueStorage = checkboxValue ? "true" : "false"
        case .text:
            valueStorage = textValue
        case .number:
            valueStorage = numberValue
        case .date:
            valueStorage = Self.encodeDate(dateValue)
        case .url:
            valueStorage = urlValue
        case .select:
            valueStorage = selectedOption
            if let selected = cleanedOptionList.first(where: { $0.name == selectedOption }) {
                colorHex = selected.colorHex
            }
        case .multiSelect:
            valueStorage = Self.encodeOptions(Array(selectedOptions))
        }

        let draft = DocumentInlinePropertyDraft(
            name: cleanedName,
            type: type,
            valueStorage: valueStorage,
            optionsStorage: Self.encodePropertyOptions(cleanedOptionList),
            colorHex: colorHex
        )

        onSave(draft)
        dismiss()
    }
    private static func encodePropertyOptions(_ options: [DocumentPropertyOptionDraft]) -> String {
        guard let data = try? JSONEncoder().encode(options),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return string
    }

    private static func decodePropertyOptions(_ storage: String) -> [DocumentPropertyOptionDraft] {
        guard let data = storage.data(using: .utf8) else { return [] }

        if let decoded = try? JSONDecoder().decode([DocumentPropertyOptionDraft].self, from: data) {
            return decoded
        }

        if let legacy = try? JSONDecoder().decode([String].self, from: data) {
            return legacy.map { DocumentPropertyOptionDraft(name: $0, colorHex: "#6055F7") }
        }

        return []
    }

    private static func encodeOptions(_ options: [String]) -> String {
        guard let data = try? JSONEncoder().encode(options),
              let string = String(data: data, encoding: .utf8) else {
            return "[]"
        }

        return string
    }

    private static func decodeOptions(_ storage: String) -> [String] {
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

struct DocumentInlinePropertyDraft {
    var name: String
    var type: DocumentInlinePropertyType
    var valueStorage: String
    var optionsStorage: String
    var colorHex: String = ""
}

