//
//  JournalEntryBackground.swift
//  Lystaria
//

import SwiftUI

struct JournalEntryBackground: View {
    let entry: JournalEntry

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                switch entry.backgroundMode {

                case .defaultLystaria:
                    LystariaBackground()
                        .frame(width: proxy.size.width, height: proxy.size.height)

                case .solidColor:
                    solidColorBackground
                        .frame(width: proxy.size.width, height: proxy.size.height)

                case .gradient:
                    gradientBackground
                        .frame(width: proxy.size.width, height: proxy.size.height)

                    readabilityOverlay

                case .image:
                    imageBackground(size: proxy.size)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
    }

    // MARK: - Solid Color

    private var solidColorBackground: some View {
        (Color(hex: entry.backgroundColorHex) ?? Color.black)
            .ignoresSafeArea()
    }

    // MARK: - Gradient

    private var gradientBackground: some View {
        let start = Color(hex: entry.backgroundGradientStartHex) ?? Color.black
        let end = Color(hex: entry.backgroundGradientEndHex) ?? Color.black.opacity(0.85)

        return LinearGradient(
            colors: [start, end],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    // MARK: - Image

    private func imageBackground(size: CGSize) -> some View {
        ZStack {
            if let data = entry.backgroundImageData,
               let uiImage = UIImage(data: data) {

                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size.width, height: size.height)
                    .clipped()
                    .opacity(entry.backgroundImageOpacity)
                    .blur(radius: entry.backgroundImageBlur)
                    .ignoresSafeArea()

            } else {
                LystariaBackground()
                    .frame(width: size.width, height: size.height)
            }

            readabilityOverlay
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }

    // MARK: - Overlay

    private var readabilityOverlay: some View {
        Color.black
            .opacity(entry.backgroundOverlayOpacity)
            .ignoresSafeArea()
    }
}
