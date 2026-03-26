//
//  ParticipatingStores.swift
//  RSD Helper
//
//  Created by David Strauss on 1/31/18.
//  Copyright © 2018 David Strauss. All rights reserved.
//

import Combine
import Contacts
import CoreLocation
import Foundation
import MapKit

struct ResolvedStoreCoordinate: Codable, Hashable {
    let latitude: Double
    let longitude: Double

    var clLocationCoordinate2D: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

struct ParticipatingStoreRecord: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let city: String
    let state: String
    let postalCode: String
    let country: String
    let latitude: Double?
    let longitude: Double?
    let websiteURL: String
    let googleMapsQuery: String
    let viewURL: String
    let phone: String
    let email: String

    var hasCoordinates: Bool {
        latitude != nil && longitude != nil
    }

    var coordinate: CLLocationCoordinate2D? {
        guard let latitude, let longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    var subtitle: String {
        [city, state, country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    var formattedAddress: String {
        let postalAddress = CNMutablePostalAddress()
        postalAddress.street = address
        postalAddress.city = city
        postalAddress.state = state
        postalAddress.postalCode = postalCode
        postalAddress.country = country

        let formatted = CNPostalAddressFormatter.string(from: postalAddress, style: .mailingAddress)
            .replacingOccurrences(of: "\n", with: ", ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if formatted.isEmpty == false {
            return formatted
        }

        let lineOne = address
        let lineTwo = [city, state, postalCode].filter { !$0.isEmpty }.joined(separator: " ")
        return [lineOne, lineTwo].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    var contactSummary: String {
        [phone, email, websiteURL].filter { !$0.isEmpty }.joined(separator: "\n")
    }

    var displayName: String {
        name.isEmpty ? "Record Store" : name
    }

    var normalizedWebsiteURL: URL? {
        guard websiteURL.isEmpty == false else { return nil }
        if let url = URL(string: websiteURL), url.scheme != nil {
            return url
        }
        return URL(string: "https://\(websiteURL)")
    }

    var normalizedPhoneNumber: String? {
        let digits = phone.replacingOccurrences(of: "[^0-9+]", with: "", options: .regularExpression)
        return digits.isEmpty ? nil : digits
    }

    var phoneURL: URL? {
        guard let normalizedPhoneNumber,
              let encoded = normalizedPhoneNumber.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return nil
        }
        return URL(string: "tel://\(encoded)")
    }

    func mapItem() -> MKMapItem {
        let postalAddress = CNMutablePostalAddress()
        postalAddress.street = address
        postalAddress.city = city
        postalAddress.state = state
        postalAddress.postalCode = postalCode
        postalAddress.country = country

        let placemark: MKPlacemark
        if let coordinate {
            placemark = MKPlacemark(coordinate: coordinate, postalAddress: postalAddress)
        } else {
            placemark = MKPlacemark(coordinate: kCLLocationCoordinate2DInvalid, postalAddress: postalAddress)
        }
        let item = MKMapItem(placemark: placemark)
        item.name = displayName
        return item
    }
}

private struct ParticipatingStoreDocument: Codable {
    let schemaVersion: Int
    let stores: [ParticipatingStoreRecord]
}

final class ParticipatingStore: NSObject, MKAnnotation {
    let record: ParticipatingStoreRecord
    private let resolvedCoordinate: CLLocationCoordinate2D

    init(record: ParticipatingStoreRecord, coordinate: CLLocationCoordinate2D) {
        self.record = record
        self.resolvedCoordinate = coordinate
    }

    var coordinate: CLLocationCoordinate2D {
        resolvedCoordinate
    }
    var title: String? { record.displayName }
    var subtitle: String? { record.subtitle }
}

enum ParticipatingStoreLoader {
    static func loadBundledStores() throws -> [ParticipatingStoreRecord] {
        guard let url = Bundle.main.url(forResource: "stores-2026", withExtension: "json") else {
            throw NSError(domain: "RSDHelper.StoreLoader", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Could not find stores-2026.json in the app bundle."
            ])
        }

        let data = try Data(contentsOf: url)
        let document = try JSONDecoder().decode(ParticipatingStoreDocument.self, from: data)
        return document.stores.sorted {
            if $0.state != $1.state {
                return $0.state.localizedCaseInsensitiveCompare($1.state) == .orderedAscending
            }
            if $0.city != $1.city {
                return $0.city.localizedCaseInsensitiveCompare($1.city) == .orderedAscending
            }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }
}

final class ResolvedStoreCoordinateStore: ObservableObject {
    static let shared = ResolvedStoreCoordinateStore()

    @Published private(set) var coordinatesByStoreID: [String: ResolvedStoreCoordinate] = [:]

    private let defaults = UserDefaults.standard
    private let storageKey = "resolved_store_coordinates_v1"

    private init() {
        coordinatesByStoreID = load()
    }

    func coordinate(for store: ParticipatingStoreRecord) -> CLLocationCoordinate2D? {
        if let coordinate = store.coordinate {
            return coordinate
        }
        return coordinatesByStoreID[store.id]?.clLocationCoordinate2D
    }

    func hasCoordinate(for store: ParticipatingStoreRecord) -> Bool {
        coordinate(for: store) != nil
    }

    func save(_ coordinate: CLLocationCoordinate2D, for storeID: String) {
        coordinatesByStoreID[storeID] = ResolvedStoreCoordinate(latitude: coordinate.latitude, longitude: coordinate.longitude)
        persist()
    }

    private func load() -> [String: ResolvedStoreCoordinate] {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: ResolvedStoreCoordinate].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(coordinatesByStoreID) else { return }
        defaults.set(data, forKey: storageKey)
    }
}

final class SelectedStoreStore: ObservableObject {
    static let shared = SelectedStoreStore()

    @Published private(set) var selectedStore: ParticipatingStoreRecord?

    private let defaults = UserDefaults.standard
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let storageKey = "selected_store_v1"

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUbiquitousStoreChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )
        ubiquitousStore.synchronize()
        selectedStore = decodeStore(from: defaults.dictionary(forKey: storageKey))
            ?? decodeStore(from: ubiquitousStore.dictionary(forKey: storageKey))
        persist()
    }

    func select(_ store: ParticipatingStoreRecord) {
        guard selectedStore != store else { return }
        selectedStore = store
        persist()
    }

    func clear() {
        guard selectedStore != nil else { return }
        selectedStore = nil
        defaults.removeObject(forKey: storageKey)
        ubiquitousStore.removeObject(forKey: storageKey)
        ubiquitousStore.synchronize()
    }

    private func persist() {
        let payload = selectedStore.flatMap(encodeStore)
        defaults.set(payload, forKey: storageKey)
        ubiquitousStore.set(payload, forKey: storageKey)
        ubiquitousStore.synchronize()
    }

    private func encodeStore(_ store: ParticipatingStoreRecord) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(store),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private func decodeStore(from dictionary: [String: Any]?) -> ParticipatingStoreRecord? {
        guard let dictionary else { return nil }
        guard let data = try? JSONSerialization.data(withJSONObject: dictionary),
              let store = try? JSONDecoder().decode(ParticipatingStoreRecord.self, from: data) else {
            return nil
        }
        return store
    }

    @objc private func handleUbiquitousStoreChange(_ notification: Notification) {
        let cloudStore = decodeStore(from: ubiquitousStore.dictionary(forKey: storageKey))
        guard cloudStore != selectedStore else { return }
        selectedStore = cloudStore
        if let payload = cloudStore.flatMap(encodeStore) {
            defaults.set(payload, forKey: storageKey)
        } else {
            defaults.removeObject(forKey: storageKey)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
