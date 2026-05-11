//
//  DocumentTextColorPickerSheet.swift
//  Lystaria
//
//  Created by Asteria Moon
//

import SwiftUI

struct DocumentTextColorPickerSheet: View {
    @Bindable var entry: DocumentEntry
    @Binding var selection: Color
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                LystariaBackground()
                    .ignoresSafeArea()

                VStack(spacing: 24) {
                    ColorPicker("Text Color", selection: $selection, supportsOpacity: false)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(LColors.textPrimary)
                        .padding(.horizontal, LSpacing.pageHorizontal)

                    if !entry.textColorHex.isEmpty {
                        Button {
                            entry.textColorHex = ""
                            entry.touch()
                            isPresented = false
                        } label: {
                            Text("Reset to Default")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(LColors.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.top, 24)
            }
            .navigationTitle("Text Color")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") {
                        let uiColor = UIColor(selection)
                        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
                        entry.textColorHex = String(format: "%02X%02X%02X",
                            Int(r * 255), Int(g * 255), Int(b * 255))
                        entry.touch()
                        isPresented = false
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                }
            }
        }
    }
}
