//
//  WatchProfileView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/9/26.
//

import SwiftUI

struct WatchProfileView: View {

    @State private var syncing = false
    @State private var synced = false

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

                if synced {
                    Text("Synced")
                        .foregroundStyle(.white)
                        .font(.system(size: 14, weight: .medium))
                } else if syncing {
                    ProgressView()
                        .tint(.white)
                } else {

                    Button {
                        Task {
                            syncing = true
                            await SupabaseSessionBridge.syncSessionToWatch()
                            syncing = false
                            synced = true
                        }
                    } label: {
                        Text("Sync")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.18))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(.white.opacity(0.35), lineWidth: 1)
                            )
                    }

                }

                Spacer()
            }
            .padding()
        }
    }
}
