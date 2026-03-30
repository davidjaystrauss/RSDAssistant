//
//  RSDFavoritesViewController.swift
//  RSD Helper
//
//  Created by David Strauss on 4/18/17.
//  Copyright © 2017 David Strauss. All rights reserved.
//

import AVFoundation
import SwiftUI
import UIKit

private struct WishlistSection: Identifiable {
    let list: RSDListDefinition
    let entries: [WishlistedEntry]

    var id: String { list.slug }
}

private enum WishlistExportFormat: String, CaseIterable, Identifiable {
    case pdf
    case csv
    case text

    var id: String { rawValue }

    var label: String {
        rawValue.uppercased()
    }
}

struct FavoritesView: View {
    let list: RSDListDefinition
    var showsDoneButton: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var appState = RSDAppState.shared
    @ObservedObject private var library = ReleaseLibrary.shared
    @ObservedObject private var favoritesStore = FavoritesStore.shared
    @ObservedObject private var releaseStatusStore = ReleaseStatusStore.shared
    @ObservedObject private var selectedStoreStore = SelectedStoreStore.shared
    @Environment(\.presentationMode) private var presentationMode
    @State private var searchText = ""
    @State private var shareDocument: ShareDocument?
    @State private var isPreparingShare = false
    @State private var selectedCoverFlowListing: Listing?
    @State private var wishlistScope: WishlistScope = .currentList
    @State private var editMode: EditMode = .inactive
    @State private var exportPickerPresented = false
    @State private var globalYearFilter = "All Years"
    @State private var globalRegionFilter = "All Regions"
    @State private var globalStatusFilter = "All Statuses"

    private var theme: RSDThemePalette {
        list.theme.palette(for: colorScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscape = geometry.size.width > geometry.size.height
            #if targetEnvironment(macCatalyst)
            let supportsImmersiveCoverFlow = false
            #else
            let supportsImmersiveCoverFlow = true
            #endif
            let isImmersiveCoverFlow = supportsImmersiveCoverFlow && appState.favoritesViewMode == .coverFlow && geometry.size.width > geometry.size.height

            Group {
                if isImmersiveCoverFlow {
                    NavigationStack {
                        favoritesContent(
                            isImmersiveCoverFlow: true,
                            isLandscape: isLandscape,
                            availableWidth: geometry.size.width
                        )
                        .navigationTitle(wishlistNavigationTitle)
                        .navigationBarTitleDisplayMode(.large)
                        .toolbar(.hidden, for: .navigationBar)
                        .tint(theme.tint)
                        .accentColor(theme.tint)
                    }
                } else {
                    NavigationStack {
                        favoritesContent(
                            isImmersiveCoverFlow: false,
                            isLandscape: isLandscape,
                            availableWidth: geometry.size.width
                        )
                        .navigationTitle(wishlistNavigationTitle)
                        .navigationBarTitleDisplayMode(.large)
                        .modifier(FavoritesSearchModifier(isEnabled: true, text: $searchText))
                        .background(
                            WishlistNavigationBarStyleApplier(
                                titleColor: colorScheme == .dark ? .white : .label,
                                tintColor: UIColor(theme.tint)
                            )
                        )
                        .toolbarBackground(theme.navigationBar.opacity(colorScheme == .dark ? 0.92 : 0.98), for: .navigationBar)
                        .toolbarBackground(.visible, for: .navigationBar)
                        .tint(theme.tint)
                        .accentColor(theme.tint)
                        .toolbar(content: toolbarContent)
                        .environment(\.editMode, $editMode)
                    }
                }
            }
        }
        .sheet(item: $shareDocument) { document in
            ActivityShareSheet(activityItems: [document.url])
        }
        .confirmationDialog("Export Wishlist", isPresented: $exportPickerPresented, titleVisibility: .visible) {
            ForEach(WishlistExportFormat.allCases) { format in
                SwiftUI.Button(format.label) {
                    exportWishlist(as: format)
                }
            }
        }
        .sheet(item: $selectedCoverFlowListing) { listing in
            NavigationStack {
                ReleaseDetailView(listing: listing, list: list)
            }
            .tint(theme.tint)
            .accentColor(theme.tint)
        }
        .onChange(of: wishlistScope) { _ in
            globalYearFilter = "All Years"
            globalRegionFilter = "All Regions"
            globalStatusFilter = "All Statuses"
            editMode = .inactive
        }
#if targetEnvironment(macCatalyst)
        .frame(minWidth: 760, idealWidth: 980, maxWidth: .infinity, minHeight: 620, idealHeight: 760, maxHeight: .infinity)
#endif
    }

    private func favoritesContent(
        isImmersiveCoverFlow: Bool,
        isLandscape: Bool,
        availableWidth: CGFloat
    ) -> some View {
        let filteredEntries = filteredWishlistEntries
        let groupedSections = groupedWishlistSections
        let statusLookup = makeStatusLookup(for: filteredEntries)
        let viewMode = effectiveWishlistViewMode
        let isRoomyCanvas = availableWidth >= 820
        let listRowHorizontalInset = isRoomyCanvas ? 24.0 : 16.0
        let listRowVerticalInset = isRoomyCanvas ? 8.0 : 4.0

        return ZStack {
            LinearGradient(
                colors: [theme.backgroundTop, theme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Group {
                if filteredEntries.isEmpty {
                    VStack(spacing: 12) {
                        Text("No Wishlist Yet")
                            .font(.title3)
                        Text(emptyWishlistMessage)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else {
                    switch viewMode {
                    case .list:
                        List {
                            if wishlistScope == .allLists {
                                ForEach(groupedSections) { section in
                                    Section("\(section.list.displayName) · \(section.entries.count)") {
                                        ForEach(section.entries) { entry in
                                            favoriteRowNavigation(for: entry, status: statusLookup[entry.id])
                                                .listRowInsets(EdgeInsets(
                                                    top: listRowVerticalInset,
                                                    leading: listRowHorizontalInset,
                                                    bottom: listRowVerticalInset,
                                                    trailing: listRowHorizontalInset
                                                ))
                                                .listRowBackground(SwiftUI.Color.clear)
                                        }
                                    }
                                }
                            } else {
                                ForEach(filteredEntries) { entry in
                                    favoriteRowNavigation(for: entry, status: statusLookup[entry.id])
                                        .listRowInsets(EdgeInsets(
                                            top: listRowVerticalInset,
                                            leading: listRowHorizontalInset,
                                            bottom: listRowVerticalInset,
                                            trailing: listRowHorizontalInset
                                        ))
                                        .listRowBackground(SwiftUI.Color.clear)
                                }
                                .onMove(perform: canReorderWishlist ? moveWishlistEntries : nil)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)

                    case .grid:
                        #if targetEnvironment(macCatalyst)
                        let minimumCardWidth = isRoomyCanvas ? 208.0 : 188.0
                        let columnSpacing = isRoomyCanvas ? 40.0 : 28.0
                        let rowSpacing = isRoomyCanvas ? 34.0 : 26.0
                        let horizontalPadding = isRoomyCanvas ? 56.0 : 28.0
                        #else
                        let minimumCardWidth = isRoomyCanvas ? 184.0 : 160.0
                        let columnSpacing = isRoomyCanvas ? 28.0 : (isLandscape ? 22.0 : 16.0)
                        let rowSpacing = isRoomyCanvas ? 30.0 : (isLandscape ? 24.0 : 18.0)
                        let horizontalPadding = isRoomyCanvas ? 48.0 : (isLandscape ? 12.0 : 16.0)
                        #endif
                        let verticalPadding = isRoomyCanvas ? 24.0 : (isLandscape ? 12.0 : 16.0)
                        ScrollView {
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: minimumCardWidth), spacing: columnSpacing)],
                                spacing: rowSpacing
                            ) {
                                ForEach(filteredEntries) { entry in
                                    favoriteGridNavigation(for: entry, status: statusLookup[entry.id])
                                        .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, horizontalPadding)
                            .padding(.vertical, verticalPadding)
                        }

                    case .coverFlow:
                        GeometryReader { outerGeometry in
                            let availableWidth = outerGeometry.size.width
                            let containerHeight = outerGeometry.size.height
                            let isPad = UIDevice.current.userInterfaceIdiom == .pad
                            let cardWidth = isImmersiveCoverFlow
                                ? (isPad
                                    ? min(max(min(availableWidth * 0.5, containerHeight * 0.82), 340), 520)
                                    : min(max(min(availableWidth * 0.42, containerHeight * 0.52), 220), 320))
                                : (isPad
                                    ? min(max(availableWidth * 0.72, 320), 540)
                                    : min(max(availableWidth * 0.62, 240), 420))
                            let overlapSpacing = isImmersiveCoverFlow && isPad ? -cardWidth * 0.1 : -cardWidth * 0.14
                            let itemHeight = isImmersiveCoverFlow
                                ? (isPad
                                    ? max(containerHeight - 12, cardWidth + 120)
                                    : min(max(cardWidth + 118, 330), max(containerHeight - 32, 280)))
                                : (isPad ? max(cardWidth + 150, 460) : max(cardWidth + 120, 360))
                            let contentHeight = isImmersiveCoverFlow
                                ? (isPad ? outerGeometry.size.height + 12 : outerGeometry.size.height)
                                : (isPad ? max(cardWidth + 210, 560) : max(cardWidth + 180, 420))

                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: overlapSpacing) {
                                    ForEach(filteredEntries) { entry in
                                        GeometryReader { itemGeometry in
                                            let frame = itemGeometry.frame(in: .global)
                                            let containerMidX = outerGeometry.frame(in: .global).midX
                                            let distance = frame.midX - containerMidX
                                            let normalizedDistance = max(-1, min(1, distance / 260))

                                            CoverFlowCardView(
                                                listing: entry.listing,
                                                isFavorite: true,
                                                themeTint: theme.tint,
                                                cardWidth: cardWidth,
                                                showsMetadata: true,
                                                subtitleText: wishlistContextSubtitle(for: entry),
                                                status: statusLookup[entry.id],
                                                prefersCompactArtwork: isImmersiveCoverFlow,
                                                onTap: {
                                                    selectedCoverFlowListing = entry.listing
                                                },
                                                onFavoriteToggle: {
                                                    favoritesStore.toggle(entry.listing, in: entry.list)
                                                },
                                                normalizedDistanceFromCenter: normalizedDistance
                                            )
                                        }
                                        .frame(width: cardWidth, height: itemHeight)
                                    }
                                }
                                .padding(.horizontal, max((outerGeometry.size.width - cardWidth) / 2, 24))
                                .padding(.vertical, isImmersiveCoverFlow && isPad ? 10 : 30)
                                .frame(minHeight: contentHeight)
                            }
                        }
                    }
                }
            }
        }
    }

    private var scopedWishlistEntries: [WishlistedEntry] {
        switch wishlistScope {
        case .currentList:
            let listings = library.listings(for: list)
            return favoritesStore.favorites(in: list, from: listings).map { WishlistedEntry(list: list, listing: $0) }
        case .allLists:
            return favoritesStore.allWishlistedEntries(
                lists: RSDAppState.availableLists,
                listingsResolver: { library.listings(for: $0) }
            )
        }
    }

    private var filteredWishlistEntries: [WishlistedEntry] {
        let query = searchText.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return scopedWishlistEntries.filter { entry in
            let matchesQuery = query.isEmpty
                || entry.listing.searchableText.contains(query)
                || entry.list.displayName.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).contains(query)
            let matchesYear = wishlistScope == .currentList || globalYearFilter == "All Years" || entry.list.yearLabel == globalYearFilter
            let matchesRegion = wishlistScope == .currentList || globalRegionFilter == "All Regions" || entry.list.regionLabel == globalRegionFilter
            let entryStatus = releaseStatusStore.status(for: entry.listing, in: entry.list)
            let matchesStatus = wishlistScope == .currentList
                || globalStatusFilter == "All Statuses"
                || entryStatus?.label == globalStatusFilter
            return matchesQuery && matchesYear && matchesRegion && matchesStatus
        }
    }

    private var groupedWishlistSections: [WishlistSection] {
        Dictionary(grouping: filteredWishlistEntries, by: \.list)
            .sorted { lhs, rhs in
                RSDAppState.listOrderBySlug[lhs.key.slug] ?? .max
                    < RSDAppState.listOrderBySlug[rhs.key.slug] ?? .max
            }
            .map { WishlistSection(list: $0.key, entries: $0.value) }
    }

    private func favoriteRowNavigation(for entry: WishlistedEntry, status: ReleaseAcquisitionStatus?) -> some View {
        NavigationLink(destination: ReleaseDetailView(listing: entry.listing, list: entry.list)) {
            ReleaseRowView(
                listing: entry.listing,
                isFavorite: true,
                themeTint: theme.tint,
                status: status,
                onFavoriteToggle: {
                    favoritesStore.toggle(entry.listing, in: entry.list)
                }
            )
        }
        .contextMenu {
            if wishlistScope == .currentList {
                SwiftUI.Button("Move to Top", systemImage: "arrow.up.to.line") {
                    favoritesStore.moveToTop(entry.listing, in: entry.list)
                }
                SwiftUI.Button("Remove from Wishlist", systemImage: "bookmark.slash") {
                    favoritesStore.toggle(entry.listing, in: entry.list)
                }
            }

            Divider()

            ForEach(ReleaseAcquisitionStatus.allCases) { status in
                SwiftUI.Button(status.label, systemImage: status.systemImage) {
                    releaseStatusStore.setStatus(status, for: entry.listing, in: entry.list)
                }
            }

            if status != nil {
                SwiftUI.Button("Clear Status", systemImage: "xmark.circle") {
                    releaseStatusStore.setStatus(nil, for: entry.listing, in: entry.list)
                }
            }
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            if wishlistScope == .currentList {
                SwiftUI.Button("Top") {
                    favoritesStore.moveToTop(entry.listing, in: entry.list)
                }
                .tint(theme.tint)
            }

            if let status {
                SwiftUI.Button(status.shortLabel) {
                    releaseStatusStore.setStatus(nil, for: entry.listing, in: entry.list)
                }
                .tint(status.color(using: theme.tint))
            }
        }
    }

    private func favoriteGridNavigation(for entry: WishlistedEntry, status: ReleaseAcquisitionStatus?) -> some View {
        NavigationLink(destination: ReleaseDetailView(listing: entry.listing, list: entry.list)) {
            VStack(alignment: .leading, spacing: 8) {
                if wishlistScope == .allLists {
                    wishlistContextChip(for: entry.list)
                }

                ReleaseGridCardView(
                    listing: entry.listing,
                    isFavorite: true,
                    themeTint: theme.tint,
                    subtitleText: wishlistContextSubtitle(for: entry),
                    status: status,
                    onFavoriteToggle: {
                        favoritesStore.toggle(entry.listing, in: entry.list)
                    }
                )
            }
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        SwiftUI.ToolbarItemGroup(placement: .topBarTrailing) {
            if scopedWishlistEntries.isEmpty == false {
                SwiftUI.Button {
                    exportPickerPresented = true
                } label: {
                    if isPreparingShare {
                        ProgressView()
                    } else {
                        SwiftUI.Image(systemName: "square.and.arrow.up")
                    }
                }
                .disabled(isPreparingShare)
            }

            Menu {
                Picker("Scope", selection: $wishlistScope) {
                    ForEach(WishlistScope.allCases) { scope in
                        Text(scope.label(for: list)).tag(scope)
                    }
                }

                if wishlistScope == .currentList {
                    Divider()
                    
                    Picker("View", selection: $appState.favoritesViewMode) {
                        ForEach(RSDViewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }

                    Divider()

                    SwiftUI.Button("Sort by Artist") {
                        favoritesStore.sortByArtist(in: list, from: library.listings(for: list))
                    }

                    SwiftUI.Button("Sort by Title") {
                        favoritesStore.sortByTitle(in: list, from: library.listings(for: list))
                    }

                    SwiftUI.Button("Sort by Got It") {
                        let statusLookup = Dictionary(
                            uniqueKeysWithValues: library.listings(for: list).compactMap { listing in
                                releaseStatusStore.status(for: listing, in: list).map { (listing.id, $0) }
                            }
                        )
                        favoritesStore.sortByGotIt(in: list, from: library.listings(for: list), statuses: statusLookup)
                    }

                    SwiftUI.Button("Clear This Wishlist", role: .destructive) {
                        favoritesStore.clear(in: list)
                    }

                    SwiftUI.Button("Clear Statuses in This Wishlist", role: .destructive) {
                        releaseStatusStore.clear(in: list)
                    }
                } else {
                    Divider()

                    Picker("Year", selection: $globalYearFilter) {
                        Text("All Years").tag("All Years")
                        ForEach(availableGlobalYears, id: \.self) { year in
                            Text(year).tag(year)
                        }
                    }

                    Picker("Region", selection: $globalRegionFilter) {
                        Text("All Regions").tag("All Regions")
                        ForEach(availableGlobalRegions, id: \.self) { region in
                            Text(region).tag(region)
                        }
                    }

                    Picker("Status", selection: $globalStatusFilter) {
                        Text("All Statuses").tag("All Statuses")
                        ForEach(availableGlobalStatuses, id: \.label) { status in
                            Text(status.label).tag(status.label)
                        }
                    }
                }
            } label: {
                SwiftUI.Image(systemName: "rectangle.3.group")
            }

            if canReorderWishlist {
                EditButton()
            }

            if showsDoneButton {
                SwiftUI.Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    private func exportWishlist(as format: WishlistExportFormat) {
        guard scopedWishlistEntries.isEmpty == false else {
            return
        }

        isPreparingShare = true
        Task {
            let url: URL
            let entries = filteredWishlistEntries
            switch (wishlistScope, format) {
            case (.currentList, .pdf):
                url = await FavoriteExportBuilder.makePDF(
                    for: entries.map(\.listing),
                    list: list,
                    selectedStore: selectedStoreStore.selectedStore,
                    statuses: makeStatusLookup(for: entries)
                )
            case (.allLists, .pdf):
                url = await FavoriteExportBuilder.makeGlobalPDF(
                    for: groupedWishlistSections,
                    statuses: makeStatusLookup(for: entries)
                )
            case (.currentList, .csv):
                url = FavoriteExportBuilder.makeCSV(
                    for: entries,
                    fileName: "\(FavoriteExportBuilder.sanitizedFileName(list.displayName))-wishlist.csv"
                )
            case (.allLists, .csv):
                url = FavoriteExportBuilder.makeCSV(
                    for: entries,
                    fileName: "record-store-day-global-wishlist.csv"
                )
            case (.currentList, .text):
                url = FavoriteExportBuilder.makeText(
                    for: entries,
                    title: "Record Store Day Wishlist",
                    subtitle: list.displayName,
                    fileName: "\(FavoriteExportBuilder.sanitizedFileName(list.displayName))-wishlist.txt"
                )
            case (.allLists, .text):
                url = FavoriteExportBuilder.makeText(
                    for: entries,
                    title: "Record Store Day Global Wishlist",
                    subtitle: "All Wishlists",
                    fileName: "record-store-day-global-wishlist.txt"
                )
            }
            await MainActor.run {
                isPreparingShare = false
                shareDocument = ShareDocument(url: url)
            }
        }
    }

    private var wishlistNavigationTitle: String {
        wishlistScope == .currentList ? "Wishlist" : "All Wishlists"
    }

    private var emptyWishlistMessage: String {
        switch wishlistScope {
        case .currentList:
            return "Save releases from \(list.displayName) and they’ll show up here."
        case .allLists:
            return "Save releases from any list and they’ll show up here together."
        }
    }

    private var effectiveWishlistViewMode: RSDViewMode {
        wishlistScope == .allLists ? .list : appState.favoritesViewMode
    }

    private var canReorderWishlist: Bool {
        wishlistScope == .currentList && effectiveWishlistViewMode == .list && filteredWishlistEntries.isEmpty == false
    }

    private var availableGlobalYears: [String] {
        Array(Set(scopedWishlistEntries.map(\.list.yearLabel))).sorted(by: >)
    }

    private var availableGlobalRegions: [String] {
        Array(Set(scopedWishlistEntries.map(\.list.regionLabel))).sorted()
    }

    private var availableGlobalStatuses: [ReleaseAcquisitionStatus] {
        ReleaseAcquisitionStatus.allCases.filter { status in
            scopedWishlistEntries.contains { entry in
                releaseStatusStore.status(for: entry.listing, in: entry.list) == status
            }
        }
    }

    private func moveWishlistEntries(from offsets: IndexSet, to destination: Int) {
        guard wishlistScope == .currentList, searchText.isEmpty else {
            return
        }
        favoritesStore.move(fromOffsets: offsets, toOffset: destination, in: list)
    }

    @ViewBuilder
    private func wishlistContextChip(for list: RSDListDefinition) -> some View {
        Text(list.displayName)
            .font(.caption.weight(.semibold))
            .foregroundColor(theme.tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(theme.tint.opacity(colorScheme == .dark ? 0.18 : 0.12))
            )
    }

    private func wishlistContextSubtitle(for entry: WishlistedEntry) -> String? {
        guard wishlistScope == .allLists else {
            return nil
        }
        return entry.list.displayName
    }

    private func makeStatusLookup(for entries: [WishlistedEntry]) -> [String: ReleaseAcquisitionStatus] {
        entries.reduce(into: [String: ReleaseAcquisitionStatus]()) { partialResult, entry in
            guard let status = releaseStatusStore.status(for: entry.listing, in: entry.list) else {
                return
            }
            partialResult[entry.id] = status
            partialResult[entry.listing.id] = status
        }
    }
}

private enum WishlistScope: String, CaseIterable, Identifiable {
    case currentList
    case allLists

    var id: String { rawValue }

    func label(for list: RSDListDefinition) -> String {
        switch self {
        case .currentList:
            return list.displayName
        case .allLists:
            return "All Wishlists"
        }
    }
}

struct ShareDocument: Identifiable {
    let id = UUID()
    let url: URL
}

struct ActivityShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct FavoritesSearchModifier: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if isEnabled {
            content.searchable(text: $text, prompt: "Search wishlist")
        } else {
            content
        }
    }
}

private struct WishlistNavigationBarStyleApplier: UIViewControllerRepresentable {
    let titleColor: UIColor
    let tintColor: UIColor

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        guard let navigationController = uiViewController.navigationController else { return }

        let signature = Signature(titleColor: titleColor, tintColor: tintColor)
        guard context.coordinator.lastApplied != signature else {
            return
        }

        context.coordinator.lastApplied = signature

        let navigationBar = navigationController.navigationBar
        let standardAppearance = navigationBar.standardAppearance.copy()
        let scrollEdgeAppearance = (navigationBar.scrollEdgeAppearance ?? navigationBar.standardAppearance).copy()
        let compactAppearance = (navigationBar.compactAppearance ?? navigationBar.standardAppearance).copy()

        standardAppearance.titleTextAttributes[.foregroundColor] = titleColor
        standardAppearance.largeTitleTextAttributes[.foregroundColor] = titleColor
        scrollEdgeAppearance.titleTextAttributes[.foregroundColor] = titleColor
        scrollEdgeAppearance.largeTitleTextAttributes[.foregroundColor] = titleColor
        compactAppearance.titleTextAttributes[.foregroundColor] = titleColor
        compactAppearance.largeTitleTextAttributes[.foregroundColor] = titleColor

        navigationBar.standardAppearance = standardAppearance
        navigationBar.scrollEdgeAppearance = scrollEdgeAppearance
        navigationBar.compactAppearance = compactAppearance
        navigationBar.compactScrollEdgeAppearance = compactAppearance
        navigationBar.tintColor = tintColor
        navigationController.view.tintColor = tintColor
        uiViewController.view.tintColor = tintColor
    }

    final class Coordinator {
        var lastApplied: Signature?
    }

    struct Signature: Equatable {
        let titleColor: UIColor
        let tintColor: UIColor
    }
}

enum FavoriteExportBuilder {
    private enum PDFHeaderStyle {
        case wishlist
        case globalWishlist

        var wishlistWord: String {
            switch self {
            case .wishlist:
                return "Wishlist"
            case .globalWishlist:
                return "Global Wishlist"
            }
        }
    }

    static func makePDF(for listings: [Listing], list: RSDListDefinition, selectedStore: ParticipatingStoreRecord?, statuses: [String: ReleaseAcquisitionStatus]) async -> URL {
        let exportRows = listings.enumerated().map {
            PDFExportRow.listing(displayIndex: $0.offset + 1, listing: $0.element, status: statuses[$0.element.id])
        }
        return await makePDF(
            for: listings,
            exportRows: exportRows,
            subtitleText: "\(currentYearText) · \(list.subtitle)",
            fileName: "\(sanitizedFileName(list.displayName))-wishlist.pdf",
            theme: theme(for: list),
            selectedStore: selectedStore,
            headerStyle: .wishlist
        )
    }

    fileprivate static func makeGlobalPDF(for sections: [WishlistSection], statuses: [String: ReleaseAcquisitionStatus]) async -> URL {
        let allEntries = sections.flatMap(\.entries)
        let listings = allEntries.map(\.listing)
        var exportRows: [PDFExportRow] = []
        var displayIndex = 1
        for section in sections {
            exportRows.append(.section(title: section.list.displayName))
            for entry in section.entries {
                exportRows.append(.listing(displayIndex: displayIndex, listing: entry.listing, status: statuses[entry.id]))
                displayIndex += 1
            }
        }
        return await makePDF(
            for: listings,
            exportRows: exportRows,
            subtitleText: currentYearText,
            fileName: "record-store-day-global-wishlist.pdf",
            theme: theme(for: nil),
            selectedStore: nil,
            headerStyle: .globalWishlist
        )
    }

    private static func makePDF(
        for listings: [Listing],
        exportRows: [PDFExportRow],
        subtitleText: String,
        fileName: String,
        theme: PDFTheme,
        selectedStore: ParticipatingStoreRecord?,
        headerStyle: PDFHeaderStyle
    ) async -> URL {
        let artworkImages = await loadArtworkImages(for: listings)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(fileName)
        let includeCategory = false
        let includeQuantity = listings.contains { $0.quantityValue != nil }

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        try? renderer.writePDF(to: url) { context in
            let margin: CGFloat = 28
            let contentRect = pageRect.insetBy(dx: margin, dy: margin)
            let bannerHeight: CGFloat = 88
            let tableHeaderHeight: CGFloat = 28
            let minimumRowHeight: CGFloat = 78
            let artworkSize = CGSize(width: 60, height: 60)
            let printBlack = UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
            let printGray = UIColor(red: 0.42, green: 0.42, blue: 0.44, alpha: 1)
            let printLightGray = UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1)
            let printWhite = UIColor.white
            let notesSectionHeight: CGFloat = 132
            let notesSectionTopPadding: CGFloat = 4
            let sectionHeaderHeight: CGFloat = 28
            let columnSpecs = tableColumns(
                totalWidth: contentRect.width,
                includeCategory: includeCategory,
                includeQuantity: includeQuantity
            )

            let brandPrimaryFont = UIFont(name: "RCA", size: 36) ?? UIFont.systemFont(ofSize: 36, weight: .bold)
            let brandSecondaryFont = UIFont(name: "RCA", size: 12) ?? UIFont.systemFont(ofSize: 12, weight: .semibold)
            let headerWishlistFont = UIFont.systemFont(ofSize: 24, weight: .bold)
            let headerSubtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: printWhite.withAlphaComponent(0.92),
            ]
            let headerCenteredSubtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .regular),
                .foregroundColor: printWhite.withAlphaComponent(0.86),
            ]
            let tableHeaderAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .bold),
                .foregroundColor: printWhite,
            ]
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: printBlack,
            ]
            let detailAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 10, weight: .regular),
                .foregroundColor: printGray,
            ]

            var rowIndex = 0
            let finalPageCapacity = pageCapacity(
                pageHeight: contentRect.height,
                bannerHeight: bannerHeight,
                tableHeaderHeight: tableHeaderHeight,
                notesHeight: notesSectionHeight,
                minimumRowHeight: minimumRowHeight
            )

            func drawPageHeader() -> CGFloat {
                let bannerRect = CGRect(x: contentRect.minX, y: contentRect.minY, width: contentRect.width, height: bannerHeight)
                theme.banner.setFill()
                UIBezierPath(roundedRect: bannerRect, cornerRadius: 18).fill()

                let accentRect = CGRect(x: bannerRect.minX, y: bannerRect.maxY - 10, width: bannerRect.width, height: 10)
                theme.accent.setFill()
                UIBezierPath(roundedRect: accentRect, byRoundingCorners: [.bottomLeft, .bottomRight], cornerRadii: CGSize(width: 18, height: 18)).fill()

                let brandRect = CGRect(x: bannerRect.minX + 20, y: bannerRect.minY + 18, width: 152, height: 56)
                let wishlistRect = CGRect(x: bannerRect.minX + 0, y: bannerRect.minY + 14, width: bannerRect.width, height: 26)
                let subtitleRect = CGRect(x: bannerRect.minX + 0, y: bannerRect.minY + 39, width: bannerRect.width, height: 14)
                let countRect = CGRect(x: bannerRect.minX + 0, y: bannerRect.minY + 52, width: bannerRect.width, height: 14)
                let metadataRect = CGRect(x: bannerRect.maxX - 220, y: bannerRect.minY + 14, width: 200, height: 58)

                drawBrandHeader(in: brandRect, primaryFont: brandPrimaryFont, secondaryFont: brandSecondaryFont, color: printWhite)
                drawCentered(headerStyle.wishlistWord, in: wishlistRect, attributes: [
                    .font: headerWishlistFont,
                    .foregroundColor: printWhite,
                ])
                drawCentered(subtitleText, in: subtitleRect, attributes: headerCenteredSubtitleAttributes)
                drawCentered("\(listings.count) releases", in: countRect, attributes: headerCenteredSubtitleAttributes)

                if let selectedStore {
                    let metadataParagraph = NSMutableParagraphStyle()
                    metadataParagraph.alignment = .right
                    let metadataAttributes: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                        .foregroundColor: printWhite.withAlphaComponent(0.92),
                        .paragraphStyle: metadataParagraph,
                    ]
                    let storeLine = selectedStore.displayName
                    let streetLine = selectedStore.address
                    let cityStateLine = [selectedStore.city, abbreviatedRegion(selectedStore.state, country: selectedStore.country)]
                        .filter { $0.isEmpty == false }
                        .joined(separator: ", ")
                    let phoneLine = selectedStore.phone.isEmpty ? "____________________" : selectedStore.phone
                    let metadata = [storeLine, streetLine, cityStateLine, phoneLine]
                        .filter { $0.isEmpty == false }
                        .joined(separator: "\n")
                    metadata.draw(in: metadataRect, withAttributes: metadataAttributes)
                }

                let headerY = bannerRect.maxY + 14
                let columns = columnRects(in: CGRect(x: contentRect.minX, y: headerY, width: contentRect.width, height: tableHeaderHeight), specs: columnSpecs)

                theme.tableHeader.setFill()
                UIBezierPath(roundedRect: CGRect(x: contentRect.minX, y: headerY, width: contentRect.width, height: tableHeaderHeight), cornerRadius: 8).fill()

                for (spec, rect) in zip(columnSpecs, columns) {
                    drawCentered(spec.title, in: rect.insetBy(dx: 4, dy: 6), attributes: tableHeaderAttributes)
                }

                return headerY + tableHeaderHeight
            }

            func drawGlobalNotesSection(startY: CGFloat) {
                let titleRect = CGRect(x: contentRect.minX, y: startY + 8, width: contentRect.width, height: 22)
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .bold),
                    .foregroundColor: printBlack,
                ]
                "Notes".draw(in: titleRect, withAttributes: titleAttributes)

                let notesRect = CGRect(x: contentRect.minX, y: startY + 34, width: contentRect.width, height: notesSectionHeight - 40)
                let border = UIBezierPath(roundedRect: notesRect, cornerRadius: 12)
                printGray.withAlphaComponent(0.25).setStroke()
                border.lineWidth = 1
                border.stroke()

                var y = notesRect.minY + 18
                while y < notesRect.maxY - 8 {
                    let path = UIBezierPath()
                    path.move(to: CGPoint(x: notesRect.minX + 12, y: y))
                    path.addLine(to: CGPoint(x: notesRect.maxX - 12, y: y))
                    UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1).setStroke()
                    path.lineWidth = 0.8
                    path.stroke()
                    y += 20
                }
            }

            func drawSectionHeader(_ title: String, at yPosition: CGFloat) {
                let rect = CGRect(x: contentRect.minX, y: yPosition, width: contentRect.width, height: sectionHeaderHeight)
                theme.tableHeader.withAlphaComponent(0.12).setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 8).fill()
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12, weight: .bold),
                    .foregroundColor: theme.tableHeader,
                ]
                title.draw(in: rect.insetBy(dx: 10, dy: 6), withAttributes: attrs)
            }

            while rowIndex < exportRows.count || rowIndex == exportRows.count {
                context.beginPage()
                var yPosition = drawPageHeader()
                let remainingListingCount = exportRows.dropFirst(rowIndex).reduce(into: 0) { partialResult, row in
                    if case .listing = row { partialResult += 1 }
                }
                let reserveNotesOnThisPage = remainingListingCount <= finalPageCapacity

                while rowIndex < exportRows.count {
                    let row = exportRows[rowIndex]
                    if case let .section(title) = row {
                        let maxY = reserveNotesOnThisPage ? (contentRect.maxY - notesSectionHeight - 12) : contentRect.maxY
                        guard yPosition + sectionHeaderHeight <= maxY else {
                            break
                        }
                        drawSectionHeader(title, at: yPosition)
                        yPosition += sectionHeaderHeight + 8
                        rowIndex += 1
                        continue
                    }

                    guard case let .listing(displayIndex, listing, status) = row else {
                        rowIndex += 1
                        continue
                    }
                    let artworkImage = artworkImages[listing.id] ?? RSDPlaceholderArt.image(
                        size: 220,
                        style: .from(format: listing.format),
                        userInterfaceStyle: .light
                    )
                    let measuredRowHeight = rowHeight(
                        for: listing,
                        columns: columnSpecs,
                        minimumRowHeight: minimumRowHeight,
                        titleAttributes: titleAttributes,
                        detailAttributes: detailAttributes
                    )

                    let maxY = reserveNotesOnThisPage ? (contentRect.maxY - notesSectionHeight - 12) : contentRect.maxY
                    guard yPosition + measuredRowHeight <= maxY else {
                        break
                    }

                    let rowRect = CGRect(x: contentRect.minX, y: yPosition, width: contentRect.width, height: measuredRowHeight)
                    let columns = columnRects(in: rowRect, specs: columnSpecs)

                    let rowFill = displayIndex.isMultiple(of: 2) ? printLightGray : printWhite
                    rowFill.setFill()
                    UIBezierPath(rect: rowRect).fill()

                    printGray.withAlphaComponent(0.35).setStroke()
                    let rowBorder = UIBezierPath(rect: rowRect)
                    rowBorder.lineWidth = 0.8
                    rowBorder.stroke()

                    for columnRect in columns.dropFirst() {
                        let path = UIBezierPath()
                        path.move(to: CGPoint(x: columnRect.minX, y: rowRect.minY))
                        path.addLine(to: CGPoint(x: columnRect.minX, y: rowRect.maxY))
                        path.lineWidth = 0.5
                        path.stroke()
                    }

                    for (index, spec) in columnSpecs.enumerated() {
                        let rect = columns[index]
                        switch spec.kind {
                        case .art:
                            drawArtwork(artworkImage, in: CGRect(
                                x: rect.midX - artworkSize.width / 2,
                                y: rect.midY - artworkSize.height / 2,
                                width: artworkSize.width,
                                height: artworkSize.height
                            ))
                        case .release:
                            let releaseTitleRect = CGRect(
                                x: rect.minX + 6,
                                y: rect.minY + 8,
                                width: rect.width - 12,
                                height: measuredTextHeight(
                                    listing.album,
                                    width: rect.width - 12,
                                    attributes: titleAttributes
                                )
                            )
                            drawWrappedText(listing.album, in: releaseTitleRect, attributes: titleAttributes)
                            let artistRect = CGRect(
                                x: rect.minX + 6,
                                y: releaseTitleRect.maxY + 4,
                                width: rect.width - 12,
                                height: measuredTextHeight(
                                    listing.artist,
                                    width: rect.width - 12,
                                    attributes: detailAttributes
                                )
                            )
                            drawWrappedText(listing.artist, in: artistRect, attributes: detailAttributes)
                            let indexBadgeAttributes: [NSAttributedString.Key: Any] = [
                                .font: UIFont.systemFont(ofSize: 9, weight: .bold),
                                .foregroundColor: printGray,
                            ]
                            drawCentered("#\(displayIndex)", in: CGRect(x: rect.minX + 6, y: rect.maxY - 18, width: 32, height: 12), attributes: indexBadgeAttributes)
                        case .format:
                            drawWrappedText(listing.format, in: insetCell(rect), attributes: detailAttributes)
                        case .label:
                            drawWrappedText(listing.label, in: insetCell(rect), attributes: detailAttributes)
                        case .category:
                            drawWrappedText(listing.releaseCategory, in: insetCell(rect), attributes: detailAttributes)
                        case .quantity:
                            drawCentered(listing.quantityDisplayValue, in: rect, attributes: detailAttributes)
                        case .status:
                            let statusLabelRect = CGRect(x: rect.minX + 6, y: rect.minY + 7, width: rect.width - 12, height: 12)
                            let statusMarkRect = CGRect(x: rect.minX + 10, y: rect.minY + 19, width: rect.width - 20, height: rect.height - 24)
                            let symbolKind: PDFStatusSymbolKind
                            switch status {
                            case .gotIt:
                                symbolKind = .check
                            case .noLuck:
                                symbolKind = .xmark
                            case nil:
                                symbolKind = .empty
                            case .some:
                                symbolKind = .empty
                            }
                            drawCentered(status?.label ?? "Unmarked", in: statusLabelRect, attributes: detailAttributes)
                            drawStatusSymbol(symbolKind, in: statusMarkRect, tintColor: printBlack)
                        }
                    }

                    yPosition += measuredRowHeight + 6
                    rowIndex += 1
                }

                if rowIndex >= exportRows.count {
                    if yPosition + notesSectionTopPadding + notesSectionHeight <= contentRect.maxY {
                        drawGlobalNotesSection(startY: yPosition + notesSectionTopPadding)
                    } else {
                        context.beginPage()
                        let headerBottom = drawPageHeader()
                        drawGlobalNotesSection(startY: headerBottom + notesSectionTopPadding)
                    }
                    break
                }
            }
        }

        return url
    }

    static func makeCSV(for entries: [WishlistedEntry], fileName: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        var lines = ["List,Artist,Title,Format,Label,Category,Quantity,Status,Details"]
        for entry in entries {
            lines.append([
                csvField(entry.list.displayName),
                csvField(entry.listing.artist),
                csvField(entry.listing.album),
                csvField(entry.listing.format),
                csvField(entry.listing.label),
                csvField(entry.listing.releaseCategory),
                csvField(entry.listing.quantityDisplayValue),
                csvField(ReleaseStatusStore.shared.status(for: entry.listing, in: entry.list)?.label ?? ""),
                csvField(entry.listing.moreInfo),
            ].joined(separator: ","))
        }
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func makeText(for entries: [WishlistedEntry], title: String, subtitle: String, fileName: String) -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        var lines = [title, subtitle, ""]
        var currentList: String?
        for entry in entries {
            if currentList != entry.list.displayName {
                currentList = entry.list.displayName
                lines.append(entry.list.displayName)
            }
            let status = ReleaseStatusStore.shared.status(for: entry.listing, in: entry.list)?.label ?? "Unmarked"
            lines.append("- \(entry.listing.artist) - \(entry.listing.album) [\(entry.listing.format)] [\(status)]")
        }
        try? lines.joined(separator: "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func loadArtworkImages(for listings: [Listing]) async -> [String: UIImage] {
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for listing in listings {
                group.addTask {
                    let image = await artworkImage(for: listing)
                    return (listing.id, image)
                }
            }

            var images: [String: UIImage] = [:]
            for await (id, image) in group {
                if let image {
                    images[id] = image
                }
            }
            return images
        }
    }

    private static func artworkImage(for listing: Listing) async -> UIImage? {
        guard ArtworkPipeline.isArtworkLoadingEnabled,
              let url = URL(string: listing.photoURL),
              listing.photoURL.isEmpty == false else {
            return RSDPlaceholderArt.image(
                size: 220,
                style: .from(format: listing.format),
                userInterfaceStyle: .light
            )
        }

        if let cached = ArtworkPipeline.shared.cachedImage(for: url) {
            return cached
        }

        return try? await ArtworkPipeline.shared.loadImage(from: url)
    }

    private static func drawArtwork(_ image: UIImage?, in rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        context.saveGState()
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
        UIColor(white: 0.96, alpha: 1).setFill()
        path.fill()
        path.addClip()

        guard let image else {
            context.restoreGState()
            return
        }

        let drawRect: CGRect
        let imageAspect = image.size.width / max(image.size.height, 1)
        let rectAspect = rect.width / max(rect.height, 1)
        if imageAspect > rectAspect {
            let scaledWidth = rect.height * imageAspect
            drawRect = CGRect(x: rect.midX - scaledWidth / 2, y: rect.minY, width: scaledWidth, height: rect.height)
        } else {
            let scaledHeight = rect.width / max(imageAspect, 0.0001)
            drawRect = CGRect(x: rect.minX, y: rect.midY - scaledHeight / 2, width: rect.width, height: scaledHeight)
        }
        image.draw(in: drawRect)
        context.restoreGState()
    }

    private static func drawWrappedText(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left

        var mergedAttributes = attributes
        mergedAttributes[.paragraphStyle] = paragraphStyle

        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: mergedAttributes, context: nil)
    }

    private static func drawCentered(_ text: String, in rect: CGRect, attributes: [NSAttributedString.Key: Any]) {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail

        var mergedAttributes = attributes
        mergedAttributes[.paragraphStyle] = paragraphStyle

        (text as NSString).draw(with: rect, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: mergedAttributes, context: nil)
    }

    private static func columnRects(in rowRect: CGRect, specs: [PDFColumn]) -> [CGRect] {
        var x = rowRect.minX
        return specs.map { spec in
            defer { x += spec.width }
            return CGRect(x: x, y: rowRect.minY, width: spec.width, height: rowRect.height)
        }
    }

    private static func insetCell(_ rect: CGRect) -> CGRect {
        rect.insetBy(dx: 6, dy: 8)
    }

    private static func rowHeight(for listing: Listing,
                                  columns: [PDFColumn],
                                  minimumRowHeight: CGFloat,
                                  titleAttributes: [NSAttributedString.Key: Any],
                                  detailAttributes: [NSAttributedString.Key: Any]) -> CGFloat {
        var maxHeight = minimumRowHeight
        for column in columns {
            switch column.kind {
            case .release:
                let value = measuredTextHeight(listing.album, width: column.width - 12, attributes: titleAttributes)
                    + 4
                    + measuredTextHeight(listing.artist, width: column.width - 12, attributes: detailAttributes)
                    + 16
                maxHeight = max(maxHeight, value)
            case .format:
                maxHeight = max(maxHeight, measuredTextHeight(listing.format, width: column.width - 12, attributes: detailAttributes) + 18)
            case .label:
                maxHeight = max(maxHeight, measuredTextHeight(listing.label, width: column.width - 12, attributes: detailAttributes) + 18)
            case .category:
                maxHeight = max(maxHeight, measuredTextHeight(listing.releaseCategory, width: column.width - 12, attributes: detailAttributes) + 18)
            default:
                break
            }
        }
        return maxHeight
    }

    private static func measuredTextHeight(_ text: String, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.alignment = .left

        var mergedAttributes = attributes
        mergedAttributes[.paragraphStyle] = paragraphStyle

        let rect = (text as NSString).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: mergedAttributes,
            context: nil
        )
        return ceil(rect.height)
    }

    private static func drawNotesLines(in rect: CGRect) {
        let spacing: CGFloat = 16
        var y = rect.minY + 10

        while y < rect.maxY {
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
            UIColor(red: 0.82, green: 0.82, blue: 0.84, alpha: 1).setStroke()
            path.lineWidth = 0.8
            path.stroke()
            y += spacing
        }
    }

    static func sanitizedFileName(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private static func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func abbreviatedRegion(_ value: String, country: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return "" }
        if trimmed.count <= 3 {
            return trimmed.uppercased()
        }

        let normalizedCountry = country.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let abbreviations: [String: String] = [
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
            "Alabama": "AL",
            "Alaska": "AK",
            "Arizona": "AZ",
            "Arkansas": "AR",
            "California": "CA",
            "Colorado": "CO",
            "Connecticut": "CT",
            "Delaware": "DE",
            "Florida": "FL",
            "Georgia": "GA",
            "Hawaii": "HI",
            "Idaho": "ID",
            "Illinois": "IL",
            "Indiana": "IN",
            "Iowa": "IA",
            "Kansas": "KS",
            "Kentucky": "KY",
            "Louisiana": "LA",
            "Maine": "ME",
            "Maryland": "MD",
            "Massachusetts": "MA",
            "Michigan": "MI",
            "Minnesota": "MN",
            "Mississippi": "MS",
            "Missouri": "MO",
            "Montana": "MT",
            "Nebraska": "NE",
            "Nevada": "NV",
            "New Hampshire": "NH",
            "New Jersey": "NJ",
            "New Mexico": "NM",
            "New York": "NY",
            "North Carolina": "NC",
            "North Dakota": "ND",
            "Ohio": "OH",
            "Oklahoma": "OK",
            "Oregon": "OR",
            "Pennsylvania": "PA",
            "Rhode Island": "RI",
            "South Carolina": "SC",
            "South Dakota": "SD",
            "Tennessee": "TN",
            "Texas": "TX",
            "Utah": "UT",
            "Vermont": "VT",
            "Virginia": "VA",
            "Washington": "WA",
            "West Virginia": "WV",
            "Wisconsin": "WI",
            "Wyoming": "WY",
        ]

        guard normalizedCountry.contains("united states")
            || normalizedCountry == "us"
            || normalizedCountry.contains("canada")
            || normalizedCountry == "ca" else {
            return trimmed
        }

        return abbreviations[trimmed] ?? trimmed
    }

    private static func theme(for list: RSDListDefinition?) -> PDFTheme {
        let region = list?.subtitle.lowercased() ?? ""
        switch region {
        case "canada":
            return PDFTheme(
                banner: UIColor(red: 0.7, green: 0.08, blue: 0.14, alpha: 1),
                accent: UIColor(red: 0.93, green: 0.93, blue: 0.93, alpha: 1),
                tableHeader: UIColor(red: 0.62, green: 0.09, blue: 0.14, alpha: 1)
            )
        case "us":
            return PDFTheme(
                banner: UIColor(red: 0.1, green: 0.18, blue: 0.4, alpha: 1),
                accent: UIColor(red: 0.73, green: 0.12, blue: 0.18, alpha: 1),
                tableHeader: UIColor(red: 0.16, green: 0.24, blue: 0.48, alpha: 1)
            )
        case "uk":
            return PDFTheme(
                banner: UIColor(red: 0.04, green: 0.19, blue: 0.43, alpha: 1),
                accent: UIColor(red: 0.75, green: 0.08, blue: 0.16, alpha: 1),
                tableHeader: UIColor(red: 0.13, green: 0.23, blue: 0.45, alpha: 1)
            )
        case "germany":
            return PDFTheme(
                banner: UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1),
                accent: UIColor(red: 0.84, green: 0.1, blue: 0.14, alpha: 1),
                tableHeader: UIColor(red: 0.22, green: 0.22, blue: 0.22, alpha: 1)
            )
        case "australia":
            return PDFTheme(
                banner: UIColor(red: 0.04, green: 0.16, blue: 0.39, alpha: 1),
                accent: UIColor(red: 0.78, green: 0.64, blue: 0.16, alpha: 1),
                tableHeader: UIColor(red: 0.1, green: 0.21, blue: 0.43, alpha: 1)
            )
        default:
            return PDFTheme(
                banner: UIColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1),
                accent: UIColor(red: 0.77, green: 0.12, blue: 0.18, alpha: 1),
                tableHeader: UIColor(red: 0.32, green: 0.32, blue: 0.36, alpha: 1)
            )
        }
    }

    private static func tableColumns(totalWidth: CGFloat, includeCategory: Bool, includeQuantity: Bool) -> [PDFColumn] {
        var columns: [PDFColumn] = [
            PDFColumn(kind: .art, title: "Art", width: 72),
            PDFColumn(kind: .release, title: "Release", width: includeCategory || includeQuantity ? 178 : 200),
            PDFColumn(kind: .format, title: "Format", width: 68),
            PDFColumn(kind: .label, title: "Label", width: includeCategory || includeQuantity ? 98 : 112),
        ]

        if includeCategory {
            columns.append(PDFColumn(kind: .category, title: "Category", width: 82))
        }

        if includeQuantity {
            columns.append(PDFColumn(kind: .quantity, title: "Qty", width: 44))
        }

        columns.append(PDFColumn(kind: .status, title: "Status", width: 82))

        let usedWidth = columns.reduce(CGFloat.zero) { $0 + $1.width }
        let remaining = max(totalWidth - usedWidth, 0)
        if let releaseIndex = columns.firstIndex(where: { $0.kind == .release }) {
            columns[releaseIndex].width += remaining
        }
        return columns
    }

    private static func pageCapacity(pageHeight: CGFloat,
                                     bannerHeight: CGFloat,
                                     tableHeaderHeight: CGFloat,
                                     notesHeight: CGFloat,
                                     minimumRowHeight: CGFloat) -> Int {
        let available = pageHeight - bannerHeight - tableHeaderHeight - notesHeight - 48
        return max(Int(floor(available / (minimumRowHeight + 6))), 1)
    }

    private static var currentYearText: String {
        String(Calendar.current.component(.year, from: Date()))
    }

    private static func drawBrandHeader(
        in rect: CGRect,
        primaryFont: UIFont,
        secondaryFont: UIFont,
        color: UIColor
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .left
        let centeredParagraph = NSMutableParagraphStyle()
        centeredParagraph.alignment = .center

        let rsdAttributes: [NSAttributedString.Key: Any] = [
            .font: primaryFont,
            .foregroundColor: color,
            .paragraphStyle: paragraph,
        ]
        let assistantAttributes: [NSAttributedString.Key: Any] = [
            .font: secondaryFont,
            .foregroundColor: color.withAlphaComponent(0.94),
            .paragraphStyle: centeredParagraph,
        ]
        let rsdRect = CGRect(x: rect.minX, y: rect.minY - 2, width: 140, height: 34)
        let assistantRect = CGRect(x: rect.minX - 4, y: rect.minY + 30, width: 114, height: 16)

        "RSD".draw(in: rsdRect, withAttributes: rsdAttributes)
        "assistant".draw(in: assistantRect, withAttributes: assistantAttributes)
    }

    private static func drawStatusSymbol(_ symbol: PDFStatusSymbolKind, in rect: CGRect, tintColor: UIColor) {
        let size = min(rect.width, rect.height) * 0.72
        let circleRect = CGRect(
            x: rect.midX - size / 2,
            y: rect.midY - size / 2,
            width: size,
            height: size
        )

        let circlePath = UIBezierPath(ovalIn: circleRect)
        tintColor.setStroke()
        circlePath.lineWidth = 1.8
        circlePath.stroke()

        switch symbol {
        case .empty:
            return
        case .check:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: circleRect.minX + size * 0.24, y: circleRect.midY + size * 0.02))
            path.addLine(to: CGPoint(x: circleRect.minX + size * 0.43, y: circleRect.maxY - size * 0.28))
            path.addLine(to: CGPoint(x: circleRect.maxX - size * 0.22, y: circleRect.minY + size * 0.28))
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.lineWidth = 2.2
            path.stroke()
        case .xmark:
            let path = UIBezierPath()
            path.move(to: CGPoint(x: circleRect.minX + size * 0.28, y: circleRect.minY + size * 0.28))
            path.addLine(to: CGPoint(x: circleRect.maxX - size * 0.28, y: circleRect.maxY - size * 0.28))
            path.move(to: CGPoint(x: circleRect.maxX - size * 0.28, y: circleRect.minY + size * 0.28))
            path.addLine(to: CGPoint(x: circleRect.minX + size * 0.28, y: circleRect.maxY - size * 0.28))
            path.lineCapStyle = .round
            path.lineWidth = 2.0
            path.stroke()
        }
    }
}

private struct PDFTheme {
    let banner: UIColor
    let accent: UIColor
    let tableHeader: UIColor
}

private struct PDFColumn {
    let kind: PDFColumnKind
    let title: String
    var width: CGFloat
}

private enum PDFStatusSymbolKind {
    case check
    case xmark
    case empty
}

private enum PDFExportRow {
    case section(title: String)
    case listing(displayIndex: Int, listing: Listing, status: ReleaseAcquisitionStatus?)
}

private enum PDFColumnKind {
    case art
    case release
    case format
    case label
    case category
    case quantity
    case status
}

private extension DateFormatter {
    static let favoriteExport: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
