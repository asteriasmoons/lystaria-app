//
//  DocumentTableData.swift
//  Lystaria
//
//  Created by Asteria Moon
//

import Foundation
import UIKit

func uiColorFromHex(_ hex: String) -> UIColor? {
    let h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if h.count == 8, let val = UInt64(h, radix: 16) {
        // RGBA 8-char
        return UIColor(
            red: CGFloat((val >> 24) & 0xFF) / 255,
            green: CGFloat((val >> 16) & 0xFF) / 255,
            blue: CGFloat((val >> 8) & 0xFF) / 255,
            alpha: CGFloat(val & 0xFF) / 255
        )
    }
    guard h.count == 6, let val = UInt64(h, radix: 16) else { return nil }
    return UIColor(
        red: CGFloat((val >> 16) & 0xFF) / 255,
        green: CGFloat((val >> 8) & 0xFF) / 255,
        blue: CGFloat(val & 0xFF) / 255,
        alpha: 1
    )
}

// MARK: - Cell Style

struct DocumentTableCellStyle: Codable, Equatable {
    var typeRaw: String
    var rangeLocation: Int
    var rangeLength: Int
    var urlString: String  // link URL or highlight "FG:BG"

    var type: DocumentInlineStyleType {
        DocumentInlineStyleType(rawValue: typeRaw) ?? .bold
    }

    var nsRange: NSRange { NSRange(location: rangeLocation, length: rangeLength) }
}

// MARK: - Table Data

struct DocumentTableData: Codable {
    var cols: Int
    var rows: [[String]]
    var styles: [[[DocumentTableCellStyle]]]
    var cellBgColors: [[String]]  // [row][col] hex, empty = no color

    init(cols: Int = 3, rows: [[String]]? = nil) {
        self.cols = cols
        if let rows {
            self.rows = rows
        } else {
            self.rows = [
                Array(repeating: "", count: cols),
                Array(repeating: "", count: cols),
                Array(repeating: "", count: cols)
            ]
        }
        let rc = self.rows.count
        self.styles = Array(repeating: Array(repeating: [], count: cols), count: rc)
        self.cellBgColors = Array(repeating: Array(repeating: "", count: cols), count: rc)
    }

    var rowCount: Int { rows.count }
    var colCount: Int { cols }

    func cell(row: Int, col: Int) -> String {
        guard row < rows.count, col < rows[row].count else { return "" }
        return rows[row][col]
    }

    func cellStyles(row: Int, col: Int) -> [DocumentTableCellStyle] {
        guard row < styles.count, col < styles[row].count else { return [] }
        return styles[row][col]
    }

    mutating func setCell(row: Int, col: Int, value: String) {
        guard row < rows.count else { return }
        while col >= rows[row].count { rows[row].append("") }
        rows[row][col] = value
        trimStyles(row: row, col: col, toLength: (value as NSString).length)
    }

    mutating func setCellStyles(row: Int, col: Int, styles newStyles: [DocumentTableCellStyle]) {
        ensureStylesCapacity()
        guard row < styles.count, col < styles[row].count else { return }
        styles[row][col] = newStyles
    }

    func cellBgColor(row: Int, col: Int) -> String {
        guard row < cellBgColors.count, col < cellBgColors[row].count else { return "" }
        return cellBgColors[row][col]
    }

    mutating func setCellBgColor(row: Int, col: Int, hex: String) {
        ensureBgColorsCapacity()
        guard row < cellBgColors.count, col < cellBgColors[row].count else { return }
        cellBgColors[row][col] = hex
    }

    mutating func addRow() {
        rows.append(Array(repeating: "", count: cols))
        styles.append(Array(repeating: [], count: cols))
        cellBgColors.append(Array(repeating: "", count: cols))
    }

    mutating func addColumn() {
        cols += 1
        for i in rows.indices { rows[i].append("") }
        for i in styles.indices { styles[i].append([]) }
        for i in cellBgColors.indices { cellBgColors[i].append("") }
    }

    mutating func deleteRow(at index: Int) {
        guard rows.count > 1, index < rows.count else { return }
        rows.remove(at: index)
        if index < styles.count { styles.remove(at: index) }
        if index < cellBgColors.count { cellBgColors.remove(at: index) }
    }

    mutating func deleteColumn(at index: Int) {
        guard cols > 1, index < cols else { return }
        cols -= 1
        for i in rows.indices {
            if index < rows[i].count { rows[i].remove(at: index) }
        }
        for i in styles.indices {
            if index < styles[i].count { styles[i].remove(at: index) }
        }
        for i in cellBgColors.indices {
            if index < cellBgColors[i].count { cellBgColors[i].remove(at: index) }
        }
    }

    // MARK: - Helpers

    private mutating func ensureStylesCapacity() {
        while styles.count < rows.count {
            styles.append(Array(repeating: [], count: cols))
        }
        for i in styles.indices {
            while styles[i].count < cols { styles[i].append([]) }
        }
    }

    private mutating func ensureBgColorsCapacity() {
        while cellBgColors.count < rows.count {
            cellBgColors.append(Array(repeating: "", count: cols))
        }
        for i in cellBgColors.indices {
            while cellBgColors[i].count < cols { cellBgColors[i].append("") }
        }
    }

    private mutating func trimStyles(row: Int, col: Int, toLength length: Int) {
        ensureStylesCapacity()
        guard row < styles.count, col < styles[row].count else { return }
        styles[row][col] = styles[row][col].compactMap { s in
            guard s.rangeLocation < length else { return nil }
            let clampedLength = min(s.rangeLength, length - s.rangeLocation)
            guard clampedLength > 0 else { return nil }
            var copy = s
            copy.rangeLength = clampedLength
            return copy
        }
    }

    // MARK: - Attributed text builder (for both editor and preview)

    func attributedText(row: Int, col: Int, baseFont: UIFont, textColor: UIColor) -> NSAttributedString {
        let text = cell(row: row, col: col)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let base: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]
        let mutable = NSMutableAttributedString(string: text, attributes: base)
        let fullLength = (text as NSString).length
        guard fullLength > 0 else { return mutable }

        for style in cellStyles(row: row, col: col) {
            let raw = style.nsRange
            let maxLen = max(0, fullLength - raw.location)
            let clampedLen = min(raw.length, maxLen)
            guard raw.location >= 0, raw.location < fullLength, clampedLen > 0 else { continue }
            let range = NSRange(location: raw.location, length: clampedLen)

            switch style.type {
            case .bold:
                mutable.enumerateAttribute(.font, in: range) { val, sub, _ in
                    let f = (val as? UIFont) ?? baseFont
                    if let d = f.fontDescriptor.withSymbolicTraits(f.fontDescriptor.symbolicTraits.union(.traitBold)) {
                        mutable.addAttribute(.font, value: UIFont(descriptor: d, size: f.pointSize), range: sub)
                    }
                }
            case .italic:
                mutable.enumerateAttribute(.font, in: range) { val, sub, _ in
                    let f = (val as? UIFont) ?? baseFont
                    if let d = f.fontDescriptor.withSymbolicTraits(f.fontDescriptor.symbolicTraits.union(.traitItalic)) {
                        mutable.addAttribute(.font, value: UIFont(descriptor: d, size: f.pointSize), range: sub)
                    }
                }
            case .underline:
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case .strikethrough:
                mutable.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case .link:
                let trimmed = style.urlString.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, let url = URL(string: trimmed) else { continue }
                mutable.addAttribute(.link, value: url, range: range)
                mutable.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: range)
            case .inlineCode:
                let mono = UIFont.monospacedSystemFont(ofSize: baseFont.pointSize * 0.9, weight: .regular)
                mutable.addAttribute(.font, value: mono, range: range)
                mutable.addAttribute(.backgroundColor, value: UIColor.white.withAlphaComponent(0.1), range: range)
            case .highlight:
                let parts = style.urlString.components(separatedBy: ":")
                guard parts.count == 2,
                      let c1 = uiColorFromHex(parts[0]),
                      let c2 = uiColorFromHex(parts[1]),
                      range.length > 0 else { continue }
                var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
                var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
                c1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
                c2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
                let count = CGFloat(range.length)
                for i in 0..<range.length {
                    let t = count > 1 ? CGFloat(i) / (count - 1) : 0
                    let blended = UIColor(red: r1+(r2-r1)*t, green: g1+(g2-g1)*t, blue: b1+(b2-b1)*t, alpha: 1)
                    mutable.addAttribute(.foregroundColor, value: blended,
                        range: NSRange(location: range.location + i, length: 1))
                }
            }
        }
        return mutable
    }

    // MARK: - JSON

    static func from(_ json: String) -> DocumentTableData {
        guard let data = json.data(using: .utf8),
              let table = try? JSONDecoder().decode(DocumentTableData.self, from: data) else {
            return DocumentTableData()
        }
        return table
    }

    func toJSON() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let str = String(data: data, encoding: .utf8) else { return "{}" }
        return str
    }
}
