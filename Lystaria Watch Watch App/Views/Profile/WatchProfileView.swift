//
//  WatchProfileView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/9/26.
//

import SwiftUI

struct WatchProfileView: View {

    var body: some View {
        ZStack {

            // Lystaria gradient background
            LinearGradient(
                colors: [
                    Color(red: 125/255, green: 25/255, blue: 247/255), // purple
                    Color(red: 3/255, green: 219/255, blue: 252/255)   // teal
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 8) {
                    Text("Profile")
                        .foregroundStyle(.white)
                        .font(.system(size: 16, weight: .semibold))

                    Text("Your data syncs through iCloud automatically.")
                        .foregroundStyle(.white.opacity(0.9))
                        .font(.system(size: 12, weight: .medium))
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding()
        }
    }
}
