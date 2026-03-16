//
//  LocationSearchSheet.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/14/26.
//

import SwiftUI
import Combine
import MapKit

private let lystariaUseCurrentLocationNotification = NotificationCenter.default.publisher(
    for: NSNotification.Name("LystariaUseCurrentLocation")
)

struct LocationSearchSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var manager = LocationPickerManager()

    let onPick: (_ displayName: String, _ latitude: Double?, _ longitude: Double?) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                TextField("Search for a place", text: $manager.searchText)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.08))
                    )
                    .onChange(of: manager.searchText) { _, newValue in
                        manager.updateSearch(newValue)
                    }

                Button {
                    manager.requestCurrentLocation()
                } label: {
                    HStack {
                        Text(manager.isLoadingCurrentLocation ? "Getting Current Location..." : "Use Current Location")
                        Spacer()
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(.white.opacity(0.08))
                    )
                }
                .buttonStyle(.plain)

                if let errorMessage = manager.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                List {
                    ForEach(manager.completions, id: \.self) { completion in
                        Button {
                            Task {
                                await manager.useCompletion(completion)

                                if !manager.composedLocationText.isEmpty {
                                    onPick(
                                        manager.composedLocationText,
                                        manager.selectedLatitude,
                                        manager.selectedLongitude
                                    )
                                    dismiss()
                                }
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(completion.title)
                                if !completion.subtitle.isEmpty {
                                    Text(completion.subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)

                if !manager.selectedTitle.isEmpty {
                    Button("Use Selected Location") {
                        onPick(
                            manager.composedLocationText,
                            manager.selectedLatitude,
                            manager.selectedLongitude
                        )
                        dismiss()
                    }
                    .padding(.top, 4)
                }
            }
            .padding()
            .navigationTitle("Pick Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onReceive(lystariaUseCurrentLocationNotification) { _ in
                manager.requestCurrentLocation()
            }
            .onChange(of: manager.composedLocationText) { _, newValue in
                guard !newValue.isEmpty else { return }

                if manager.selectedLatitude != nil || manager.selectedLongitude != nil {
                    onPick(
                        newValue,
                        manager.selectedLatitude,
                        manager.selectedLongitude
                    )
                    dismiss()
                }
              }
            }
            .onChange(of: manager.composedLocationText) { _, newValue in
                guard !newValue.isEmpty else { return }

                if manager.selectedLatitude != nil || manager.selectedLongitude != nil {
                    onPick(
                        newValue,
                        manager.selectedLatitude,
                        manager.selectedLongitude
                    )
                    dismiss()
                }
            }
        }
    }
