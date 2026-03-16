//
//  LocationPickerManager.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/14/26.
//

import Foundation
import Combine
import CoreLocation
import MapKit

@MainActor
final class LocationPickerManager: NSObject, ObservableObject {
    @Published var searchText: String = ""
    @Published var completions: [MKLocalSearchCompletion] = []
    @Published var selectedTitle: String = ""
    @Published var selectedSubtitle: String = ""
    @Published var selectedLatitude: Double?
    @Published var selectedLongitude: Double?
    @Published var isLoadingCurrentLocation: Bool = false
    @Published var errorMessage: String?

    private let locationManager = CLLocationManager()
    private let completer = MKLocalSearchCompleter()

    private var pendingCurrentLocationRequest = false

    override init() {
        super.init()

        locationManager.delegate = self

        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }

    func updateSearch(_ text: String) {
        searchText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil

        guard !searchText.isEmpty else {
            completions = []
            return
        }

        completer.queryFragment = searchText
    }

    func requestCurrentLocation() {
        errorMessage = nil
        pendingCurrentLocationRequest = true
        isLoadingCurrentLocation = true

        let status = locationManager.authorizationStatus

        switch status {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()

        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()

        case .denied, .restricted:
            isLoadingCurrentLocation = false
            pendingCurrentLocationRequest = false
            errorMessage = "Location access is unavailable."

        @unknown default:
            isLoadingCurrentLocation = false
            pendingCurrentLocationRequest = false
            errorMessage = "Location access is unavailable."
        }
    }

    func useCompletion(_ completion: MKLocalSearchCompletion) async {
        errorMessage = nil

        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()

            guard let item = response.mapItems.first else {
                errorMessage = "No place result was found."
                return
            }

            applyMapItem(item)
        } catch {
            errorMessage = "Unable to load that place."
        }
    }

    private func reverseGeocode(_ location: CLLocation) {
        Task { @MainActor in
            do {
                guard let request = MKReverseGeocodingRequest(location: location) else {
                    self.isLoadingCurrentLocation = false
                    self.pendingCurrentLocationRequest = false
                    self.errorMessage = "Unable to create a reverse geocoding request."
                    return
                }

                let mapItems = try await request.mapItems

                guard let item = mapItems.first else {
                    self.isLoadingCurrentLocation = false
                    self.pendingCurrentLocationRequest = false
                    self.errorMessage = "No placemark was found for your location."
                    return
                }

                self.isLoadingCurrentLocation = false
                self.pendingCurrentLocationRequest = false

                let address = item.address
                let name = item.name ?? address?.shortAddress ?? "Current Location"
                let subtitle = address?.fullAddress ?? ""

                self.selectedTitle = name
                self.selectedSubtitle = subtitle
                self.selectedLatitude = location.coordinate.latitude
                self.selectedLongitude = location.coordinate.longitude

                self.searchText = self.composedLocationText
                self.completions = []

            } catch {
                self.isLoadingCurrentLocation = false
                self.pendingCurrentLocationRequest = false
                self.errorMessage = "Unable to turn your current location into a place."
            }
        }
    }

    private func applyMapItem(_ item: MKMapItem) {
        let address = item.address
        let location = item.location

        let titleCandidates: [String?] = [
            item.name,
            address?.shortAddress,
            address?.fullAddress
        ]
        let title = titleCandidates
            .compactMap { value -> String? in
                guard let value, !value.isEmpty else { return nil }
                return value
            }
            .first ?? "Selected Place"

        let subtitle = address?.fullAddress ?? ""

        selectedTitle = title
        selectedSubtitle = subtitle == title ? "" : subtitle
        selectedLatitude = location.coordinate.latitude
        selectedLongitude = location.coordinate.longitude
        searchText = composedLocationText
        completions = []
    }

    var composedLocationText: String {
        if selectedSubtitle.isEmpty {
            return selectedTitle
        }
        return "\(selectedTitle) — \(selectedSubtitle)"
    }

    func clearSelection() {
        selectedTitle = ""
        selectedSubtitle = ""
        selectedLatitude = nil
        selectedLongitude = nil
        errorMessage = nil
    }
}

extension LocationPickerManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard pendingCurrentLocationRequest else { return }

        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()

        case .denied, .restricted:
            isLoadingCurrentLocation = false
            pendingCurrentLocationRequest = false
            errorMessage = "Location access is unavailable."

        case .notDetermined:
            break

        @unknown default:
            isLoadingCurrentLocation = false
            pendingCurrentLocationRequest = false
            errorMessage = "Location access is unavailable."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else {
            isLoadingCurrentLocation = false
            pendingCurrentLocationRequest = false
            errorMessage = "No current location was returned."
            return
        }

        reverseGeocode(location)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoadingCurrentLocation = false
        pendingCurrentLocationRequest = false
        errorMessage = "Unable to get your current location."
    }
}

extension LocationPickerManager: MKLocalSearchCompleterDelegate {
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        completions = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        errorMessage = "Place suggestions could not be loaded."
    }
}
