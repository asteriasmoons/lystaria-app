//
//  DocumentInlinePropertyChip.swift
//  Lystaria
//
//  Created by Asteria Moon on 5/8/26.
//

import SwiftUI

struct DocumentInlinePropertyChip: View {
    let property: DocumentInlineProperty
    var onTap: (() -> Void)? = nil

    private var type: DocumentInlinePropertyType {
        DocumentInlinePropertyType(rawValue: property.typeRaw) ?? .text
    }

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack(spacing: 6) {
                Text(property.name.isEmpty ? type.rawValue : property.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white.opacity(0.82))

                Text(displayValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)

                if type == .checkbox || type == .boolean {
                    Image(systemName: boolValue ? "checkmark.circle.fill" : "circle")
                        .font(.caption)
                        .foregroundStyle(boolValue ? LColors.accent : .white.opacity(0.55))
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.white.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(LColors.glassBorder.opacity(0.8), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var displayValue: String {
        switch type {
        case .boolean:
            return boolValue ? "True" : "False"

        case .checkbox:
            return boolValue ? "Checked" : "Unchecked"

        case .text:
            return property.valueStorage.isEmpty ? "Empty" : property.valueStorage

        case .number:
            return property.valueStorage.isEmpty ? "0" : property.valueStorage

        case .date:
            return formattedDate

        case .url:
            return property.valueStorage.isEmpty ? "No URL" : property.valueStorage

        case .select:
            return property.valueStorage.isEmpty ? "None" : property.valueStorage

        case .multiSelect:
            let values = decodeStringArray(property.valueStorage)
            return values.isEmpty ? "None" : values.joined(separator: ", ")
        }
    }

    private var boolValue: Bool {
        property.valueStorage == "true"
    }

    private var formattedDate: String {
        guard let date = ISO8601DateFormatter().date(from: property.valueStorage) else {
            return "No Date"
        }

        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func decodeStringArray(_ storage: String) -> [String] {
        guard let data = storage.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }

        return decoded
    }
}
