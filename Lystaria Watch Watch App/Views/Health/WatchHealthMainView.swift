//
//  WatchHealthMainView.swift
//  Lystaria
//

import SwiftUI

struct WatchHealthMainView: View {
    var body: some View {
        ZStack{
            WatchLystariaBackground()
        
            VStack(spacing: 12) {
                Spacer()

                NavigationLink {
                    WatchStepsView()
                } label: {
                    WatchHealthCard(
                        icon: "shoefill",
                        title: "Steps"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    WatchWaterView()
                } label: {
                    WatchHealthCard(
                        icon: "glassfill",
                        title: "Water"
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
        }
        .navigationTitle("Health")
        .toolbarBackground(.hidden, for: .navigationBar)
    }
}

// MARK: - Card

private struct WatchHealthCard: View {
    let icon: String
    let title: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.16), lineWidth: 1)
                )
            
            HStack(spacing: 8) {
                
                Image(icon)
                    .renderingMode(.template)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 18, height: 18)
                    .foregroundStyle(.white)
                
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .frame(height: 62)
    }
}

#Preview {
    NavigationStack{
        WatchHealthMainView()
    }
}
