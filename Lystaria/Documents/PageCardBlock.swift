//
//  PageCardBlock.swift
//  Lystaria
//
//  Created by Asteria Moon
//

import SwiftUI
import SwiftData
import PhotosUI

// MARK: - Page Card Size

enum PageCardSize: String, CaseIterable {
    case square  // ~160x160
    case banner  // full width, short (~80pt tall)
    case full    // full width, tall (~200pt)
}

// MARK: - Page Card Style

enum PageCardStyleMode: String, CaseIterable {
    case `default`
    case color
    case gradient
    case image
}

// MARK: - DocumentBlock page helpers

extension DocumentBlock {

    // languageHint format: "childUUID|size|styleMode|showPreviewPage"
    // Falls back gracefully if old format (bare UUID) is present

    var pageChildUUID: UUID? {
        guard type == .page else { return nil }
        let parts = languageHint.components(separatedBy: "|")
        return UUID(uuidString: parts[0].trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var pageCardSize: PageCardSize {
        get {
            let parts = languageHint.components(separatedBy: "|")
            guard parts.count > 1 else { return .square }
            return PageCardSize(rawValue: parts[1]) ?? .square
        }
        set {
            var parts = languageHint.components(separatedBy: "|")
            while parts.count < 4 { parts.append("") }
            parts[1] = newValue.rawValue
            languageHint = parts.joined(separator: "|")
        }
    }

    var pageCardStyleMode: PageCardStyleMode {
        get {
            let parts = languageHint.components(separatedBy: "|")
            guard parts.count > 2 else { return .default }
            return PageCardStyleMode(rawValue: parts[2]) ?? .default
        }
        set {
            var parts = languageHint.components(separatedBy: "|")
            while parts.count < 4 { parts.append("") }
            parts[2] = newValue.rawValue
            languageHint = parts.joined(separator: "|")
        }
    }

    var pageCardShowsPreviewPage: Bool {
        get {
            let parts = languageHint.components(separatedBy: "|")
            guard parts.count > 3 else { return true }
            let value = parts[3].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return true }
            return value != "false"
        }
        set {
            var parts = languageHint.components(separatedBy: "|")
            while parts.count < 4 { parts.append("") }
            parts[3] = newValue ? "true" : "false"
            languageHint = parts.joined(separator: "|")
        }
    }

    /// Write page fields atomically to avoid partial-state issues.
    func setPageCardMeta(childUUID: UUID, size: PageCardSize, style: PageCardStyleMode, showPreviewPage: Bool = true) {
        languageHint = "\(childUUID.uuidString)|\(size.rawValue)|\(style.rawValue)|\(showPreviewPage ? "true" : "false")"
    }
}

// MARK: - Shared card background helper

struct PageCardBackground: View {
    let block: DocumentBlock
    let cornerRadius: CGFloat

    var body: some View {
        switch block.pageCardStyleMode {
        case .default:
            defaultBackground
        case .color:
            colorBackground
        case .gradient:
            gradientBackground
        case .image:
            imageBackground
        }
    }

    private var defaultBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.black.opacity(0.28))
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }

    private var colorBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color(block.blockColor1))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }

    private var gradientBackground: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(block.blockColor1), Color(block.blockColor2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
            )
    }

    private var imageBackground: some View {
        Group {
            if let data = block.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(Color.black.opacity(0.32))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            } else {
                defaultBackground
            }
        }
    }
}

// MARK: - Shared card title text color

extension DocumentBlock {
    var pageCardTitleColor: Color {
        switch pageCardStyleMode {
        case .default: return Color(LColors.textPrimary)
        case .color, .gradient, .image: return .white
        }
    }

    var pageCardSubtitleColor: Color {
        switch pageCardStyleMode {
        case .default: return Color(LColors.textSecondary)
        case .color, .gradient, .image: return .white.opacity(0.7)
        }
    }
}

// MARK: - Page Card View (shared between editor and preview)

struct PageCardView: View {
    let block: DocumentBlock
    let childEntry: DocumentEntry?
    /// In editor mode the destination is the editor page; in preview it's the preview page.
    /// Pass nil to disable navigation (e.g. when childEntry is missing).
    let destination: AnyView?
    let isSelectionMode: Bool

    private var title: String {
        let t = childEntry?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return t.isEmpty ? "Untitled Page" : t
    }

    private var previewText: String {
        childEntry?.blockPreviewText ?? ""
    }

    private var displayPreviewText: String {
        previewText.isEmpty
            ? "Preview of the page will be displayed here. Tap to add content."
            : previewText
    }

    var body: some View {
        let cardContent = cardBody
            .contentShape(Rectangle())
            .transaction { transaction in
                transaction.animation = nil
            }

        if let destination, !isSelectionMode {
            NavigationLink(destination: destination) {
                cardContent
            }
            .buttonStyle(.plain)
            .transaction { transaction in
                transaction.animation = nil
            }
        } else {
            cardContent
                .opacity(isSelectionMode ? 0.6 : 1)
                .transaction { transaction in
                    transaction.animation = nil
                }
        }
    }

    @ViewBuilder
    private var cardBody: some View {
        switch block.pageCardSize {
        case .square:
            squareCard
        case .banner:
            bannerCard
        case .full:
            fullCard
        }
    }

    @ViewBuilder
    private func pagePreviewSheet(
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat = 12,
        titleVisible: Bool = true,
        bodyLineCount: Int = 5
    ) -> some View {
        ZStack {
            UnevenRoundedRectangle(
                topLeadingRadius: cornerRadius,
                bottomLeadingRadius: cornerRadius * 0.75,
                bottomTrailingRadius: cornerRadius * 1.25,
                topTrailingRadius: cornerRadius * 0.85,
                style: .continuous
            )
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.96),
                        Color.white.opacity(0.88),
                        Color.white.opacity(0.94)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                UnevenRoundedRectangle(
                    topLeadingRadius: cornerRadius,
                    bottomLeadingRadius: cornerRadius * 0.75,
                    bottomTrailingRadius: cornerRadius * 1.25,
                    topTrailingRadius: cornerRadius * 0.85,
                    style: .continuous
                )
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.38), radius: 12, x: 0, y: 8)

            VStack(alignment: .leading, spacing: 0) {
                if titleVisible {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.16))
                        .frame(width: width * 0.5, height: 10)
                        .padding(.top, 26)
                        .padding(.horizontal, 26)
                }

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(0..<bodyLineCount, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.12))
                            .frame(
                                width: index == bodyLineCount - 1
                                    ? width * 0.44
                                    : width * (0.58 + CGFloat(index % 3) * 0.09),
                                height: 8
                            )
                    }
                }
                .padding(.horizontal, 26)
                .padding(.top, titleVisible ? 22 : 28)

                Spacer(minLength: 0)
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: Square (~160x160)

    private var squareCard: some View {
        ZStack(alignment: .trailing) {
            PageCardBackground(block: block, cornerRadius: 16)

            if block.pageCardShowsPreviewPage {
                pagePreviewSheet(
                    width: 90,
                    height: 128,
                    cornerRadius: 12,
                    titleVisible: false,
                    bodyLineCount: 5
                )
                .offset(x: 38, y: 12)
                .rotationEffect(.degrees(-1.4))
                .opacity(0.96)
            }

            VStack(alignment: .leading, spacing: 4) {
                Spacer(minLength: 0)

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(block.pageCardTitleColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if !previewText.isEmpty {
                    Text(previewText)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(block.pageCardSubtitleColor)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(width: 170, height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 4)
    }

    // MARK: Banner (full width, medium height)

    private var bannerCard: some View {
        ZStack(alignment: .trailing) {
            PageCardBackground(block: block, cornerRadius: 14)

            if block.pageCardShowsPreviewPage {
                pagePreviewSheet(
                    width: 118,
                    height: 150,
                    cornerRadius: 14,
                    titleVisible: false,
                    bodyLineCount: 6
                )
                .offset(x: 28, y: 42)
                .rotationEffect(.degrees(-1.4))
                .opacity(0.96)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(block.pageCardTitleColor)
                    .lineLimit(1)

                Text(displayPreviewText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(block.pageCardSubtitleColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.trailing, block.pageCardShowsPreviewPage ? 150 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 4)
    }

    // MARK: Full (full width, 200pt tall)

    private var fullCard: some View {
        ZStack(alignment: .trailing) {
            PageCardBackground(block: block, cornerRadius: 18)

            if block.pageCardShowsPreviewPage {
                pagePreviewSheet(
                    width: 126,
                    height: 160,
                    cornerRadius: 16,
                    titleVisible: false,
                    bodyLineCount: 8
                )
                .padding(.trailing, 20)
                .rotationEffect(.degrees(-1.4))
                .opacity(0.98)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(block.pageCardTitleColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(displayPreviewText)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(block.pageCardSubtitleColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .padding(.trailing, block.pageCardShowsPreviewPage ? 156 : 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.22), radius: 10, x: 0, y: 4)
    }
}

// MARK: - Page Card Customization Sheet

struct PageCardCustomizationSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var block: DocumentBlock

    @State private var selectedSize: PageCardSize
    @State private var selectedStyle: PageCardStyleMode
    @State private var showPreviewPage: Bool
    @State private var color1: Color
    @State private var color2: Color
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    init(block: DocumentBlock) {
        self.block = block
        _selectedSize = State(initialValue: block.pageCardSize)
        _selectedStyle = State(initialValue: block.pageCardStyleMode)
        _showPreviewPage = State(initialValue: block.pageCardShowsPreviewPage)
        let c1 = block.hasCustomBlockColor ? Color(block.blockColor1) : Color(LColors.accent)
        let c2 = block.hasCustomBlockColor ? Color(block.blockColor2) : Color(LColors.accent)
        _color1 = State(initialValue: c1)
        _color2 = State(initialValue: c2)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground().ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {

                        // Live preview
                        preview
                            .padding(.horizontal, LSpacing.pageHorizontal)
                            .padding(.top, 4)

                        // Size picker
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("Size")
                            HStack(spacing: 10) {
                                ForEach(PageCardSize.allCases, id: \.self) { size in
                                    sizeButton(size)
                                }
                            }
                            .padding(.horizontal, LSpacing.pageHorizontal)
                        }

                        // Page preview toggle
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("Page Preview")
                            Toggle(isOn: $showPreviewPage) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Show Page Inside Card")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)

                                    Text("Display the little paper preview on the right side of the card.")
                                        .font(.system(size: 12, weight: .regular))
                                        .foregroundStyle(LColors.textSecondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .toggleStyle(.switch)
                            .tint(Color(LColors.accent))
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(LColors.glassBorder, lineWidth: 1)
                            )
                            .padding(.horizontal, LSpacing.pageHorizontal)
                            .onChange(of: showPreviewPage) { _, newValue in
                                block.pageCardShowsPreviewPage = newValue
                                block.touch()
                            }
                        }

                        // Style picker
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("Background")
                            HStack(spacing: 10) {
                                ForEach(PageCardStyleMode.allCases, id: \.self) { style in
                                    styleButton(style)
                                }
                            }
                            .padding(.horizontal, LSpacing.pageHorizontal)
                        }

                        // Color/gradient pickers
                        if selectedStyle == .color || selectedStyle == .gradient {
                            VStack(alignment: .leading, spacing: 16) {
                                sectionLabel(selectedStyle == .gradient ? "Colors" : "Color")
                                VStack(spacing: 14) {
                                    ColorPicker("Color 1", selection: $color1, supportsOpacity: false)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(LColors.textPrimary)
                                    if selectedStyle == .gradient {
                                        ColorPicker("Color 2", selection: $color2, supportsOpacity: false)
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(LColors.textPrimary)
                                    }
                                }
                                .padding(.horizontal, LSpacing.pageHorizontal)
                            }
                        }

                        // Image picker
                        if selectedStyle == .image {
                            VStack(alignment: .leading, spacing: 12) {
                                sectionLabel("Image")
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    HStack(spacing: 10) {
                                        Image(systemName: block.imageData != nil ? "arrow.triangle.2.circlepath" : "photo.badge.plus")
                                            .font(.system(size: 15, weight: .semibold))
                                        Text(block.imageData != nil ? "Replace Image" : "Choose Image")
                                            .font(.system(size: 15, weight: .semibold))
                                    }
                                    .foregroundStyle(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(LGradients.blue)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, LSpacing.pageHorizontal)
                            }
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Card Style")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(LColors.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") { applyAndDismiss() }
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let compressed = UIImage(data: data)
                        .flatMap { $0.jpegData(compressionQuality: 0.75) } ?? data
                    await MainActor.run {
                        block.imageData = compressed
                        block.touch()
                    }
                }
                await MainActor.run { selectedPhotoItem = nil }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var preview: some View {
        switch selectedSize {
        case .square:
            HStack {
                Spacer()
                PageCardView(block: block, childEntry: nil, destination: nil, isSelectionMode: false)
                Spacer()
            }
        case .banner, .full:
            PageCardView(block: block, childEntry: nil, destination: nil, isSelectionMode: false)
        }
    }

    // MARK: Controls

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(LColors.textSecondary)
            .textCase(.uppercase)
            .padding(.horizontal, LSpacing.pageHorizontal)
    }

    private func sizeButton(_ size: PageCardSize) -> some View {
        let active = selectedSize == size
        return Button {
            selectedSize = size
            block.pageCardSize = size
            block.touch()
        } label: {
            Text(sizeLabel(size))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? .white : LColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(active ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.white.opacity(0.08)))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(active ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.glassBorder), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func styleButton(_ style: PageCardStyleMode) -> some View {
        let active = selectedStyle == style
        return Button {
            selectedStyle = style
            block.pageCardStyleMode = style
            block.touch()
        } label: {
            Text(styleLabel(style))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(active ? .white : LColors.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(active ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(Color.white.opacity(0.08)))
                .clipShape(Capsule())
                .overlay(Capsule().stroke(active ? AnyShapeStyle(LGradients.blue) : AnyShapeStyle(LColors.glassBorder), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func sizeLabel(_ size: PageCardSize) -> String {
        switch size {
        case .square: return "Square"
        case .banner: return "Banner"
        case .full: return "Full"
        }
    }

    private func styleLabel(_ style: PageCardStyleMode) -> String {
        switch style {
        case .default: return "Default"
        case .color: return "Color"
        case .gradient: return "Gradient"
        case .image: return "Image"
        }
    }

    private func applyAndDismiss() {
        // Write size + style
        block.pageCardSize = selectedSize
        block.pageCardStyleMode = selectedStyle
        block.pageCardShowsPreviewPage = showPreviewPage

        // Write colors if needed
        if selectedStyle == .color || selectedStyle == .gradient {
            let hex1 = hexString(from: UIColor(color1))
            let hex2 = selectedStyle == .gradient ? hexString(from: UIColor(color2)) : hex1
            block.colorHex = "\(hex1):\(hex2)"
        } else if selectedStyle != .image {
            // default — clear custom color
            block.colorHex = ""
        }

        block.touch()
        try? modelContext.save()
        dismiss()
    }

    private func hexString(from color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
