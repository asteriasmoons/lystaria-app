//
//  DocumentBackgroundSettingsSheet.swift
//  Lystaria
//
//  Created by Asteria Moon on 5/8/26.
//

import SwiftUI
import PhotosUI

struct DocumentBackgroundSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var entry: DocumentEntry

    @State private var showPhotoPicker = false

    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()

                ScrollView {
                    VStack(spacing: 20) {

                        // MARK: - Header

                        GlassCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Document Background")
                                    .font(.custom("Lily Script One", size: 30))
                                    .foregroundStyle(LGradients.blue)

                                Text("Customize the background appearance behind your document.")
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.72))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // MARK: - Background Mode

                        GlassCard {
                            VStack(alignment: .leading, spacing: 14) {

                                Text("Background Type")
                                    .font(.headline)
                                    .foregroundStyle(.white)

                                Picker("", selection: backgroundModeBinding) {
                                    ForEach(DocumentEntryBackgroundMode.allCases) { mode in
                                        Text(mode.title)
                                            .tag(mode)
                                    }
                                }
                                .pickerStyle(.segmented)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // MARK: - Solid Color

                        if entry.backgroundMode == .solidColor {

                            GlassCard {
                                VStack(alignment: .leading, spacing: 14) {

                                    Text("Background Color")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    ColorPicker(
                                        "Choose Color",
                                        selection: solidColorBinding,
                                        supportsOpacity: false
                                    )
                                    .foregroundStyle(.white.opacity(0.8))
                                    .tint(LColors.accent)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // MARK: - Gradient

                        if entry.backgroundMode == .gradient {

                            GlassCard {
                                VStack(alignment: .leading, spacing: 16) {

                                    Text("Gradient Colors")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    VStack(alignment: .leading, spacing: 10) {

                                        Text("Start Color")
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.72))

                                        ColorPicker(
                                            "Start",
                                            selection: gradientStartBinding,
                                            supportsOpacity: false
                                        )
                                        .labelsHidden()
                                    }

                                    VStack(alignment: .leading, spacing: 10) {

                                        Text("End Color")
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.72))

                                        ColorPicker(
                                            "End",
                                            selection: gradientEndBinding,
                                            supportsOpacity: false
                                        )
                                        .labelsHidden()
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // MARK: - Image

                        if entry.backgroundMode == .image {

                            GlassCard {
                                VStack(alignment: .leading, spacing: 18) {

                                    Text("Background Image")
                                        .font(.headline)
                                        .foregroundStyle(.white)

                                    if let data = entry.backgroundImageData,
                                       let uiImage = UIImage(data: data) {

                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 180)
                                            .frame(maxWidth: .infinity)
                                            .clipShape(
                                                RoundedRectangle(
                                                    cornerRadius: 22,
                                                    style: .continuous
                                                )
                                            )
                                    }

                                    Button {
                                        showPhotoPicker = true
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: "photo")
                                            Text(entry.backgroundImageData == nil
                                                 ? "Choose Image"
                                                 : "Replace Image")
                                        }
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(
                                            RoundedRectangle(
                                                cornerRadius: 18,
                                                style: .continuous
                                            )
                                            .fill(.white.opacity(0.08))
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    VStack(alignment: .leading, spacing: 10) {

                                        HStack {
                                            Text("Image Opacity")
                                                .foregroundStyle(.white)

                                            Spacer()

                                            Text("\(Int(entry.backgroundImageOpacity * 100))%")
                                                .foregroundStyle(.white.opacity(0.7))
                                        }

                                        Slider(
                                            value: $entry.backgroundImageOpacity,
                                            in: 0...1
                                        )
                                        .tint(LColors.accent)
                                    }

                                    VStack(alignment: .leading, spacing: 10) {

                                        HStack {
                                            Text("Blur")
                                                .foregroundStyle(.white)

                                            Spacer()

                                            Text("\(Int(entry.backgroundImageBlur))")
                                                .foregroundStyle(.white.opacity(0.7))
                                        }

                                        Slider(
                                            value: $entry.backgroundImageBlur,
                                            in: 0...20
                                        )
                                        .tint(LColors.accent)
                                    }

                                    VStack(alignment: .leading, spacing: 10) {

                                        HStack {
                                            Text("Dark Overlay")
                                                .foregroundStyle(.white)

                                            Spacer()

                                            Text("\(Int(entry.backgroundOverlayOpacity * 100))%")
                                                .foregroundStyle(.white.opacity(0.7))
                                        }

                                        Slider(
                                            value: $entry.backgroundOverlayOpacity,
                                            in: 0...1
                                        )
                                        .tint(LColors.accent)
                                    }

                                    if entry.backgroundImageData != nil {

                                        Button(role: .destructive) {
                                            entry.backgroundImageData = nil
                                            entry.touch()
                                        } label: {

                                            HStack {
                                                Image(systemName: "trash.fill")

                                                Text("Remove Image")
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 14)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        // MARK: - Reset

                        GlassCard {
                            Button {
                                resetBackground()
                            } label: {

                                HStack {
                                    Image(systemName: "arrow.counterclockwise")

                                    Text("Reset Background")
                                }
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 120)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {

                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showPhotoPicker) {
                BackgroundImagePickerSheet { data in
                    entry.backgroundImageData = data
                    entry.touch()
                }
            }
        }
    }

    // MARK: - Bindings

    private var backgroundModeBinding: Binding<DocumentEntryBackgroundMode> {
        Binding(
            get: { entry.backgroundMode },
            set: {
                entry.backgroundMode = $0
                entry.touch()
            }
        )
    }

    private var solidColorBinding: Binding<Color> {
        Binding(
            get: {
                Color(hex: entry.backgroundColorHex) ?? .black
            },
            set: {
                entry.backgroundColorHex = Self.hexString(from: $0)
                entry.touch()
            }
        )
    }

    private var gradientStartBinding: Binding<Color> {
        Binding(
            get: {
                Color(hex: entry.backgroundGradientStartHex) ?? .black
            },
            set: {
                entry.backgroundGradientStartHex = Self.hexString(from: $0)
                entry.touch()
            }
        )
    }

    private var gradientEndBinding: Binding<Color> {
        Binding(
            get: {
                Color(hex: entry.backgroundGradientEndHex) ?? .black
            },
            set: {
                entry.backgroundGradientEndHex = Self.hexString(from: $0)
                entry.touch()
            }
        )
    }

    // MARK: - Actions

    private func resetBackground() {
        entry.backgroundMode = .defaultLystaria
        entry.backgroundColorHex = ""
        entry.backgroundGradientStartHex = ""
        entry.backgroundGradientEndHex = ""
        entry.backgroundImageData = nil
        entry.backgroundImageOpacity = 0.85
        entry.backgroundImageBlur = 0
        entry.backgroundOverlayOpacity = 0.35
        entry.touch()
    }

    // MARK: - Helpers

    private static func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)

        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0

        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#000000"
        }

        return String(
            format: "#%02X%02X%02X",
            Int(red * 255),
            Int(green * 255),
            Int(blue * 255)
        )
    }
}

// MARK: - Isolated photo picker to prevent parent scroll reset

private struct BackgroundImagePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onImagePicked: (Data) -> Void

    @State private var selectedItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground().ignoresSafeArea()
                PhotosPicker(
                    selection: $selectedItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    Text("Choose a Photo")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .navigationTitle("Choose Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .task(id: selectedItem) {
            guard let item = selectedItem else { return }
            if let data = try? await item.loadTransferable(type: Data.self) {
                onImagePicked(data)
            }
            dismiss()
        }
    }
}
