//
//  RSDViewController.swift
//  RSD Helper
//
//  Created by David Strauss on 4/14/17.
//  Copyright © 2017 David Strauss. All rights reserved.
//

import SwiftUI
import Combine
import ImageIO
import UIKit

enum RSDPresentedSheet: Identifiable {
    case favorites
    case stores
    case settings

    var id: String {
        switch self {
        case .favorites:
            return "favorites"
        case .stores:
            return "stores"
        case .settings:
            return "settings"
        }
    }
}

enum RSDSortOption: String, CaseIterable, Identifiable {
    case artist = "Artist"
    case title = "Title"
    case format = "Format"
    case label = "Label"
    case category = "Category"

    var id: String { rawValue }
}

struct ReleaseSection: Identifiable {
    let id: String
    let title: String
    let listings: [Listing]
}

enum RSDViewMode: String, CaseIterable, Identifiable {
    case list = "List"
    case grid = "Grid"
    case coverFlow = "Cover Flow"

    var id: String { rawValue }
}

enum RSDMainTab: Hashable {
    case releases
    case stores
}

struct RSDListDefinition: Identifiable, Hashable {
    let slug: String
    let title: String
    let subtitle: String
    let resourceName: String

    var id: String { slug }

    var displayName: String {
        subtitle.isEmpty ? title : "\(title) - \(subtitle)"
    }

    var theme: RSDTheme {
        let lowerSubtitle = subtitle.lowercased()
        let isBlackFriday = lowerSubtitle.contains("black friday")

        if isBlackFriday {
            return RSDTheme(
                light: RSDThemePalette(
                    tint: SwiftUI.Color(red: 0.76, green: 0.16, blue: 0.18),
                    navigationBar: SwiftUI.Color(red: 0.99, green: 0.95, blue: 0.9),
                    filterBar: SwiftUI.Color(red: 0.98, green: 0.94, blue: 0.88),
                    backgroundTop: SwiftUI.Color(red: 1.0, green: 0.98, blue: 0.94),
                    backgroundBottom: SwiftUI.Color(red: 0.95, green: 0.9, blue: 0.84)
                ),
                dark: RSDThemePalette(
                    tint: SwiftUI.Color(red: 0.95, green: 0.74, blue: 0.16),
                    navigationBar: SwiftUI.Color(red: 0.1, green: 0.1, blue: 0.12),
                    filterBar: SwiftUI.Color(red: 0.16, green: 0.16, blue: 0.18),
                    backgroundTop: SwiftUI.Color(red: 0.08, green: 0.08, blue: 0.1),
                    backgroundBottom: SwiftUI.Color(red: 0.17, green: 0.08, blue: 0.08)
                )
            )
        }

        switch lowerSubtitle {
        case "canada":
            return RSDTheme(
                light: RSDThemePalette(
                    tint: SwiftUI.Color(red: 0.79, green: 0.08, blue: 0.16),
                    navigationBar: SwiftUI.Color(red: 0.93, green: 0.96, blue: 0.98),
                    filterBar: SwiftUI.Color(red: 0.98, green: 0.96, blue: 0.96),
                    backgroundTop: SwiftUI.Color(red: 0.99, green: 0.98, blue: 0.98),
                    backgroundBottom: SwiftUI.Color(red: 0.95, green: 0.96, blue: 0.99)
                ),
                dark: RSDThemePalette(
                    tint: SwiftUI.Color(red: 1.0, green: 0.36, blue: 0.34),
                    navigationBar: SwiftUI.Color(red: 0.14, green: 0.08, blue: 0.1),
                    filterBar: SwiftUI.Color(red: 0.2, green: 0.1, blue: 0.12),
                    backgroundTop: SwiftUI.Color(red: 0.11, green: 0.08, blue: 0.1),
                    backgroundBottom: SwiftUI.Color(red: 0.18, green: 0.08, blue: 0.1)
                )
            )
        case "us":
            return RSDTheme(
                light: RSDThemePalette(
                    tint: SwiftUI.Color(red: 0.13, green: 0.24, blue: 0.59),
                    navigationBar: SwiftUI.Color(red: 0.94, green: 0.96, blue: 0.99),
                    filterBar: SwiftUI.Color(red: 0.97, green: 0.97, blue: 0.99),
                    backgroundTop: SwiftUI.Color(red: 0.98, green: 0.98, blue: 1.0),
                    backgroundBottom: SwiftUI.Color(red: 0.96, green: 0.95, blue: 0.98)
                ),
                dark: RSDThemePalette(
                    tint: SwiftUI.Color(red: 0.43, green: 0.58, blue: 1.0),
                    navigationBar: SwiftUI.Color(red: 0.06, green: 0.1, blue: 0.18),
                    filterBar: SwiftUI.Color(red: 0.09, green: 0.13, blue: 0.24),
                    backgroundTop: SwiftUI.Color(red: 0.06, green: 0.1, blue: 0.18),
                    backgroundBottom: SwiftUI.Color(red: 0.18, green: 0.09, blue: 0.13)
                )
            )
        case "uk":
            return RSDTheme(
                light: RSDThemePalette(
                    tint: SwiftUI.Color(red: 0.05, green: 0.22, blue: 0.54),
                    navigationBar: SwiftUI.Color(red: 0.95, green: 0.96, blue: 0.99),
                    filterBar: SwiftUI.Color(red: 0.98, green: 0.97, blue: 0.98),
                    backgroundTop: SwiftUI.Color(red: 0.99, green: 0.99, blue: 1.0),
                    backgroundBottom: SwiftUI.Color(red: 0.96, green: 0.95, blue: 0.97)
                ),
                dark: RSDThemePalette(
                    tint: SwiftUI.Color(red: 0.5, green: 0.64, blue: 1.0),
                    navigationBar: SwiftUI.Color(red: 0.06, green: 0.1, blue: 0.2),
                    filterBar: SwiftUI.Color(red: 0.1, green: 0.14, blue: 0.26),
                    backgroundTop: SwiftUI.Color(red: 0.06, green: 0.1, blue: 0.2),
                    backgroundBottom: SwiftUI.Color(red: 0.2, green: 0.07, blue: 0.12)
                )
            )
        case "germany":
            return RSDTheme(
                light: RSDThemePalette(
                    tint: SwiftUI.Color(red: 0.72, green: 0.14, blue: 0.16),
                    navigationBar: SwiftUI.Color(red: 0.97, green: 0.96, blue: 0.93),
                    filterBar: SwiftUI.Color(red: 0.99, green: 0.97, blue: 0.93),
                    backgroundTop: SwiftUI.Color(red: 0.99, green: 0.99, blue: 0.97),
                    backgroundBottom: SwiftUI.Color(red: 0.96, green: 0.94, blue: 0.9)
                ),
                dark: RSDThemePalette(
                    tint: SwiftUI.Color(red: 0.98, green: 0.29, blue: 0.26),
                    navigationBar: SwiftUI.Color(red: 0.1, green: 0.1, blue: 0.1),
                    filterBar: SwiftUI.Color(red: 0.16, green: 0.13, blue: 0.1),
                    backgroundTop: SwiftUI.Color(red: 0.08, green: 0.08, blue: 0.08),
                    backgroundBottom: SwiftUI.Color(red: 0.19, green: 0.1, blue: 0.08)
                )
            )
        case "australia":
            return RSDTheme(
                light: RSDThemePalette(
                    tint: SwiftUI.Color(red: 0.06, green: 0.23, blue: 0.56),
                    navigationBar: SwiftUI.Color(red: 0.95, green: 0.98, blue: 1.0),
                    filterBar: SwiftUI.Color(red: 0.97, green: 0.98, blue: 0.96),
                    backgroundTop: SwiftUI.Color(red: 0.98, green: 1.0, blue: 0.99),
                    backgroundBottom: SwiftUI.Color(red: 0.94, green: 0.97, blue: 1.0)
                ),
                dark: RSDThemePalette(
                    tint: SwiftUI.Color(red: 0.35, green: 0.69, blue: 1.0),
                    navigationBar: SwiftUI.Color(red: 0.05, green: 0.1, blue: 0.18),
                    filterBar: SwiftUI.Color(red: 0.08, green: 0.15, blue: 0.24),
                    backgroundTop: SwiftUI.Color(red: 0.05, green: 0.1, blue: 0.18),
                    backgroundBottom: SwiftUI.Color(red: 0.08, green: 0.18, blue: 0.14)
                )
            )
        default:
            return RSDTheme(
                light: RSDThemePalette(
                    tint: SwiftUI.Color(red: 0.77, green: 0.12, blue: 0.18),
                    navigationBar: SwiftUI.Color(red: 0.97, green: 0.96, blue: 0.94),
                    filterBar: SwiftUI.Color(red: 0.99, green: 0.98, blue: 0.96),
                    backgroundTop: SwiftUI.Color(red: 0.99, green: 0.99, blue: 0.98),
                    backgroundBottom: SwiftUI.Color(red: 0.96, green: 0.95, blue: 0.93)
                ),
                dark: RSDThemePalette(
                    tint: SwiftUI.Color(red: 1.0, green: 0.36, blue: 0.39),
                    navigationBar: SwiftUI.Color(red: 0.11, green: 0.1, blue: 0.1),
                    filterBar: SwiftUI.Color(red: 0.16, green: 0.13, blue: 0.13),
                    backgroundTop: SwiftUI.Color(red: 0.1, green: 0.1, blue: 0.1),
                    backgroundBottom: SwiftUI.Color(red: 0.2, green: 0.11, blue: 0.12)
                )
            )
        }
    }
}

struct RSDTheme {
    let light: RSDThemePalette
    let dark: RSDThemePalette

    func palette(for colorScheme: ColorScheme) -> RSDThemePalette {
        colorScheme == .dark ? dark : light
    }
}

struct RSDThemePalette {
    let tint: SwiftUI.Color
    let navigationBar: SwiftUI.Color
    let filterBar: SwiftUI.Color
    let backgroundTop: SwiftUI.Color
    let backgroundBottom: SwiftUI.Color
}

final class RSDAppState: ObservableObject {
    static let shared = RSDAppState()

    private static let baseLists: [RSDListDefinition] = [
        RSDListDefinition(slug: "rsd-2017", title: "2017", subtitle: "US", resourceName: "rsd-2017.enriched"),
        RSDListDefinition(slug: "rsd-black-friday-2017", title: "2017", subtitle: "US Black Friday", resourceName: "rsd-black-friday-2017.enriched"),
        RSDListDefinition(slug: "rsd-2018", title: "2018", subtitle: "US", resourceName: "rsd-2018.enriched"),
        RSDListDefinition(slug: "rsd-black-friday-2019", title: "2019", subtitle: "US Black Friday", resourceName: "rsd-black-friday-2019.enriched"),
        RSDListDefinition(slug: "rsd-2020-us", title: "2020", subtitle: "US", resourceName: "rsd-2020-us"),
        RSDListDefinition(slug: "rsd-2020-canada", title: "2020", subtitle: "Canada", resourceName: "rsd-2020-canada"),
        RSDListDefinition(slug: "rsd-2021-us", title: "2021", subtitle: "US", resourceName: "rsd-2021-us"),
        RSDListDefinition(slug: "rsd-black-friday-2021-us", title: "2021", subtitle: "US Black Friday", resourceName: "rsd-black-friday-2021-us"),
        RSDListDefinition(slug: "rsd-2021-canada", title: "2021", subtitle: "Canada", resourceName: "rsd-2021-canada"),
        RSDListDefinition(slug: "rsd-2022-us", title: "2022", subtitle: "US", resourceName: "rsd-2022-us"),
        RSDListDefinition(slug: "rsd-2022-canada", title: "2022", subtitle: "Canada", resourceName: "rsd-2022-canada"),
        RSDListDefinition(slug: "rsd-black-friday-2022-canada", title: "2022", subtitle: "Canada Black Friday", resourceName: "rsd-black-friday-2022-canada"),
        RSDListDefinition(slug: "rsd-2022-australia", title: "2022", subtitle: "Australia", resourceName: "rsd-2022-australia"),
        RSDListDefinition(slug: "rsd-2023-us-black-friday", title: "2023", subtitle: "US Black Friday", resourceName: "rsd-black-friday-2023-us"),
        RSDListDefinition(slug: "rsd-2023-canada", title: "2023", subtitle: "Canada", resourceName: "rsd-2023-canada"),
        RSDListDefinition(slug: "rsd-2023-canada-black-friday", title: "2023", subtitle: "Canada Black Friday", resourceName: "rsd-black-friday-2023-canada"),
        RSDListDefinition(slug: "rsd-2023-germany", title: "2023", subtitle: "Germany", resourceName: "rsd-2023-germany"),
        RSDListDefinition(slug: "rsd-2023-italy", title: "2023", subtitle: "Italy", resourceName: "rsd-2023-italy"),
        RSDListDefinition(slug: "rsd-2023-uk", title: "2023", subtitle: "UK", resourceName: "rsd-2023-uk"),
        RSDListDefinition(slug: "rsd-2024-us", title: "2024", subtitle: "US", resourceName: "rsd-2024-us"),
        RSDListDefinition(slug: "rsd-2024-canada", title: "2024", subtitle: "Canada", resourceName: "rsd-2024-canada"),
        RSDListDefinition(slug: "rsd-2024-germany", title: "2024", subtitle: "Germany", resourceName: "rsd-2024-germany"),
        RSDListDefinition(slug: "rsd-2024-uk", title: "2024", subtitle: "UK", resourceName: "rsd-2024-uk"),
        RSDListDefinition(slug: "rsd-2025-us", title: "2025", subtitle: "US", resourceName: "rsd-2025-us"),
        RSDListDefinition(slug: "rsd-2025-australia", title: "2025", subtitle: "Australia", resourceName: "rsd-2025-australia"),
        RSDListDefinition(slug: "rsd-2025-canada", title: "2025", subtitle: "Canada", resourceName: "rsd-2025-canada"),
        RSDListDefinition(slug: "rsd-2025-germany", title: "2025", subtitle: "Germany", resourceName: "rsd-2025-germany"),
        RSDListDefinition(slug: "rsd-2026-us", title: "2026", subtitle: "US", resourceName: "rsd-2026-us"),
        RSDListDefinition(slug: "rsd-2026-australia", title: "2026", subtitle: "Australia", resourceName: "rsd-2026-australia"),
        RSDListDefinition(slug: "rsd-2026-canada", title: "2026", subtitle: "Canada", resourceName: "rsd-2026-canada"),
        RSDListDefinition(slug: "rsd-2026-germany", title: "2026", subtitle: "Germany", resourceName: "rsd-2026-germany"),
        RSDListDefinition(slug: "rsd-2026-uk", title: "2026", subtitle: "UK", resourceName: "rsd-2026-uk"),
    ]

    static let availableLists: [RSDListDefinition] = baseLists.sorted { lhs, rhs in
        let lhsYear = Int(lhs.title) ?? 0
        let rhsYear = Int(rhs.title) ?? 0
        if lhsYear != rhsYear {
            return lhsYear > rhsYear
        }

        func subtitleRank(_ subtitle: String) -> Int {
            let lowered = subtitle.lowercased()
            if lowered == "us" { return 0 }
            if lowered.contains("black friday") { return 1 }
            return 2
        }

        let lhsRank = subtitleRank(lhs.subtitle)
        let rhsRank = subtitleRank(rhs.subtitle)
        if lhsRank != rhsRank {
            return lhsRank < rhsRank
        }

        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }

    static let availableListsByYear: [(year: String, lists: [RSDListDefinition])] = {
        let grouped = Dictionary(grouping: availableLists, by: \.title)
        return grouped
            .map { (year: $0.key, lists: $0.value) }
            .sorted { (Int($0.year) ?? 0) > (Int($1.year) ?? 0) }
    }()

    @Published var selectedList: RSDListDefinition
    @Published var sortOption: RSDSortOption = .artist
    @Published var isSortReversed: Bool = false
    @Published var viewMode: RSDViewMode = .list
    @Published var favoritesViewMode: RSDViewMode = .list
    @Published var presentedSheet: RSDPresentedSheet?
    @Published var formatFilter: String = "All Formats"
    @Published var releaseCategoryFilter: String = "All Categories"
    @Published var quantityFilter: String = "All Quantities"
    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    private enum StorageKey {
        static let selectedListSlug = "app_state_selected_list_slug"
        static let sortOption = "app_state_sort_option"
        static let sortReversed = "app_state_sort_reversed"
        static let viewMode = "app_state_view_mode"
        static let favoritesViewMode = "app_state_favorites_view_mode"
        static let formatFilter = "app_state_format_filter"
        static let releaseCategoryFilter = "app_state_release_category_filter"
        static let quantityFilter = "app_state_quantity_filter"
    }

    private init() {
        let fallbackList = Self.availableLists.first ?? RSDListDefinition(slug: "empty", title: "Empty", subtitle: "", resourceName: "")
        if let savedSlug = defaults.string(forKey: StorageKey.selectedListSlug),
           let savedList = Self.availableLists.first(where: { $0.slug == savedSlug }) {
            selectedList = savedList
        } else {
            selectedList = fallbackList
        }

        if let savedSort = defaults.string(forKey: StorageKey.sortOption),
           let sortOption = RSDSortOption(rawValue: savedSort) {
            self.sortOption = sortOption
        }
        self.isSortReversed = defaults.bool(forKey: StorageKey.sortReversed)

        if let savedViewMode = defaults.string(forKey: StorageKey.viewMode),
           let viewMode = RSDViewMode(rawValue: savedViewMode) {
            self.viewMode = viewMode
        }
        if let savedFavoritesViewMode = defaults.string(forKey: StorageKey.favoritesViewMode),
           let favoritesViewMode = RSDViewMode(rawValue: savedFavoritesViewMode) {
            self.favoritesViewMode = favoritesViewMode
        }

        formatFilter = defaults.string(forKey: StorageKey.formatFilter) ?? "All Formats"
        releaseCategoryFilter = defaults.string(forKey: StorageKey.releaseCategoryFilter) ?? "All Categories"
        quantityFilter = defaults.string(forKey: StorageKey.quantityFilter) ?? "All Quantities"

        $selectedList
            .map(\.slug)
            .sink { [weak self] slug in
                self?.defaults.set(slug, forKey: StorageKey.selectedListSlug)
            }
            .store(in: &cancellables)

        $sortOption
            .map(\.rawValue)
            .sink { [weak self] value in
                self?.defaults.set(value, forKey: StorageKey.sortOption)
            }
            .store(in: &cancellables)

        $viewMode
            .map(\.rawValue)
            .sink { [weak self] value in
                self?.defaults.set(value, forKey: StorageKey.viewMode)
            }
            .store(in: &cancellables)

        $favoritesViewMode
            .map(\.rawValue)
            .sink { [weak self] value in
                self?.defaults.set(value, forKey: StorageKey.favoritesViewMode)
            }
            .store(in: &cancellables)

        $isSortReversed
            .sink { [weak self] value in
                self?.defaults.set(value, forKey: StorageKey.sortReversed)
            }
            .store(in: &cancellables)

        $formatFilter
            .sink { [weak self] value in
                self?.defaults.set(value, forKey: StorageKey.formatFilter)
            }
            .store(in: &cancellables)

        $releaseCategoryFilter
            .sink { [weak self] value in
                self?.defaults.set(value, forKey: StorageKey.releaseCategoryFilter)
            }
            .store(in: &cancellables)

        $quantityFilter
            .sink { [weak self] value in
                self?.defaults.set(value, forKey: StorageKey.quantityFilter)
            }
            .store(in: &cancellables)
    }
}

final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published private(set) var favoritesByList: [String: Set<String>] = [:]
    private let defaults = UserDefaults.standard
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let storageKey = "favorites_by_list_v2"

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUbiquitousStoreChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )
        ubiquitousStore.synchronize()
        favoritesByList = mergedFavorites(local: decodeFavorites(from: defaults.dictionary(forKey: storageKey)),
                                          cloud: decodeFavorites(from: ubiquitousStore.dictionary(forKey: storageKey)))
        persist()
    }

    func contains(_ listing: Listing, in list: RSDListDefinition) -> Bool {
        favoritesByList[list.slug, default: []].contains(listing.id)
    }

    func toggle(_ listing: Listing, in list: RSDListDefinition) {
        var favorites = favoritesByList[list.slug, default: []]
        if favorites.contains(listing.id) {
            favorites.remove(listing.id)
        } else {
            favorites.insert(listing.id)
        }
        favoritesByList[list.slug] = favorites
        persist()
    }

    func favorites(in list: RSDListDefinition, from listings: [Listing]) -> [Listing] {
        let ids = favoritesByList[list.slug, default: []]
        return listings.filter { ids.contains($0.id) }
    }

    private func persist() {
        let payload = serializedFavorites
        defaults.set(payload, forKey: storageKey)
        ubiquitousStore.set(payload, forKey: storageKey)
        ubiquitousStore.synchronize()
    }

    private var serializedFavorites: [String: [String]] {
        favoritesByList.reduce(into: [String: [String]]()) { partialResult, entry in
            partialResult[entry.key] = Array(entry.value).sorted()
        }
    }

    private func decodeFavorites(from value: Any?) -> [String: Set<String>] {
        guard let stored = value as? [String: [String]] else {
            return [:]
        }
        return stored.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = Set(entry.value)
        }
    }

    private func mergedFavorites(local: [String: Set<String>], cloud: [String: Set<String>]) -> [String: Set<String>] {
        let keys = Set(local.keys).union(cloud.keys)
        return keys.reduce(into: [:]) { partialResult, key in
            partialResult[key] = local[key, default: []].union(cloud[key, default: []])
        }
    }

    @objc private func handleUbiquitousStoreChange(_ notification: Notification) {
        let cloudFavorites = decodeFavorites(from: ubiquitousStore.dictionary(forKey: storageKey))
        let merged = mergedFavorites(local: favoritesByList, cloud: cloudFavorites)
        guard merged != favoritesByList else {
            return
        }
        favoritesByList = merged
        defaults.set(serializedFavorites, forKey: storageKey)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

final class ReleaseLibrary: ObservableObject {
    static let shared = ReleaseLibrary()

    @Published private(set) var releases: [Listing] = []
    @Published private(set) var currentList: RSDListDefinition = RSDAppState.availableLists.first ?? RSDListDefinition(slug: "empty", title: "Empty", subtitle: "", resourceName: "")
    @Published private(set) var loadError: String?

    func load(_ list: RSDListDefinition) {
        currentList = list
        loadError = nil

        guard let file = Bundle.main.url(forResource: list.resourceName, withExtension: "json") else {
            releases = []
            loadError = "Could not find \(list.resourceName).json in the app bundle."
            return
        }

        do {
            let data = try Data(contentsOf: file)
            releases = try ListingLoader.loadCanonicalListings(from: data)
        } catch {
            releases = []
            loadError = error.localizedDescription
        }
    }

    func sortedReleases(using sortOption: RSDSortOption) -> [Listing] {
        releases.sorted { lhs, rhs in
            switch sortOption {
            case .artist:
                return lhs.artist.localizedCaseInsensitiveCompare(rhs.artist) == .orderedAscending
            case .title:
                return lhs.album.localizedCaseInsensitiveCompare(rhs.album) == .orderedAscending
            case .format:
                return lhs.format.localizedCaseInsensitiveCompare(rhs.format) == .orderedAscending
            case .label:
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            case .category:
                return lhs.releaseCategory.localizedCaseInsensitiveCompare(rhs.releaseCategory) == .orderedAscending
            }
        }
    }
}

final class ArtworkPipeline {
    static let shared = ArtworkPipeline()

    private let imageCache = NSCache<NSURL, UIImage>()
    private let urlCache: URLCache
    private let session: URLSession
    private let maxCachedArtworkPixelSize: CGFloat = 900

    private init() {
        urlCache = URLCache(
            memoryCapacity: 24 * 1024 * 1024,
            diskCapacity: 96 * 1024 * 1024,
            diskPath: "rsd-artwork-cache"
        )

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        configuration.urlCache = urlCache
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 60
        session = URLSession(configuration: configuration)

        imageCache.countLimit = 250
        imageCache.totalCostLimit = 32 * 1024 * 1024
    }

    func cachedImage(for url: URL) -> UIImage? {
        let cacheKey = url as NSURL
        if let image = imageCache.object(forKey: cacheKey) {
            return image
        }

        let request = URLRequest(url: url)
        guard let cachedResponse = urlCache.cachedResponse(for: request),
              let image = decodedImage(from: cachedResponse.data) else {
            return nil
        }

        store(image, for: url)
        return image
    }

    func loadImage(from url: URL) async throws -> UIImage? {
        if let cached = cachedImage(for: url) {
            return cached
        }

        let request = URLRequest(url: url)
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode),
              let image = decodedImage(from: data) else {
            return nil
        }

        let cachedResponse = CachedURLResponse(response: response, data: data)
        urlCache.storeCachedResponse(cachedResponse, for: request)
        store(image, for: url)
        return image
    }

    private func store(_ image: UIImage, for url: URL) {
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale)
        imageCache.setObject(image, forKey: url as NSURL, cost: cost)
    }

    private func decodedImage(from data: Data) -> UIImage? {
        let options: [CFString: Any] = [
            kCGImageSourceShouldCache: false,
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, options as CFDictionary) else {
            return UIImage(data: data)
        }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxCachedArtworkPixelSize,
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return UIImage(data: data)
        }

        return UIImage(cgImage: cgImage)
    }
}

@MainActor
final class ArtworkLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoading = false

    private let urlString: String
    private var loadTask: Task<Void, Never>?

    init(urlString: String) {
        self.urlString = urlString
    }

    func loadIfNeeded() {
        guard image == nil, loadTask == nil, let url = URL(string: urlString), urlString.isEmpty == false else {
            return
        }

        if let cachedImage = ArtworkPipeline.shared.cachedImage(for: url) {
            image = cachedImage
            return
        }

        isLoading = true
        loadTask = Task { [url] in
            defer {
                Task { @MainActor in
                    self.isLoading = false
                    self.loadTask = nil
                }
            }

            let loadedImage = try? await ArtworkPipeline.shared.loadImage(from: url)
            guard Task.isCancelled == false else {
                return
            }

            await MainActor.run {
                self.image = loadedImage ?? self.image
            }
        }
    }

    func cancel() {
        loadTask?.cancel()
        loadTask = nil
        isLoading = false
    }
}

struct RemoteArtworkView: View {
    let urlString: String
    let contentMode: SwiftUI.ContentMode
    @StateObject private var loader: ArtworkLoader

    init(urlString: String, contentMode: SwiftUI.ContentMode = .fill) {
        self.urlString = urlString
        self.contentMode = contentMode
        _loader = StateObject(wrappedValue: ArtworkLoader(urlString: urlString))
    }

    var body: some View {
        if let image = loader.image {
            SwiftUI.Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else if urlString.isEmpty {
            placeholder
        } else {
            placeholder
                .overlay {
                    if loader.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    }
                }
                .task {
                    loader.loadIfNeeded()
                }
                .onDisappear {
                    loader.cancel()
                }
        }
    }

    private var placeholder: some View {
        SwiftUI.Rectangle()
            .fill(SwiftUI.Color(.secondarySystemBackground))
            .overlay(
                SwiftUI.Image(systemName: "opticaldisc")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundColor(SwiftUI.Color.secondary)
            )
    }
}

struct ReleaseRowView: View {
    let listing: Listing
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            RemoteArtworkView(urlString: listing.photoURL)
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.album)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text(listing.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                Text(listing.format)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            SwiftUI.Button(action: onFavoriteToggle) {
                SwiftUI.Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .foregroundColor(isFavorite ? .red : .secondary)
                    .font(.system(size: 18, weight: .semibold))
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.trailing, 18)
        }
        .padding(.vertical, 6)
    }
}

struct ReleaseGridCardView: View {
    let listing: Listing
    let isFavorite: Bool
    let onFavoriteToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RemoteArtworkView(urlString: listing.photoURL, contentMode: .fit)
                .frame(width: artworkSize, height: artworkSize)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.album)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    Text(listing.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    Text(listing.format)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                SwiftUI.Button(action: onFavoriteToggle) {
                    SwiftUI.Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isFavorite ? .red : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var artworkSize: CGFloat {
#if targetEnvironment(macCatalyst)
        196
#else
        180
#endif
    }
}

struct CoverFlowCardView: View {
    let listing: Listing
    let isFavorite: Bool
    let onTap: () -> Void
    let onFavoriteToggle: () -> Void
    let normalizedDistanceFromCenter: CGFloat

    var body: some View {
        VStack(spacing: 14) {
            SwiftUI.Button(action: onTap) {
                RemoteArtworkView(urlString: listing.photoURL, contentMode: .fit)
                    .frame(width: 230, height: 230)
                    .background(SwiftUI.Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .buttonStyle(.plain)
                .frame(width: 230, height: 230)

            VStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text(listing.album)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(listing.artist)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    Text(listing.format)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                SwiftUI.Button(action: onFavoriteToggle) {
                    SwiftUI.Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isFavorite ? .red : .secondary)
                }
                .buttonStyle(.plain)
            }
            .frame(width: 240)
        }
        .scaleEffect(coverFlowScale)
        .rotation3DEffect(
            .degrees(Double(normalizedDistanceFromCenter) * 55.0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.72
        )
        .offset(x: coverFlowHorizontalOffset, y: abs(normalizedDistanceFromCenter) * 28)
        .zIndex(1 - Double(abs(normalizedDistanceFromCenter)))
        .opacity(1 - Double(abs(normalizedDistanceFromCenter)) * 0.08)
    }

    private var coverFlowScale: CGFloat {
        1 - (abs(normalizedDistanceFromCenter) * 0.2)
    }

    private var coverFlowHorizontalOffset: CGFloat {
        -normalizedDistanceFromCenter * 40
    }
}

struct RSDRootView: View {
    @ObservedObject var appState: RSDAppState
    @ObservedObject private var library = ReleaseLibrary.shared
    @ObservedObject private var favoritesStore = FavoritesStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var selectedCoverFlowListing: Listing?
    @State private var activeSectionID: String?
    @State private var selectedTab: RSDMainTab = .releases

    private var theme: RSDThemePalette {
        appState.selectedList.theme.palette(for: colorScheme)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                ZStack {
                    LinearGradient(
                        colors: [theme.backgroundTop, theme.backgroundBottom],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    rootContent
                }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .safeAreaInset(edge: .top, spacing: 0) {
                    filterBar
                }
                .toolbar(content: toolbarContent)
                .toolbarBackground(theme.navigationBar.opacity(colorScheme == .dark ? 0.92 : 0.98), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .tint(theme.tint)
                .accentColor(theme.tint)
            }
            .tabItem {
                Label("Releases", systemImage: "music.note.list")
            }
            .tag(RSDMainTab.releases)

            StoresMapScreen(showsDoneButton: false)
                .tabItem {
                    Label("Stores", systemImage: "map")
                }
                .tag(RSDMainTab.stores)
        }
        .tint(theme.tint)
        .sheet(item: $appState.presentedSheet) { sheet in
            presentedSheetView(sheet)
        }
        .sheet(item: $selectedCoverFlowListing) { listing in
            NavigationStack {
                ReleaseDetailView(listing: listing, list: appState.selectedList)
            }
            .tint(theme.tint)
            .accentColor(theme.tint)
        }
        .onAppear {
            library.load(appState.selectedList)
        }
        .onReceive(appState.$selectedList) { list in
            library.load(list)
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if let error = library.loadError {
            SwiftUI.VStack(spacing: 16) {
                SwiftUI.Text("Unable to Load List")
                    .font(.title3)
                SwiftUI.Text(error)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            contentView
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        SwiftUI.ToolbarItem(placement: .principal) {
            EmptyView()
        }

        SwiftUI.ToolbarItem(placement: .topBarLeading) {
            releaseListMenu()
        }

        SwiftUI.ToolbarItemGroup(placement: .topBarTrailing) {
            SwiftUI.Button {
                appState.presentedSheet = .favorites
            } label: {
                SwiftUI.Image(systemName: "heart")
            }

            toolbarMenu
        }
    }

    private func releaseListMenu() -> some View {
        Menu {
            releaseListMenuContent()
        } label: {
            releaseListMenuLabel()
        }
    }

    @ViewBuilder
    private func releaseListMenuContent() -> some View {
        ForEach(RSDAppState.availableListsByYear, id: \.year) { yearGroup in
            Section(yearGroup.year) {
                ForEach(yearGroup.lists) { definition in
                    releaseListMenuButton(for: definition)
                }
            }
        }
    }

    private func releaseListMenuButton(for definition: RSDListDefinition) -> some View {
        SwiftUI.Button {
            appState.selectedList = definition
        } label: {
            if definition == appState.selectedList {
                Label(definition.subtitle, systemImage: "checkmark")
            } else {
                Text(definition.subtitle)
            }
        }
    }

    private func releaseListMenuLabel() -> some View {
        HStack(spacing: 4) {
            Text(appState.selectedList.displayName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            SwiftUI.Image(systemName: "chevron.down")
                .font(.caption.weight(.semibold))
        }
    }

    @ViewBuilder
    private func presentedSheetView(_ sheet: RSDPresentedSheet) -> some View {
        switch sheet {
        case .favorites:
            NavigationStack {
                FavoritesView(list: appState.selectedList, showsDoneButton: true)
            }
            .tint(theme.tint)
            .accentColor(theme.tint)
        case .stores:
            NavigationStack {
                StoresMapScreen(showsDoneButton: true)
            }
            .tint(theme.tint)
            .accentColor(theme.tint)
        case .settings:
            NavigationStack {
                Text("Settings")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.backgroundTop.ignoresSafeArea())
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tint(theme.tint)
            .accentColor(theme.tint)
        }
    }

    private var toolbarMenu: some View {
        Menu {
            Picker("Sort By", selection: $appState.sortOption) {
                ForEach(RSDSortOption.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }

            Toggle("Reverse Sort", isOn: $appState.isSortReversed)

            Divider()

            Picker("View", selection: $appState.viewMode) {
                ForEach(RSDViewMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }

            Divider()

            SwiftUI.Button("Clear Filters", action: clearFilters)
        } label: {
            SwiftUI.Image(systemName: "slider.horizontal.3")
        }
    }

    private func clearFilters() {
        appState.formatFilter = "All Formats"
        appState.releaseCategoryFilter = "All Categories"
        appState.quantityFilter = "All Quantities"
        searchText = ""
    }

    private var contentView: some View {
        SwiftUI.Group {
            switch appState.viewMode {
            case .list:
                ScrollViewReader { proxy in
                    ZStack(alignment: .trailing) {
                        SwiftUI.List {
                            ForEach(sectionedReleases) { section in
                                Section(section.title) {
                                    ForEach(section.listings) { listing in
                                        releaseNavigation(for: listing) {
                                            ReleaseRowView(
                                                listing: listing,
                                                isFavorite: favoritesStore.contains(listing, in: appState.selectedList),
                                                onFavoriteToggle: {
                                                    favoritesStore.toggle(listing, in: appState.selectedList)
                                                }
                                            )
                                        }
                                    }
                                }
                                .id(section.id)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)
                        .searchable(text: $searchText, prompt: "Search releases")

                        if sectionedReleases.count > 1 {
                            sectionIndexSidebar { sectionID in
                                activeSectionID = sectionID
                                withAnimation(.easeInOut(duration: 0.12)) {
                                    proxy.scrollTo(sectionID, anchor: .top)
                                }
                            }
                        }
                    }
                }

            case .grid:
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: gridMinimumWidth), spacing: gridColumnSpacing)],
                        spacing: gridRowSpacing
                    ) {
                        ForEach(filteredAndSortedReleases) { listing in
                            releaseNavigation(for: listing) {
                                ReleaseGridCardView(
                                    listing: listing,
                                    isFavorite: favoritesStore.contains(listing, in: appState.selectedList),
                                    onFavoriteToggle: {
                                        favoritesStore.toggle(listing, in: appState.selectedList)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(gridContentPadding)
                }
                .searchable(text: $searchText, prompt: "Search releases")

            case .coverFlow:
                GeometryReader { outerGeometry in
                    let cardWidth: CGFloat = 240
                    let overlapSpacing: CGFloat = -32

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: overlapSpacing) {
                            ForEach(filteredAndSortedReleases) { listing in
                                GeometryReader { itemGeometry in
                                    let frame = itemGeometry.frame(in: .global)
                                    let containerMidX = outerGeometry.frame(in: .global).midX
                                    let distance = frame.midX - containerMidX
                                    let normalizedDistance = max(-1, min(1, distance / 260))

                                    CoverFlowCardView(
                                        listing: listing,
                                        isFavorite: favoritesStore.contains(listing, in: appState.selectedList),
                                        onTap: {
                                            navigateToDetail(for: listing)
                                        },
                                        onFavoriteToggle: {
                                            favoritesStore.toggle(listing, in: appState.selectedList)
                                        },
                                        normalizedDistanceFromCenter: normalizedDistance
                                    )
                                }
                                .frame(width: cardWidth, height: 360)
                            }
                        }
                        .padding(.horizontal, max((outerGeometry.size.width - cardWidth) / 2, 24))
                        .padding(.vertical, 30)
                        .frame(minHeight: 420)
                    }
                }
                .searchable(text: $searchText, prompt: "Search releases")
            }
        }
    }

    private var filteredAndSortedReleases: [Listing] {
        let query = searchText.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)

        let filtered = library.releases.filter { listing in
            let matchesSearch = query.isEmpty || listing.searchableText.contains(query)
            let matchesFormat = appState.formatFilter == "All Formats" || listing.formatFilterValue == appState.formatFilter
            let matchesCategory = appState.releaseCategoryFilter == "All Categories" || listing.releaseCategoryFilterValue == appState.releaseCategoryFilter
            let matchesQuantity = appState.quantityFilter == "All Quantities" || listing.quantityFilterValue == appState.quantityFilter
            return matchesSearch && matchesFormat && matchesCategory && matchesQuantity
        }

        let sorted = filtered.sorted { lhs, rhs in
            switch appState.sortOption {
            case .artist:
                return lhs.artist.localizedCaseInsensitiveCompare(rhs.artist) == .orderedAscending
            case .title:
                return lhs.album.localizedCaseInsensitiveCompare(rhs.album) == .orderedAscending
            case .format:
                return lhs.format.localizedCaseInsensitiveCompare(rhs.format) == .orderedAscending
            case .label:
                return lhs.label.localizedCaseInsensitiveCompare(rhs.label) == .orderedAscending
            case .category:
                return lhs.releaseCategory.localizedCaseInsensitiveCompare(rhs.releaseCategory) == .orderedAscending
            }
        }

        return appState.isSortReversed ? sorted.reversed() : sorted
    }

    private var sectionedReleases: [ReleaseSection] {
        let grouped = Dictionary(grouping: filteredAndSortedReleases) { listing in
            sectionTitle(for: listing)
        }

        let orderedTitles = grouped.keys.sorted { lhs, rhs in
            if lhs == "#" { return true }
            if rhs == "#" { return false }
            if appState.isSortReversed {
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedDescending
            }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        return orderedTitles.map { title in
            ReleaseSection(
                id: "section-\(title)",
                title: title,
                listings: grouped[title] ?? []
            )
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                Menu {
                    Picker("Format", selection: $appState.formatFilter) {
                        Text("All Formats").tag("All Formats")
                        ForEach(availableFormats, id: \.self) { format in
                            Text(format).tag(format)
                        }
                    }
                } label: {
                    filterPill(title: "Format", value: appState.formatFilter)
                }

                if availableReleaseCategories.isEmpty == false {
                    Menu {
                        Picker("Category", selection: $appState.releaseCategoryFilter) {
                            Text("All Categories").tag("All Categories")
                            ForEach(availableReleaseCategories, id: \.self) { category in
                                Text(category).tag(category)
                            }
                        }
                    } label: {
                        filterPill(title: "Category", value: appState.releaseCategoryFilter)
                    }
                }

                if availableQuantityFilters.isEmpty == false {
                    Menu {
                        Picker("Quantity", selection: $appState.quantityFilter) {
                            Text("All Quantities").tag("All Quantities")
                            ForEach(availableQuantityFilters, id: \.self) { quantity in
                                Text(quantity).tag(quantity)
                            }
                        }
                    } label: {
                        filterPill(title: "Quantity", value: appState.quantityFilter)
                    }
                }

                Text("\(filteredAndSortedReleases.count) releases")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(theme.filterBar.opacity(colorScheme == .dark ? 0.92 : 0.96))
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.tint.opacity(colorScheme == .dark ? 0.28 : 0.16))
                .frame(height: 0.5)
        }
    }

    private func filterPill(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundColor(theme.tint)
            Text(value)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundColor(colorScheme == .dark ? .white : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            theme.tint.opacity(colorScheme == .dark ? 0.2 : 0.12),
            in: Capsule()
        )
        .overlay {
            Capsule()
                .stroke(theme.tint.opacity(colorScheme == .dark ? 0.6 : 0.34), lineWidth: 1)
        }
        .shadow(color: theme.tint.opacity(colorScheme == .dark ? 0.18 : 0.1), radius: 8, y: 2)
    }

    private var availableFormats: [String] {
        Array(Set(library.releases.map(\.formatFilterValue).filter { !$0.isEmpty })).sorted()
    }

    private var gridMinimumWidth: CGFloat {
#if targetEnvironment(macCatalyst)
        180
#else
        160
#endif
    }

    private var gridColumnSpacing: CGFloat {
#if targetEnvironment(macCatalyst)
        24
#else
        16
#endif
    }

    private var gridRowSpacing: CGFloat {
#if targetEnvironment(macCatalyst)
        26
#else
        18
#endif
    }

    private var gridContentPadding: CGFloat {
#if targetEnvironment(macCatalyst)
        24
#else
        16
#endif
    }

    private var availableReleaseCategories: [String] {
        Array(Set(library.releases.map(\.releaseCategoryFilterValue).filter { !$0.isEmpty })).sorted()
    }

    private var availableQuantityFilters: [String] {
        Listing.quantityFilterOptions.filter { option in
            library.releases.contains(where: { $0.quantityFilterValue == option })
        }
    }

    private func sectionTitle(for listing: Listing) -> String {
        let source: String
        switch appState.sortOption {
        case .artist:
            source = listing.artist
        case .title:
            source = listing.album
        case .format:
            source = listing.formatFilterValue
        case .label:
            source = listing.label
        case .category:
            source = listing.releaseCategory
        }

        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else {
            return "#"
        }

        let letter = String(first).uppercased()
        return letter.rangeOfCharacter(from: .letters) != nil ? letter : "#"
    }

    private func sectionIndexSidebar(onSelect: @escaping (String) -> Void) -> some View {
        let sections = sectionedReleases

        return GeometryReader { geometry in
            let count = max(sections.count, 1)
            let itemHeight = geometry.size.height / CGFloat(count)

            VStack(spacing: 0) {
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    Text(section.title)
                        .font(.caption2.weight(activeSectionID == section.id ? .bold : .regular))
                        .foregroundColor(activeSectionID == section.id ? .primary : .secondary)
                        .frame(width: 20, height: itemHeight)
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.vertical, 10)
            .padding(.horizontal, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let rawIndex = Int((value.location.y / max(itemHeight, 1)).rounded(.down))
                        let index = min(max(rawIndex, 0), sections.count - 1)
                        guard sections.indices.contains(index) else { return }
                        onSelect(sections[index].id)
                    }
                    .onEnded { _ in
                        activeSectionID = nil
                    }
            )
        }
        .frame(width: 32)
        .padding(.vertical, 20)
        .padding(.trailing, 2)
    }

    @ViewBuilder
    private func releaseNavigation<Content: View>(for listing: Listing, @ViewBuilder content: () -> Content) -> some View {
        NavigationLink(destination: ReleaseDetailView(listing: listing, list: appState.selectedList)) {
            content()
        }
    }

    private func navigateToDetail(for listing: Listing) {
        selectedCoverFlowListing = listing
    }
}

struct RSDSettingsView: View {
    @ObservedObject var appState: RSDAppState
    @Environment(\.presentationMode) private var presentationMode

    var body: some View {
        NavigationStack {
            Form {
                Section(header: SwiftUI.Text("Active List")) {
                    Picker("List", selection: $appState.selectedList) {
                        ForEach(RSDAppState.availableLists) { definition in
                            SwiftUI.Text(definition.displayName)
                                .tag(definition)
                        }
                    }
                }

                Section(header: SwiftUI.Text("Sort")) {
                    Picker("Sort By", selection: $appState.sortOption) {
                        ForEach(RSDSortOption.allCases) { option in
                            SwiftUI.Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    Toggle("Reverse Sort", isOn: $appState.isSortReversed)
                }

                Section(header: SwiftUI.Text("View")) {
                    Picker("View Mode", selection: $appState.viewMode) {
                        ForEach(RSDViewMode.allCases) { mode in
                            SwiftUI.Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
            }
            .navigationTitle("Lists & Sorting")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                SwiftUI.ToolbarItem(placement: .topBarTrailing) {
                    SwiftUI.Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
}
