//
//  RSDStoreMapViewController.swift
//  RSD Helper
//
//  Created by David Strauss on 1/31/18.
//  Copyright © 2018 David Strauss. All rights reserved.
//

import SwiftUI
import UIKit
import MapKit
import CoreLocation
import Combine

private let regionAbbreviations: [String: String] = [
    "Alberta": "AB",
    "British Columbia": "BC",
    "Manitoba": "MB",
    "New Brunswick": "NB",
    "Newfoundland and Labrador": "NL",
    "Nova Scotia": "NS",
    "Ontario": "ON",
    "Prince Edward Island": "PE",
    "Québec": "QC",
    "Quebec": "QC",
    "Saskatchewan": "SK",
    "Yukon": "YT",
    "Northwest Territories": "NT",
    "Nunavut": "NU",
]

private final class StoreListCell: UITableViewCell {
    static let reuseIdentifier = "StoreListCell"

    private let nameLabel = UILabel()
    private let addressLabel = UILabel()
    private let metaLabel = UILabel()
    private let actionRow = UIStackView()
    private let favoriteButton = UIButton(type: .system)
    private let directionsButton = UIButton(type: .system)
    private let callButton = UIButton(type: .system)
    private let websiteButton = UIButton(type: .system)

    var onFavorite: (() -> Void)?
    var onDirections: (() -> Void)?
    var onCall: (() -> Void)?
    var onWebsite: (() -> Void)?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        selectionStyle = .none
        backgroundColor = .clear

        nameLabel.font = .preferredFont(forTextStyle: .headline)
        nameLabel.numberOfLines = 0

        addressLabel.font = .preferredFont(forTextStyle: .subheadline)
        addressLabel.textColor = .secondaryLabel
        addressLabel.numberOfLines = 0

        metaLabel.font = .preferredFont(forTextStyle: .footnote)
        metaLabel.textColor = .tertiaryLabel
        metaLabel.numberOfLines = 0

        configureActionButton(favoriteButton, systemName: "star.fill")
        configureActionButton(directionsButton, systemName: "map.fill")
        configureActionButton(callButton, systemName: "phone.fill")
        configureActionButton(websiteButton, systemName: "safari.fill")

        favoriteButton.addTarget(self, action: #selector(handleFavorite), for: .touchUpInside)
        directionsButton.addTarget(self, action: #selector(handleDirections), for: .touchUpInside)
        callButton.addTarget(self, action: #selector(handleCall), for: .touchUpInside)
        websiteButton.addTarget(self, action: #selector(handleWebsite), for: .touchUpInside)

        actionRow.axis = .horizontal
        actionRow.spacing = 8
        actionRow.alignment = .fill
        actionRow.distribution = .fillEqually
        actionRow.addArrangedSubview(favoriteButton)
        actionRow.addArrangedSubview(directionsButton)
        actionRow.addArrangedSubview(callButton)
        actionRow.addArrangedSubview(websiteButton)

        let stack = UIStackView(arrangedSubviews: [nameLabel, addressLabel, metaLabel, actionRow])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -14),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with store: ParticipatingStoreRecord, metaText: String?, isSelected: Bool, isHighlighted: Bool) {
        nameLabel.text = store.displayName

        addressLabel.text = store.formattedAddress

        metaLabel.text = metaText
        metaLabel.isHidden = metaText?.isEmpty != false
        favoriteButton.tintColor = isSelected ? .systemGreen : tintColor
        favoriteButton.backgroundColor = isSelected ? UIColor.systemGreen.withAlphaComponent(0.14) : UIColor.secondarySystemFill
        favoriteButton.accessibilityLabel = isSelected ? "Clear Favorite" : "Set As Favorite"
        directionsButton.isHidden = false
        callButton.isHidden = store.phoneURL == nil
        websiteButton.isHidden = store.normalizedWebsiteURL == nil
        contentView.backgroundColor = isHighlighted ? UIColor.systemFill.withAlphaComponent(0.45) : .clear
        contentView.layer.cornerRadius = 14
        contentView.layer.masksToBounds = true
    }

    private func configureActionButton(_ button: UIButton, systemName: String) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = tintColor
        button.backgroundColor = .secondarySystemFill
        button.layer.cornerRadius = 16
        button.clipsToBounds = true
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 32),
            button.heightAnchor.constraint(equalToConstant: 32),
        ])
    }

    @objc private func handleFavorite() {
        onFavorite?()
    }

    @objc private func handleDirections() {
        onDirections?()
    }

    @objc private func handleCall() {
        onCall?()
    }

    @objc private func handleWebsite() {
        onWebsite?()
    }
}

final class RSDStoreMapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate {
    private enum StorageKey {
        static let mapType = "stores_map_type"
    }

    private let mapView = MKMapView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let resolvedCoordinateStore = ResolvedStoreCoordinateStore.shared
    private let distanceFormatter = MKDistanceFormatter()
    private let defaults = UserDefaults.standard
    private var allStores = [ParticipatingStoreRecord]()
    private var filteredStores = [ParticipatingStoreRecord]()
    private var pinnedStores = [ParticipatingStore]()
    private var currentUserLocation: CLLocation?
    private var cancellables = Set<AnyCancellable>()
    private let regionRadius: CLLocationDistance = 50_000
    private var pendingGeocodeStoreIDs = Set<String>()
    private var geocodeTask: Task<Void, Never>?
    private var highlightedStoreID: String?
    private var refreshAnnotationsWorkItem: DispatchWorkItem?

    private let selectedStoreCard = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let selectedStoreBadgeLabel = UILabel()
    private let selectedStoreTitleLabel = UILabel()
    private let selectedStoreSubtitleLabel = UILabel()
    private let clearSelectionButton = UIButton(type: .system)
    private let mapControlsView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterial))
    private let currentLocationButton = UIButton(type: .system)
    private let mapTypeButton = UIButton(type: .system)
    private let favoriteStoreButton = UIButton(type: .system)

    private let sheetView = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterial))
    private let grabberView = UIView()
    private let sheetTitleLabel = UILabel()
    private let sheetCountLabel = UILabel()
    private let searchBar = UISearchBar()
    private var sheetHeightConstraint: NSLayoutConstraint?
    private let collapsedHeight: CGFloat = 196
    private let expandedHeight: CGFloat = 520
    private var currentSheetHeight: CGFloat = 240
    private var sheetPanStartHeight: CGFloat = 240

    private var onMapStores: [ParticipatingStoreRecord] {
        let visibleStores = filteredStores.filter { store in
            hasPin(for: store) && isVisibleOnMap(store)
        }
        guard let favoriteID = SelectedStoreStore.shared.selectedStore?.id,
              let favoriteIndex = visibleStores.firstIndex(where: { $0.id == favoriteID }) else {
            return visibleStores
        }
        var reordered = visibleStores
        let favoriteStore = reordered.remove(at: favoriteIndex)
        reordered.insert(favoriteStore, at: 0)
        return reordered
    }

    private func isVisibleOnMap(_ store: ParticipatingStoreRecord) -> Bool {
        guard let coordinate = effectiveCoordinate(for: store) else { return false }
        let visibleRect = mapView.visibleMapRect
        guard visibleRect.isNull == false, visibleRect.isEmpty == false else { return true }
        return visibleRect.contains(MKMapPoint(coordinate))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = ""
        navigationItem.largeTitleDisplayMode = .always
        view.backgroundColor = .systemBackground

        mapView.translatesAutoresizingMaskIntoConstraints = false
        mapView.delegate = self
        mapView.showsUserLocation = true
        view.addSubview(mapView)

        selectedStoreCard.translatesAutoresizingMaskIntoConstraints = false
        selectedStoreCard.layer.cornerRadius = 18
        selectedStoreCard.clipsToBounds = true
        selectedStoreCard.isHidden = true
        view.addSubview(selectedStoreCard)

        selectedStoreBadgeLabel.font = .preferredFont(forTextStyle: .caption1).withWeight(.semibold)
        selectedStoreBadgeLabel.textColor = .systemGreen
        selectedStoreBadgeLabel.text = "Favorite Store"

        selectedStoreTitleLabel.font = .preferredFont(forTextStyle: .headline)
        selectedStoreTitleLabel.numberOfLines = 2
        selectedStoreSubtitleLabel.font = .preferredFont(forTextStyle: .subheadline)
        selectedStoreSubtitleLabel.textColor = .secondaryLabel
        selectedStoreSubtitleLabel.numberOfLines = 2
        clearSelectionButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearSelectionButton.tintColor = .tertiaryLabel
        clearSelectionButton.addTarget(self, action: #selector(clearSelectedStore), for: .touchUpInside)

        let selectedTextStack = UIStackView(arrangedSubviews: [selectedStoreBadgeLabel, selectedStoreTitleLabel, selectedStoreSubtitleLabel])
        selectedTextStack.axis = .vertical
        selectedTextStack.spacing = 3

        let selectedRow = UIStackView(arrangedSubviews: [selectedTextStack, clearSelectionButton])
        selectedRow.axis = .horizontal
        selectedRow.spacing = 12
        selectedRow.alignment = .top
        selectedRow.translatesAutoresizingMaskIntoConstraints = false
        selectedStoreCard.contentView.addSubview(selectedRow)
        let cardTap = UITapGestureRecognizer(target: self, action: #selector(handleSelectedStoreCardTap))
        selectedStoreCard.contentView.addGestureRecognizer(cardTap)
        selectedStoreCard.contentView.isUserInteractionEnabled = true

        mapControlsView.translatesAutoresizingMaskIntoConstraints = false
        mapControlsView.layer.cornerRadius = 18
        mapControlsView.clipsToBounds = true
        view.addSubview(mapControlsView)

        configureMapControlButton(currentLocationButton, systemName: "location.fill", action: #selector(centerOnCurrentLocation))
        configureMapControlButton(mapTypeButton, systemName: "map.fill", action: #selector(toggleMapType))
        configureMapControlButton(favoriteStoreButton, systemName: "star.fill", action: #selector(jumpToFavoriteStore))

        let controlsStack = UIStackView(arrangedSubviews: [currentLocationButton, mapTypeButton, favoriteStoreButton])
        controlsStack.axis = .vertical
        controlsStack.spacing = 8
        controlsStack.translatesAutoresizingMaskIntoConstraints = false
        mapControlsView.contentView.addSubview(controlsStack)

        sheetView.translatesAutoresizingMaskIntoConstraints = false
        sheetView.layer.cornerRadius = 28
        sheetView.clipsToBounds = true
        view.addSubview(sheetView)

        grabberView.translatesAutoresizingMaskIntoConstraints = false
        grabberView.backgroundColor = .tertiaryLabel.withAlphaComponent(0.45)
        grabberView.layer.cornerRadius = 3

        sheetTitleLabel.font = .preferredFont(forTextStyle: .title2).withWeight(.bold)
        sheetTitleLabel.text = "Participating Stores"
        sheetTitleLabel.numberOfLines = 1

        sheetCountLabel.font = .preferredFont(forTextStyle: .footnote)
        sheetCountLabel.textColor = .secondaryLabel
        sheetCountLabel.numberOfLines = 0

        searchBar.placeholder = "Search stores, cities, countries"
        searchBar.searchBarStyle = .minimal
        searchBar.delegate = self
        searchBar.showsCancelButton = false

        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(StoreListCell.self, forCellReuseIdentifier: StoreListCell.reuseIdentifier)
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .onDrag
        tableView.contentInset.bottom = 24

        let titleTextStack = UIStackView(arrangedSubviews: [sheetTitleLabel, sheetCountLabel])
        titleTextStack.axis = .vertical
        titleTextStack.spacing = 2
        titleTextStack.alignment = .leading

        let titleRow = UIStackView(arrangedSubviews: [titleTextStack, UIView()])
        titleRow.axis = .horizontal
        titleRow.alignment = .top
        titleRow.isLayoutMarginsRelativeArrangement = true
        titleRow.layoutMargins = UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)

        let headerStack = UIStackView(arrangedSubviews: [grabberView, titleRow])
        headerStack.axis = .vertical
        headerStack.spacing = 12
        headerStack.alignment = .center
        headerStack.translatesAutoresizingMaskIntoConstraints = false

        let sheetStack = UIStackView(arrangedSubviews: [headerStack, searchBar, tableView])
        sheetStack.axis = .vertical
        sheetStack.spacing = 12
        sheetStack.translatesAutoresizingMaskIntoConstraints = false
        sheetView.contentView.addSubview(sheetStack)

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(handleSheetPan(_:)))
        headerStack.isUserInteractionEnabled = true
        headerStack.addGestureRecognizer(panGesture)

        let mapTapGesture = UITapGestureRecognizer(target: self, action: #selector(handleMapTap))
        mapTapGesture.cancelsTouchesInView = false
        mapView.addGestureRecognizer(mapTapGesture)

        NSLayoutConstraint.activate([
            mapView.topAnchor.constraint(equalTo: view.topAnchor),
            mapView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mapView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mapView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            selectedStoreCard.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 28),
            selectedStoreCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            selectedStoreCard.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -16),

            mapControlsView.topAnchor.constraint(equalTo: selectedStoreCard.topAnchor),
            mapControlsView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            selectedRow.topAnchor.constraint(equalTo: selectedStoreCard.contentView.topAnchor, constant: 12),
            selectedRow.leadingAnchor.constraint(equalTo: selectedStoreCard.contentView.leadingAnchor, constant: 12),
            selectedRow.trailingAnchor.constraint(equalTo: selectedStoreCard.contentView.trailingAnchor, constant: -12),
            selectedRow.bottomAnchor.constraint(equalTo: selectedStoreCard.contentView.bottomAnchor, constant: -12),

            controlsStack.topAnchor.constraint(equalTo: mapControlsView.contentView.topAnchor, constant: 10),
            controlsStack.leadingAnchor.constraint(equalTo: mapControlsView.contentView.leadingAnchor, constant: 10),
            controlsStack.trailingAnchor.constraint(equalTo: mapControlsView.contentView.trailingAnchor, constant: -10),
            controlsStack.bottomAnchor.constraint(equalTo: mapControlsView.contentView.bottomAnchor, constant: -10),

            sheetView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            sheetView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -8),
            sheetView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: 8),

            grabberView.heightAnchor.constraint(equalToConstant: 6),
            grabberView.widthAnchor.constraint(equalToConstant: 48),

            sheetStack.topAnchor.constraint(equalTo: sheetView.contentView.topAnchor, constant: 10),
            sheetStack.leadingAnchor.constraint(equalTo: sheetView.contentView.leadingAnchor, constant: 12),
            sheetStack.trailingAnchor.constraint(equalTo: sheetView.contentView.trailingAnchor, constant: -12),
            sheetStack.bottomAnchor.constraint(equalTo: sheetView.contentView.bottomAnchor, constant: -12),
        ])

        sheetHeightConstraint = sheetView.heightAnchor.constraint(equalToConstant: collapsedHeight)
        sheetHeightConstraint?.isActive = true
        currentSheetHeight = collapsedHeight

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        applySavedMapType()

        SelectedStoreStore.shared.$selectedStore
            .receive(on: DispatchQueue.main)
            .sink { [weak self] store in
                self?.updateSelectedStoreCard(with: store)
                self?.refreshAnnotationViews()
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        resolvedCoordinateStore.$coordinatesByStoreID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.schedulePinnedStoreRefresh()
                self?.updateCountLabel()
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)

        requestLocation()
        loadStores()
    }

    private func requestLocation() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            locationManager.startUpdatingLocation()
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    private func configureMapControlButton(_ button: UIButton, systemName: String, action: Selector) {
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setImage(UIImage(systemName: systemName), for: .normal)
        button.tintColor = .label
        button.backgroundColor = .secondarySystemBackground.withAlphaComponent(0.7)
        button.layer.cornerRadius = 20
        button.clipsToBounds = true
        button.addTarget(self, action: action, for: .touchUpInside)
        NSLayoutConstraint.activate([
            button.widthAnchor.constraint(equalToConstant: 40),
            button.heightAnchor.constraint(equalToConstant: 40),
        ])
    }

    private func loadStores() {
        do {
            allStores = try ParticipatingStoreLoader.loadBundledStores()
            filteredStores = allStores
            refreshPinnedStores()
            updateCountLabel()
            tableView.reloadData()
            beginResolvingMissingCoordinates(for: allStores)

            if let selected = SelectedStoreStore.shared.selectedStore {
                revealStore(selected, animated: false)
            }
        } catch {
            sheetCountLabel.text = error.localizedDescription
        }
    }

    private func refreshPinnedStores() {
        let nextPinnedStores = filteredStores
            .filter(hasPin(for:))
            .compactMap { store in
                effectiveCoordinate(for: store).map { ParticipatingStore(record: store, coordinate: $0) }
            }

        let existingAnnotations = mapView.annotations.compactMap { $0 as? ParticipatingStore }
        let existingByID = Dictionary(uniqueKeysWithValues: existingAnnotations.map { ($0.record.id, $0) })
        let nextByID = Dictionary(uniqueKeysWithValues: nextPinnedStores.map { ($0.record.id, $0) })

        let removed = existingAnnotations.filter { nextByID[$0.record.id] == nil }
        let added = nextPinnedStores.filter { existingByID[$0.record.id] == nil }

        pinnedStores = nextPinnedStores

        if removed.isEmpty == false {
            mapView.removeAnnotations(removed)
        }
        if added.isEmpty == false {
            mapView.addAnnotations(added)
        }
        refreshAnnotationViews()
    }

    private func schedulePinnedStoreRefresh() {
        refreshAnnotationsWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.refreshPinnedStores()
        }
        refreshAnnotationsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18, execute: workItem)
    }

    private func filterStores(with query: String) {
        let normalized = query.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        if normalized.isEmpty {
            filteredStores = allStores
        } else {
            filteredStores = allStores.filter { store in
                [
                    store.displayName,
                    store.formattedAddress,
                    store.city,
                    store.state,
                    store.country,
                    store.websiteURL,
                    store.phone,
                    store.email,
                ]
                .joined(separator: " ")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(normalized)
            }
        }
        refreshPinnedStores()
        updateMapRegionForSearchResults(animated: normalized.isEmpty == false)
        updateCountLabel()
        tableView.reloadData()
        beginResolvingMissingCoordinates(for: filteredStores)
    }

    private func updateMapRegionForSearchResults(animated: Bool) {
        let visibleCandidates = filteredStores.compactMap { store -> (ParticipatingStoreRecord, CLLocationCoordinate2D)? in
            guard let coordinate = effectiveCoordinate(for: store) else { return nil }
            return (store, coordinate)
        }

        guard visibleCandidates.isEmpty == false else { return }

        if visibleCandidates.count == 1, let coordinate = visibleCandidates.first?.1 {
            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 18_000,
                longitudinalMeters: 18_000
            )
            mapView.setRegion(region, animated: animated)
            return
        }

        var rect = MKMapRect.null
        for (_, coordinate) in visibleCandidates {
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
            rect = rect.isNull ? pointRect : rect.union(pointRect)
        }

        guard rect.isNull == false else { return }
        let padded = rect.insetBy(dx: -rect.size.width * 0.18 - 12000, dy: -rect.size.height * 0.22 - 12000)
        mapView.setVisibleMapRect(
            padded,
            edgePadding: UIEdgeInsets(top: 110, left: 32, bottom: currentSheetHeight + 32, right: 32),
            animated: animated
        )
    }

    @objc private func centerOnCurrentLocation() {
        requestLocation()
        guard let currentUserLocation else { return }
        let region = MKCoordinateRegion(
            center: currentUserLocation.coordinate,
            latitudinalMeters: regionRadius,
            longitudinalMeters: regionRadius
        )
        mapView.setRegion(region, animated: true)
    }

    @objc private func toggleMapType() {
        switch mapView.mapType {
        case .standard:
            updateMapType(.mutedStandard)
        case .mutedStandard:
            updateMapType(.hybrid)
        case .hybrid:
            updateMapType(.satellite)
        default:
            updateMapType(.standard)
        }
    }

    private func applySavedMapType() {
        let rawValue = defaults.integer(forKey: StorageKey.mapType)
        let savedType = MKMapType(rawValue: UInt(rawValue)) ?? .standard
        updateMapType(savedType, persist: false)
    }

    private func updateMapType(_ mapType: MKMapType, persist: Bool = true) {
        mapView.mapType = mapType
        mapTypeButton.setImage(UIImage(systemName: mapTypeSymbolName(for: mapType)), for: .normal)
        if persist {
            defaults.set(Int(mapType.rawValue), forKey: StorageKey.mapType)
        }
    }

    private func mapTypeSymbolName(for mapType: MKMapType) -> String {
        switch mapType {
        case .standard:
            return "map.fill"
        case .mutedStandard:
            return "map.circle.fill"
        case .hybrid:
            return "globe.americas.fill"
        case .satellite:
            return "sparkles"
        default:
            return "map.fill"
        }
    }

    @objc private func jumpToFavoriteStore() {
        guard let store = SelectedStoreStore.shared.selectedStore else { return }
        highlightStore(store, animated: true)
    }

    private func updateCountLabel() {
        sheetCountLabel.text = "\(onMapStores.count) stores on map"
    }

    private func updateSelectedStoreCard(with store: ParticipatingStoreRecord?) {
        guard let store else {
            selectedStoreCard.isHidden = true
            selectedStoreBadgeLabel.text = nil
            selectedStoreTitleLabel.text = nil
            selectedStoreSubtitleLabel.text = nil
            return
        }

        selectedStoreCard.isHidden = false
        selectedStoreBadgeLabel.text = "Favorite Store"
        selectedStoreTitleLabel.text = store.displayName
        let locationLine = [store.city, abbreviatedRegion(store.state)]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        let distanceLine = distanceText(for: store)
        let primaryLocation = locationLine.isEmpty ? store.country : locationLine
        selectedStoreSubtitleLabel.text = [primaryLocation, distanceLine]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " • ")
    }

    private func distanceText(for store: ParticipatingStoreRecord) -> String? {
        guard let currentUserLocation,
              let coordinate = effectiveCoordinate(for: store) else {
            return nil
        }
        let destination = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let distanceInMeters = currentUserLocation.distance(from: destination)
        distanceFormatter.unitStyle = .abbreviated
        return distanceFormatter.string(fromDistance: distanceInMeters)
    }

    private func abbreviatedRegion(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "" }
        if trimmed.count <= 3 {
            return trimmed.uppercased()
        }
        return regionAbbreviations[trimmed] ?? trimmed
    }

    private func refreshAnnotationViews() {
        for annotation in mapView.annotations {
            guard let markerView = mapView.view(for: annotation) as? MKMarkerAnnotationView,
                  let store = annotation as? ParticipatingStore else {
                continue
            }
            configureMarkerAppearance(for: markerView, store: store.record)
        }
    }

    private func configureMarkerAppearance(for view: MKMarkerAnnotationView, store: ParticipatingStoreRecord) {
        let isSelected = SelectedStoreStore.shared.selectedStore?.id == store.id
        view.markerTintColor = isSelected ? .systemGreen : .systemRed
        view.glyphImage = UIImage(systemName: isSelected ? "star.fill" : "opticaldisc.fill")
        view.transform = isSelected ? CGAffineTransform(scaleX: 1.18, y: 1.18) : .identity
        view.displayPriority = isSelected ? .required : .defaultHigh
        if #available(iOS 14.0, *) {
            view.zPriority = isSelected ? .max : .defaultSelected
        }
    }

    private func hasPin(for store: ParticipatingStoreRecord) -> Bool {
        resolvedCoordinateStore.hasCoordinate(for: store)
    }

    private func effectiveCoordinate(for store: ParticipatingStoreRecord) -> CLLocationCoordinate2D? {
        resolvedCoordinateStore.coordinate(for: store)
    }

    private func selectStore(_ store: ParticipatingStoreRecord) {
        SelectedStoreStore.shared.select(store)
        revealStore(store, animated: true)
    }

    private func highlightStore(_ store: ParticipatingStoreRecord, animated: Bool) {
        highlightedStoreID = store.id
        tableView.reloadData()
        revealStore(store, animated: animated)
    }

    private func revealStore(_ store: ParticipatingStoreRecord, animated: Bool) {
        if let row = onMapStores.firstIndex(where: { $0.id == store.id }) {
            let indexPath = IndexPath(row: row, section: 0)
            tableView.scrollToRow(at: indexPath, at: .middle, animated: animated)
            tableView.selectRow(at: indexPath, animated: animated, scrollPosition: .none)
        }
        if let annotation = pinnedStores.first(where: { $0.record.id == store.id }),
           let coordinate = effectiveCoordinate(for: store) {
            if mapView.selectedAnnotations.contains(where: { ($0 as? ParticipatingStore)?.record.id == store.id }) == false {
                mapView.selectAnnotation(annotation, animated: animated)
            }
            let region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 18_000,
                longitudinalMeters: 18_000
            )
            mapView.setRegion(region, animated: animated)
        }
    }

    private func openDirections(for store: ParticipatingStoreRecord) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = geocodeQuery(for: store)
        if let coordinate = effectiveCoordinate(for: store) {
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 12_000,
                longitudinalMeters: 12_000
            )
        }

        let fallbackItem = store.mapItem()

        MKLocalSearch(request: request).start { response, _ in
            if let bestMatch = response?.mapItems.first {
                bestMatch.openInMaps()
                return
            }

            if CLLocationCoordinate2DIsValid(fallbackItem.placemark.coordinate) {
                fallbackItem.openInMaps()
                return
            }

            let query = self.geocodeQuery(for: store)
            guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
                  let url = URL(string: "http://maps.apple.com/?q=\(encoded)") else {
                return
            }
            UIApplication.shared.open(url)
        }
    }

    private func openWebsite(for store: ParticipatingStoreRecord) {
        guard let websiteURL = store.normalizedWebsiteURL else { return }
        UIApplication.shared.open(websiteURL)
    }

    private func callStore(_ store: ParticipatingStoreRecord) {
        guard let phoneURL = store.phoneURL else { return }
        UIApplication.shared.open(phoneURL)
    }

    private func beginResolvingMissingCoordinates(for stores: [ParticipatingStoreRecord]) {
        let candidates = stores.filter { !hasPin(for: $0) && !pendingGeocodeStoreIDs.contains($0.id) }
        guard candidates.isEmpty == false else { return }

        for store in candidates {
            pendingGeocodeStoreIDs.insert(store.id)
        }

        guard geocodeTask == nil else { return }
        geocodeTask = Task { [weak self] in
            await self?.processGeocodeQueue()
        }
    }

    @MainActor
    private func processResolvedCoordinate(_ coordinate: CLLocationCoordinate2D, for store: ParticipatingStoreRecord) {
        resolvedCoordinateStore.save(coordinate, for: store.id)
        if SelectedStoreStore.shared.selectedStore?.id == store.id {
            revealStore(store, animated: true)
        }
    }

    private func geocodeQuery(for store: ParticipatingStoreRecord) -> String {
        if store.googleMapsQuery.isEmpty == false {
            return store.googleMapsQuery
        }
        return [store.displayName, store.formattedAddress, store.country]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func processGeocodeQueue() async {
        while let storeID = pendingGeocodeStoreIDs.first {
            defer { pendingGeocodeStoreIDs.remove(storeID) }

            guard let store = allStores.first(where: { $0.id == storeID }) else {
                continue
            }
            if hasPin(for: store) {
                continue
            }

            let query = geocodeQuery(for: store)
            guard query.isEmpty == false else {
                continue
            }

            do {
                let placemarks = try await geocoder.geocodeAddressString(query)
                if let coordinate = placemarks.first?.location?.coordinate {
                    await MainActor.run {
                        processResolvedCoordinate(coordinate, for: store)
                    }
                }
            } catch {
                continue
            }
        }

        geocodeTask = nil
        if pendingGeocodeStoreIDs.isEmpty == false {
            geocodeTask = Task { [weak self] in
                await self?.processGeocodeQueue()
            }
        }
    }

    @objc private func clearSelectedStore() {
        SelectedStoreStore.shared.clear()
    }

    @objc private func handleSelectedStoreCardTap() {
        guard let store = SelectedStoreStore.shared.selectedStore else { return }
        highlightStore(store, animated: true)
    }

    @objc private func handleSheetPan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        switch gesture.state {
        case .began:
            view.endEditing(true)
            sheetPanStartHeight = sheetHeightConstraint?.constant ?? currentSheetHeight
        case .changed:
            let nextHeight = max(collapsedHeight, min(expandedHeight, sheetPanStartHeight - translation.y))
            sheetHeightConstraint?.constant = nextHeight
            currentSheetHeight = nextHeight
            view.layoutIfNeeded()
        case .ended, .cancelled:
            let velocity = gesture.velocity(in: view).y
            let midpoint = (collapsedHeight + expandedHeight) / 2
            let currentHeight = sheetHeightConstraint?.constant ?? collapsedHeight
            currentSheetHeight = currentHeight
            let expanded = velocity < -200 || (abs(velocity) < 200 && currentHeight > midpoint)
            let target = expanded ? expandedHeight : collapsedHeight
            animateSheet(to: target)
        default:
            break
        }
    }

    private func animateSheet(to height: CGFloat) {
        currentSheetHeight = height
        sheetHeightConstraint?.constant = height
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.9, initialSpringVelocity: 0.6) {
            self.view.layoutIfNeeded()
        }
    }

    @objc private func handleMapTap() {
        view.endEditing(true)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        filterStores(with: searchText)
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
        animateSheet(to: expandedHeight)
    }

    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: true)
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        searchBar.setShowsCancelButton(false, animated: true)
        filterStores(with: "")
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentLocation = locations.last else { return }
        currentUserLocation = currentLocation
        locationManager.stopUpdatingLocation()
        let region = MKCoordinateRegion(
            center: currentLocation.coordinate,
            latitudinalMeters: regionRadius,
            longitudinalMeters: regionRadius
        )
        mapView.setRegion(region, animated: true)
        if let selected = SelectedStoreStore.shared.selectedStore {
            updateSelectedStoreCard(with: selected)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        requestLocation()
    }

    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        updateCountLabel()
        tableView.reloadData()
    }

    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        guard let annotation = annotation as? ParticipatingStore else { return nil }

        let identifier = "store-marker"
        let view = (mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView)
            ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
        view.annotation = annotation
        view.canShowCallout = false
        view.animatesWhenAdded = true
        configureMarkerAppearance(for: view, store: annotation.record)
        return view
    }

    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
        guard let store = (view.annotation as? ParticipatingStore)?.record else { return }
        highlightStore(store, animated: true)
        UIView.animate(withDuration: 0.18) {
            view.transform = CGAffineTransform(scaleX: 1.18, y: 1.18)
        }
    }

    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
        guard let store = (view.annotation as? ParticipatingStore)?.record else { return }
        let shouldStaySelected = SelectedStoreStore.shared.selectedStore?.id == store.id
        UIView.animate(withDuration: 0.18) {
            view.transform = shouldStaySelected ? CGAffineTransform(scaleX: 1.18, y: 1.18) : .identity
        }
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        onMapStores.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        nil
    }

    private func store(at indexPath: IndexPath) -> ParticipatingStoreRecord {
        onMapStores[indexPath.row]
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: StoreListCell.reuseIdentifier, for: indexPath) as! StoreListCell
        let store = store(at: indexPath)
        let isSelected = SelectedStoreStore.shared.selectedStore?.id == store.id
        let isHighlighted = highlightedStoreID == store.id
        let metaParts = [
            isSelected ? "Favorite Store" : nil,
            distanceText(for: store)
        ].compactMap { $0 }
        cell.configure(
            with: store,
            metaText: metaParts.isEmpty ? nil : metaParts.joined(separator: " • "),
            isSelected: isSelected,
            isHighlighted: isHighlighted
        )
        cell.onFavorite = { [weak self] in
            guard let self else { return }
            if isSelected {
                self.clearSelectedStore()
            } else {
                self.selectStore(store)
            }
            self.tableView.reloadData()
        }
        cell.onDirections = { [weak self] in
            self?.openDirections(for: store)
        }
        cell.onCall = { [weak self] in
            self?.callStore(store)
        }
        cell.onWebsite = { [weak self] in
            self?.openWebsite(for: store)
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let store = store(at: indexPath)
        highlightStore(store, animated: true)
    }

    func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        let store = store(at: indexPath)
        return UIContextMenuConfiguration(identifier: store.id as NSString, previewProvider: nil) { [weak self] _ in
            guard let self else { return UIMenu() }
            var actions: [UIMenuElement] = []

            let isFavorite = SelectedStoreStore.shared.selectedStore?.id == store.id
            actions.append(
                UIAction(
                    title: isFavorite ? "Clear Favorite Store" : "Set As Favorite",
                    image: UIImage(systemName: isFavorite ? "star.slash" : "star.fill"),
                    attributes: isFavorite ? .destructive : []
                ) { [weak self] _ in
                    guard let self else { return }
                    if isFavorite {
                        self.clearSelectedStore()
                    } else {
                        self.selectStore(store)
                    }
                    self.tableView.reloadData()
                }
            )

            actions.append(
                UIAction(title: "Directions in Maps", image: UIImage(systemName: "map")) { [weak self] _ in
                    self?.openDirections(for: store)
                }
            )

            if store.phone.isEmpty == false {
                actions.append(
                    UIAction(title: "Call Store", image: UIImage(systemName: "phone")) { [weak self] _ in
                        self?.callStore(store)
                    }
                )
            }

            if store.websiteURL.isEmpty == false {
                actions.append(
                    UIAction(title: "Visit Website", image: UIImage(systemName: "safari")) { [weak self] _ in
                        self?.openWebsite(for: store)
                    }
                )
            }

            return UIMenu(title: store.displayName, children: actions)
        }
    }
}

private extension UIFont {
    func withWeight(_ weight: UIFont.Weight) -> UIFont {
        let descriptor = fontDescriptor.addingAttributes([
            .traits: [UIFontDescriptor.TraitKey.weight: weight]
        ])
        return UIFont(descriptor: descriptor, size: pointSize)
    }
}

struct StoresMapScreen: View {
    @Environment(\.presentationMode) private var presentationMode
    var showsDoneButton: Bool = true

    var body: some View {
        NavigationView {
            StoresMapContainer()
                .ignoresSafeArea()
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.large)
                .toolbarBackground(.hidden, for: .navigationBar)
                .toolbarBackground(.regularMaterial, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbar {
                    if showsDoneButton {
                        SwiftUI.ToolbarItem(placement: .navigationBarTrailing) {
                            SwiftUI.Button("Done") {
                                presentationMode.wrappedValue.dismiss()
                            }
                        }
                    }
                }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

struct StoresMapContainer: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> RSDStoreMapViewController {
        RSDStoreMapViewController()
    }

    func updateUIViewController(_ uiViewController: RSDStoreMapViewController, context: Context) {}
}
