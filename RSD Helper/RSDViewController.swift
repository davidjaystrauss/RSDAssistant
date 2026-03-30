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

struct WishlistedEntry: Identifiable {
    let list: RSDListDefinition
    let listing: Listing

    var id: String {
        "\(list.slug)::\(listing.id)"
    }
}

enum ReleaseAcquisitionStatus: String, CaseIterable, Identifiable {
    case gotIt = "got_it"
    case noLuck = "no_luck"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gotIt:
            return "Got It"
        case .noLuck:
            return "No Luck"
        }
    }

    var shortLabel: String {
        switch self {
        case .gotIt:
            return "Got It"
        case .noLuck:
            return "No Luck"
        }
    }

    var systemImage: String {
        switch self {
        case .gotIt:
            return "checkmark.circle.fill"
        case .noLuck:
            return "xmark.circle.fill"
        }
    }

    func color(using themeTint: SwiftUI.Color) -> SwiftUI.Color {
        switch self {
        case .gotIt:
            return .green
        case .noLuck:
            return .orange
        }
    }
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

    var yearLabel: String {
        title
    }

    var regionLabel: String {
        subtitle.isEmpty ? "Unknown" : subtitle
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

    static let listOrderBySlug: [String: Int] = Dictionary(
        uniqueKeysWithValues: availableLists.enumerated().map { ($0.element.slug, $0.offset) }
    )

    @Published var selectedList: RSDListDefinition
    @Published var sortOption: RSDSortOption = .artist
    @Published var isSortReversed: Bool = false
    @Published var viewMode: RSDViewMode = .grid
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
        let fallbackList = Self.defaultInitialList()
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
                guard let self else { return }
                self.defaults.set(slug, forKey: StorageKey.selectedListSlug)
                self.formatFilter = "All Formats"
                self.releaseCategoryFilter = "All Categories"
                self.quantityFilter = "All Quantities"
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

    private static func defaultInitialList() -> RSDListDefinition {
        let fallback = availableLists.first(where: { $0.slug == "rsd-2026-canada" })
            ?? availableLists.first
            ?? RSDListDefinition(slug: "empty", title: "Empty", subtitle: "", resourceName: "")

        let regionCode = Locale.current.region?.identifier.uppercased()
            ?? Locale.current.regionCode?.uppercased()
            ?? ""

        let preferredSlug: String
        switch regionCode {
        case "US":
            preferredSlug = "rsd-2026-us"
        case "CA":
            preferredSlug = "rsd-2026-canada"
        case "AU":
            preferredSlug = "rsd-2026-australia"
        case "DE":
            preferredSlug = "rsd-2026-germany"
        case "GB", "UK":
            preferredSlug = "rsd-2026-uk"
        default:
            preferredSlug = "rsd-2026-canada"
        }

        return availableLists.first(where: { $0.slug == preferredSlug }) ?? fallback
    }
}

final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()

    @Published private(set) var wishlistIDsByList: [String: [String]] = [:]
    private let defaults = UserDefaults.standard
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let storageKey = "wishlist_ids_by_list_v3"
    private let legacyStorageKey = "favorites_by_list_v2"

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUbiquitousStoreChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )
        ubiquitousStore.synchronize()
        let local = decodeWishlistIDs(
            from: defaults.dictionary(forKey: storageKey),
            legacyValue: defaults.dictionary(forKey: legacyStorageKey)
        )
        let cloud = decodeWishlistIDs(
            from: ubiquitousStore.dictionary(forKey: storageKey),
            legacyValue: ubiquitousStore.dictionary(forKey: legacyStorageKey)
        )
        wishlistIDsByList = mergedWishlistIDs(local: local, cloud: cloud)
        persist()
    }

    func contains(_ listing: Listing, in list: RSDListDefinition) -> Bool {
        wishlistIDsByList[list.slug, default: []].contains(listing.id)
    }

    func toggle(_ listing: Listing, in list: RSDListDefinition) {
        var wishlistIDs = wishlistIDsByList[list.slug, default: []]
        if let existingIndex = wishlistIDs.firstIndex(of: listing.id) {
            wishlistIDs.remove(at: existingIndex)
        } else {
            wishlistIDs.insert(listing.id, at: 0)
        }
        wishlistIDsByList[list.slug] = wishlistIDs
        persist()
    }

    func move(fromOffsets offsets: IndexSet, toOffset destination: Int, in list: RSDListDefinition) {
        var wishlistIDs = wishlistIDsByList[list.slug, default: []]
        wishlistIDs.move(fromOffsets: offsets, toOffset: destination)
        wishlistIDsByList[list.slug] = wishlistIDs
        persist()
    }

    func moveToTop(_ listing: Listing, in list: RSDListDefinition) {
        var wishlistIDs = wishlistIDsByList[list.slug, default: []]
        guard let currentIndex = wishlistIDs.firstIndex(of: listing.id), currentIndex != 0 else {
            return
        }
        wishlistIDs.remove(at: currentIndex)
        wishlistIDs.insert(listing.id, at: 0)
        wishlistIDsByList[list.slug] = wishlistIDs
        persist()
    }

    func sortByArtist(in list: RSDListDefinition, from listings: [Listing]) {
        sort(in: list, from: listings) {
            ($0.artist.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current),
             $0.album.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
            <
            ($1.artist.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current),
             $1.album.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
        }
    }

    func sortByTitle(in list: RSDListDefinition, from listings: [Listing]) {
        sort(in: list, from: listings) {
            ($0.album.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current),
             $0.artist.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
            <
            ($1.album.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current),
             $1.artist.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
        }
    }

    func sortByGotIt(in list: RSDListDefinition, from listings: [Listing], statuses: [String: ReleaseAcquisitionStatus]) {
        sort(in: list, from: listings) { lhs, rhs in
            let lhsGotIt = statuses[lhs.id] == .gotIt
            let rhsGotIt = statuses[rhs.id] == .gotIt
            if lhsGotIt != rhsGotIt {
                return lhsGotIt && !rhsGotIt
            }

            let lhsNoLuck = statuses[lhs.id] == .noLuck
            let rhsNoLuck = statuses[rhs.id] == .noLuck
            if lhsNoLuck != rhsNoLuck {
                return !lhsNoLuck && rhsNoLuck
            }

            return
                (lhs.artist.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current),
                 lhs.album.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
                <
                (rhs.artist.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current),
                 rhs.album.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
        }
    }

    func clear(in list: RSDListDefinition) {
        wishlistIDsByList[list.slug] = []
        persist()
    }

    func favorites(in list: RSDListDefinition, from listings: [Listing]) -> [Listing] {
        let listingByID = Dictionary(uniqueKeysWithValues: listings.map { ($0.id, $0) })
        return wishlistIDsByList[list.slug, default: []].compactMap { listingByID[$0] }
    }

    func allWishlistedEntries(
        lists: [RSDListDefinition],
        listingsResolver: (RSDListDefinition) -> [Listing]
    ) -> [WishlistedEntry] {
        lists.flatMap { list -> [WishlistedEntry] in
            let listings = listingsResolver(list)
            let listingByID = Dictionary(uniqueKeysWithValues: listings.map { ($0.id, $0) })
            return wishlistIDsByList[list.slug, default: []].compactMap { listingID -> WishlistedEntry? in
                guard let listing = listingByID[listingID] else {
                    return nil
                }
                return WishlistedEntry(list: list, listing: listing)
            }
        }
    }

    private func sort(in list: RSDListDefinition, from listings: [Listing], by areInIncreasingOrder: (Listing, Listing) -> Bool) {
        let listingByID = Dictionary(uniqueKeysWithValues: listings.map { ($0.id, $0) })
        let sortedIDs = wishlistIDsByList[list.slug, default: []]
            .compactMap { listingByID[$0] }
            .sorted(by: areInIncreasingOrder)
            .map(\.id)
        wishlistIDsByList[list.slug] = sortedIDs
        persist()
    }

    private func persist() {
        let payload = serializedWishlistIDs
        defaults.set(payload, forKey: storageKey)
        defaults.set(payload, forKey: legacyStorageKey)
        ubiquitousStore.set(payload, forKey: storageKey)
        ubiquitousStore.set(payload, forKey: legacyStorageKey)
        ubiquitousStore.synchronize()
    }

    private var serializedWishlistIDs: [String: [String]] {
        wishlistIDsByList.reduce(into: [String: [String]]()) { partialResult, entry in
            partialResult[entry.key] = entry.value
        }
    }

    private func decodeWishlistIDs(from value: Any?, legacyValue: Any?) -> [String: [String]] {
        guard let stored = value as? [String: [String]] else {
            return decodeLegacyWishlistIDs(from: legacyValue)
        }
        return stored.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = deduplicated(entry.value)
        }
    }

    private func decodeLegacyWishlistIDs(from value: Any?) -> [String: [String]] {
        guard let stored = value as? [String: [String]] else {
            return [:]
        }
        return stored.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = deduplicated(entry.value)
        }
    }

    private func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func mergedWishlistIDs(local: [String: [String]], cloud: [String: [String]]) -> [String: [String]] {
        let keys = Set(local.keys).union(cloud.keys)
        return keys.reduce(into: [:]) { partialResult, key in
            var merged = cloud[key, default: []]
            for listingID in local[key, default: []] where merged.contains(listingID) == false {
                merged.append(listingID)
            }
            partialResult[key] = merged
        }
    }

    @objc private func handleUbiquitousStoreChange(_ notification: Notification) {
        let cloudWishlistIDs = decodeWishlistIDs(
            from: ubiquitousStore.dictionary(forKey: storageKey),
            legacyValue: ubiquitousStore.dictionary(forKey: legacyStorageKey)
        )
        let merged = mergedWishlistIDs(local: wishlistIDsByList, cloud: cloudWishlistIDs)
        guard merged != wishlistIDsByList else {
            return
        }
        wishlistIDsByList = merged
        let payload = serializedWishlistIDs
        defaults.set(payload, forKey: storageKey)
        defaults.set(payload, forKey: legacyStorageKey)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

final class ReleaseStatusStore: ObservableObject {
    static let shared = ReleaseStatusStore()

    @Published private(set) var statusByList: [String: [String: String]] = [:]
    private let defaults = UserDefaults.standard
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private let storageKey = "release_status_by_list_v1"

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleUbiquitousStoreChange(_:)),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )
        ubiquitousStore.synchronize()
        let local = decodeStatuses(from: defaults.dictionary(forKey: storageKey))
        let cloud = decodeStatuses(from: ubiquitousStore.dictionary(forKey: storageKey))
        statusByList = mergedStatuses(local: local, cloud: cloud)
        persist()
    }

    func status(for listing: Listing, in list: RSDListDefinition) -> ReleaseAcquisitionStatus? {
        guard let rawValue = statusByList[list.slug]?[listing.id] else {
            return nil
        }
        return ReleaseAcquisitionStatus(rawValue: rawValue)
    }

    func setStatus(_ status: ReleaseAcquisitionStatus?, for listing: Listing, in list: RSDListDefinition) {
        var statuses = statusByList[list.slug, default: [:]]
        if let status {
            statuses[listing.id] = status.rawValue
        } else {
            statuses.removeValue(forKey: listing.id)
        }
        statusByList[list.slug] = statuses
        persist()
    }

    func clear(in list: RSDListDefinition) {
        statusByList[list.slug] = [:]
        persist()
    }

    private func persist() {
        let payload = statusByList
        defaults.set(payload, forKey: storageKey)
        ubiquitousStore.set(payload, forKey: storageKey)
        ubiquitousStore.synchronize()
    }

    private func decodeStatuses(from value: Any?) -> [String: [String: String]] {
        guard let stored = value as? [String: [String: String]] else {
            return [:]
        }
        return stored.reduce(into: [:]) { partialResult, entry in
            partialResult[entry.key] = entry.value.reduce(into: [:]) { normalizedStatuses, statusEntry in
                let normalizedValue: String
                switch statusEntry.value {
                case "found_it":
                    normalizedValue = ReleaseAcquisitionStatus.gotIt.rawValue
                case ReleaseAcquisitionStatus.gotIt.rawValue, ReleaseAcquisitionStatus.noLuck.rawValue:
                    normalizedValue = statusEntry.value
                default:
                    return
                }
                normalizedStatuses[statusEntry.key] = normalizedValue
            }
        }
    }

    private func mergedStatuses(local: [String: [String: String]], cloud: [String: [String: String]]) -> [String: [String: String]] {
        let keys = Set(local.keys).union(cloud.keys)
        return keys.reduce(into: [String: [String: String]]()) { partialResult, key in
            var merged = local[key, default: [:]]
            for (listingID, status) in cloud[key, default: [:]] {
                if merged[listingID] == nil {
                    merged[listingID] = status
                }
            }
            partialResult[key] = merged
        }
    }

    @objc private func handleUbiquitousStoreChange(_ notification: Notification) {
        let cloudStatuses = decodeStatuses(from: ubiquitousStore.dictionary(forKey: storageKey))
        let merged = mergedStatuses(local: statusByList, cloud: cloudStatuses)
        guard merged != statusByList else {
            return
        }
        statusByList = merged
        defaults.set(statusByList, forKey: storageKey)
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
    private var cachedListingsBySlug: [String: [Listing]] = [:]

    func load(_ list: RSDListDefinition) {
        currentList = list
        loadError = nil
        do {
            releases = try loadListings(for: list)
        } catch {
            releases = []
            loadError = error.localizedDescription
        }
    }

    func listings(for list: RSDListDefinition) -> [Listing] {
        (try? loadListings(for: list)) ?? []
    }

    private func loadListings(for list: RSDListDefinition) throws -> [Listing] {
        if let cached = cachedListingsBySlug[list.slug] {
            return cached
        }

        guard let file = Bundle.main.url(forResource: list.resourceName, withExtension: "json") else {
            throw NSError(domain: "RSDHelper.ReleaseLibrary", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Could not find \(list.resourceName).json in the app bundle."
            ])
        }

        let data = try Data(contentsOf: file)
        let loadedListings = try ListingLoader.loadCanonicalListings(from: data)
        cachedListingsBySlug[list.slug] = loadedListings
        return loadedListings
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
    static let isArtworkLoadingEnabled = true

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

    enum LoadPriority {
        case normal
        case high

        var taskPriority: TaskPriority {
            switch self {
            case .normal:
                return .utility
            case .high:
                return .userInitiated
            }
        }

        var urlSessionPriority: Float {
            switch self {
            case .normal:
                return URLSessionTask.defaultPriority
            case .high:
                return URLSessionTask.highPriority
            }
        }
    }

    func cachedImage(for url: URL) -> UIImage? {
        guard Self.isArtworkLoadingEnabled else {
            return nil
        }

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

    func loadImage(from url: URL, priority: LoadPriority = .normal) async throws -> UIImage? {
        guard Self.isArtworkLoadingEnabled else {
            return nil
        }

        if let cached = cachedImage(for: url) {
            return cached
        }

        let request = URLRequest(url: url)
        let (data, response) = try await data(for: request, priority: priority)

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

    private func data(for request: URLRequest, priority: LoadPriority) async throws -> (Data, URLResponse) {
        let taskBox = LockedTaskBox()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let dataTask = session.dataTask(with: request) { data, response, error in
                    if let error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let data, let response else {
                        continuation.resume(throwing: URLError(.badServerResponse))
                        return
                    }

                    continuation.resume(returning: (data, response))
                }
                dataTask.priority = priority.urlSessionPriority
                taskBox.task = dataTask
                dataTask.resume()
            }
        } onCancel: {
            taskBox.task?.cancel()
        }
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

private final class LockedTaskBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storedTask: URLSessionTask?

    var task: URLSessionTask? {
        get {
            lock.lock()
            defer { lock.unlock() }
            return storedTask
        }
        set {
            lock.lock()
            storedTask = newValue
            lock.unlock()
        }
    }
}

@MainActor
final class ArtworkLoader: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isLoading = false

    private let urlString: String
    private let priority: ArtworkPipeline.LoadPriority
    private var loadTask: Task<Void, Never>?

    init(urlString: String, priority: ArtworkPipeline.LoadPriority = .normal) {
        self.urlString = urlString
        self.priority = priority
    }

    func loadIfNeeded() {
        guard ArtworkPipeline.isArtworkLoadingEnabled else {
            return
        }

        guard image == nil, loadTask == nil, let url = URL(string: urlString), urlString.isEmpty == false else {
            return
        }

        if let cachedImage = ArtworkPipeline.shared.cachedImage(for: url) {
            image = cachedImage
            return
        }

        isLoading = true
        loadTask = Task(priority: priority.taskPriority) { [url, priority] in
            defer {
                Task { @MainActor in
                    self.isLoading = false
                    self.loadTask = nil
                }
            }

            let loadedImage = try? await ArtworkPipeline.shared.loadImage(from: url, priority: priority)
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

struct RSDRecordPlaceholderStyle: Equatable {
    let discCount: Int
    let sizeScale: CGFloat

    static let standard = RSDRecordPlaceholderStyle(discCount: 1, sizeScale: 1)

    static func from(format: String) -> RSDRecordPlaceholderStyle {
        let normalized = format
            .lowercased()
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "″", with: "\"")
            .replacingOccurrences(of: "’", with: "'")

        let discCount = parsedDiscCount(from: normalized)
        let isSevenInch = normalized.range(of: #"\b7\s*(\"|inch|in)\b"#, options: .regularExpression) != nil
            || normalized.contains("7-inch")
            || normalized.contains("7 inch")

        return RSDRecordPlaceholderStyle(
            discCount: min(max(discCount, 1), 3),
            sizeScale: isSevenInch ? 0.76 : 1
        )
    }

    private static func parsedDiscCount(from normalizedFormat: String) -> Int {
        let patterns = [
            #"\b([2-9])\s*x\s*lp\b"#,
            #"\b([2-9])\s*lp\b"#,
            #"\b([2-9])lp\b"#,
        ]

        for pattern in patterns {
            guard let expression = try? NSRegularExpression(pattern: pattern, options: []) else {
                continue
            }

            let range = NSRange(normalizedFormat.startIndex..., in: normalizedFormat)
            guard let match = expression.firstMatch(in: normalizedFormat, options: [], range: range),
                  let captureRange = Range(match.range(at: 1), in: normalizedFormat),
                  let value = Int(normalizedFormat[captureRange]) else {
                continue
            }
            return value
        }

        if normalizedFormat.contains("double lp") {
            return 2
        }
        if normalizedFormat.contains("triple lp") {
            return 3
        }

        return 1
    }
}

enum RSDPlaceholderArt {
    static func image(
        size: CGFloat = 240,
        style: RSDRecordPlaceholderStyle = .standard,
        userInterfaceStyle: UIUserInterfaceStyle = .unspecified
    ) -> UIImage {
        let resolvedTraits = UITraitCollection(userInterfaceStyle: userInterfaceStyle)
        let colorScheme: ColorScheme = userInterfaceStyle == .dark ? .dark : .light
        let palette = RSDAppState.shared.selectedList.theme.palette(for: colorScheme)
        let backgroundTopColor = UIColor(palette.backgroundTop)
        let backgroundBottomColor = UIColor(palette.backgroundBottom)
        let backgroundColor = UIColor.secondarySystemBackground.resolvedColor(with: resolvedTraits)
        let ringColor = UIColor.white.withAlphaComponent(userInterfaceStyle == .dark ? 0.62 : 0.58)
        let innerRingColor = UIColor.white.withAlphaComponent(userInterfaceStyle == .dark ? 0.18 : 0.16)
        let recordGradientColors = userInterfaceStyle == .dark
            ? [UIColor(white: 0.72, alpha: 1).cgColor, UIColor(white: 0.42, alpha: 1).cgColor, UIColor(white: 0.16, alpha: 1).cgColor]
            : [UIColor(white: 0.78, alpha: 1).cgColor, UIColor(white: 0.50, alpha: 1).cgColor, UIColor(white: 0.28, alpha: 1).cgColor]

        let format = UIGraphicsImageRendererFormat()
        format.scale = UIScreen.main.scale
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format)

        return renderer.image { context in
            let cgContext = context.cgContext
            let bounds = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            let cornerRadius = size * 0.12

            let panelPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
            cgContext.saveGState()
            panelPath.addClip()
            let panelGradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    backgroundTopColor.withAlphaComponent(userInterfaceStyle == .dark ? 0.92 : 0.98).cgColor,
                    backgroundBottomColor.withAlphaComponent(userInterfaceStyle == .dark ? 0.96 : 0.98).cgColor,
                ] as CFArray,
                locations: [0.0, 1.0]
            )!
            cgContext.drawLinearGradient(
                panelGradient,
                start: CGPoint(x: bounds.midX, y: bounds.minY),
                end: CGPoint(x: bounds.midX, y: bounds.maxY),
                options: []
            )
            cgContext.restoreGState()

            backgroundColor.withAlphaComponent(userInterfaceStyle == .dark ? 0.18 : 0.1).setStroke()
            panelPath.lineWidth = 1
            panelPath.stroke()

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let recordGradient = CGGradient(colorsSpace: colorSpace, colors: recordGradientColors as CFArray, locations: [0.0, 0.52, 1.0])!
            let discLayouts = discLayouts(for: style.discCount)
            let baseRadius = size * 0.39 * style.sizeScale

            for layout in discLayouts {
                let recordCenter = CGPoint(
                    x: size * 0.5 + layout.offset.width * size,
                    y: size * 0.5 + layout.offset.height * size
                )
                drawRecord(
                    in: cgContext,
                    center: recordCenter,
                    radius: baseRadius,
                    size: size,
                    gradient: recordGradient,
                    ringColor: ringColor.withAlphaComponent(layout.alpha),
                    innerRingColor: innerRingColor.withAlphaComponent(layout.alpha),
                    labelColor: UIColor(white: 0.76, alpha: 0.74 * layout.alpha),
                    centerColor: UIColor.white.withAlphaComponent((userInterfaceStyle == .dark ? 0.94 : 0.9) * layout.alpha),
                    spindleColor: UIColor(white: 0.25, alpha: layout.alpha)
                )
            }
        }
    }

    private static func discLayouts(for discCount: Int) -> [(offset: CGSize, alpha: CGFloat)] {
        switch discCount {
        case 2:
            return [
                (CGSize(width: -0.07, height: -0.015), 0.74),
                (CGSize(width: 0.065, height: 0.03), 1.0),
            ]
        case 3:
            return [
                (CGSize(width: -0.11, height: -0.03), 0.62),
                (CGSize(width: 0, height: 0), 0.8),
                (CGSize(width: 0.11, height: 0.03), 1.0),
            ]
        default:
            return [(CGSize.zero, 1.0)]
        }
    }

    private static func drawRecord(
        in cgContext: CGContext,
        center: CGPoint,
        radius: CGFloat,
        size: CGFloat,
        gradient: CGGradient,
        ringColor: UIColor,
        innerRingColor: UIColor,
        labelColor: UIColor,
        centerColor: UIColor,
        spindleColor: UIColor
    ) {
        cgContext.saveGState()
        UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: .pi * 2, clockwise: true).addClip()
        cgContext.drawRadialGradient(
            gradient,
            startCenter: CGPoint(x: center.x - size * 0.035, y: center.y - size * 0.08),
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: []
        )
        cgContext.restoreGState()

        ringColor.setStroke()
        for radiusMultiplier in [0.82, 0.68, 0.54] {
            let path = UIBezierPath(arcCenter: center, radius: radius * radiusMultiplier, startAngle: 0, endAngle: .pi * 2, clockwise: true)
            path.lineWidth = size * 0.011
            path.stroke()
        }

        innerRingColor.setStroke()
        let innerGroove = UIBezierPath(arcCenter: center, radius: radius * 0.4, startAngle: 0, endAngle: .pi * 2, clockwise: true)
        innerGroove.lineWidth = size * 0.008
        innerGroove.stroke()

        labelColor.setFill()
        UIBezierPath(arcCenter: center, radius: radius * 0.3, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()
        centerColor.setFill()
        UIBezierPath(arcCenter: center, radius: radius * 0.078, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()
        spindleColor.setFill()
        UIBezierPath(arcCenter: center, radius: radius * 0.026, startAngle: 0, endAngle: .pi * 2, clockwise: true).fill()
    }
}

struct RSDRecordToteMark: View {
    let animated: Bool
    let style: RSDRecordPlaceholderStyle
    @ObservedObject private var appState = RSDAppState.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var loaderScale: CGFloat = 0.96
    @State private var loaderOpacity: Double = 0.82

    private var theme: RSDThemePalette {
        appState.selectedList.theme.palette(for: colorScheme)
    }

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            let recordFill = RadialGradient(
                colors: [
                    SwiftUI.Color(white: colorScheme == .dark ? 0.74 : 0.8),
                    SwiftUI.Color(white: colorScheme == .dark ? 0.42 : 0.5),
                    SwiftUI.Color(white: colorScheme == .dark ? 0.16 : 0.28),
                ],
                center: .init(x: 0.46, y: 0.34),
                startRadius: 0,
                endRadius: size * 0.42
            )

            ZStack {
                RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                theme.backgroundTop.opacity(colorScheme == .dark ? 0.94 : 0.98),
                                theme.backgroundBottom.opacity(colorScheme == .dark ? 0.98 : 0.98),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RoundedRectangle(cornerRadius: size * 0.12, style: .continuous)
                    .stroke(SwiftUI.Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.08), lineWidth: 1)

                ZStack {
                    ForEach(Array(discLayouts.enumerated()), id: \.offset) { entry in
                        let layout = entry.element
                        recordDiscView(size: size, fill: recordFill)
                            .opacity(layout.opacity)
                            .offset(x: layout.offset.width * size, y: layout.offset.height * size)
                    }
                }
                .scaleEffect(animated ? loaderScale : 1)
                .opacity(animated ? loaderOpacity : 1)
            }
            .onAppear {
                guard animated else { return }
                withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                    loaderScale = 1
                    loaderOpacity = 1
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var discLayouts: [(offset: CGSize, opacity: Double)] {
        switch style.discCount {
        case 2:
            return [
                (CGSize(width: -0.07, height: -0.015), 0.74),
                (CGSize(width: 0.065, height: 0.03), 1.0),
            ]
        case 3:
            return [
                (CGSize(width: -0.11, height: -0.03), 0.62),
                (CGSize(width: 0, height: 0), 0.8),
                (CGSize(width: 0.11, height: 0.03), 1.0),
            ]
        default:
            return [(CGSize.zero, 1.0)]
        }
    }

    @ViewBuilder
    private func recordDiscView(size: CGFloat, fill: RadialGradient) -> some View {
        let discSize = size * 0.78 * style.sizeScale

        Circle()
            .fill(fill)
            .frame(width: discSize, height: discSize)
            .overlay {
                Circle().stroke(SwiftUI.Color.white.opacity(0.58), lineWidth: size * 0.011).padding(discSize * 0.09)
                Circle().stroke(SwiftUI.Color.white.opacity(0.34), lineWidth: size * 0.011).padding(discSize * 0.16)
                Circle().stroke(SwiftUI.Color.white.opacity(0.18), lineWidth: size * 0.01).padding(discSize * 0.23)
                Circle().stroke(SwiftUI.Color.white.opacity(0.14), lineWidth: size * 0.008).padding(discSize * 0.3)
                Circle().fill(SwiftUI.Color(white: 0.68).opacity(0.74)).frame(width: discSize * 0.3, height: discSize * 0.3)
                Circle().fill(SwiftUI.Color.white.opacity(0.9)).frame(width: discSize * 0.078, height: discSize * 0.078)
                Circle().fill(SwiftUI.Color(white: 0.24)).frame(width: discSize * 0.026, height: discSize * 0.026)
            }
    }
}

struct RemoteArtworkView: View {
    let urlString: String
    let contentMode: SwiftUI.ContentMode
    let placeholderStyle: RSDRecordPlaceholderStyle
    @StateObject private var loader: ArtworkLoader

    init(
        urlString: String,
        contentMode: SwiftUI.ContentMode = .fill,
        placeholderStyle: RSDRecordPlaceholderStyle = .standard,
        priority: ArtworkPipeline.LoadPriority = .normal
    ) {
        self.urlString = urlString
        self.contentMode = contentMode
        self.placeholderStyle = placeholderStyle
        _loader = StateObject(wrappedValue: ArtworkLoader(urlString: urlString, priority: priority))
    }

    var body: some View {
        if let image = loader.image {
            SwiftUI.Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } else if urlString.isEmpty {
            placeholder
        } else {
            placeholder(animated: loader.isLoading)
                .task {
                    loader.loadIfNeeded()
                }
                .onDisappear {
                    loader.cancel()
                }
        }
    }

    private var placeholder: some View {
        placeholder(animated: false)
    }

    private func placeholder(animated: Bool) -> some View {
        RSDRecordToteMark(animated: animated, style: placeholderStyle)
    }
}

struct ReleaseRowView: View {
    let listing: Listing
    let isFavorite: Bool
    let themeTint: SwiftUI.Color
    let status: ReleaseAcquisitionStatus?
    let onFavoriteToggle: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: 14) {
            RemoteArtworkView(urlString: listing.photoURL, placeholderStyle: .from(format: listing.format))
                .frame(width: 68, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(listing.album)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                Text(listing.artist)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                if let status {
                    StatusBadge(status: status, themeTint: themeTint, usesCompactLabel: false)
                }
                Text(listing.format)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            SwiftUI.Button(action: onFavoriteToggle) {
                SwiftUI.Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                    .foregroundColor(isFavorite ? themeTint : .secondary)
                    .font(.system(size: 18, weight: .semibold))
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.trailing, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(themeTint.opacity(colorScheme == .dark ? 0.16 : 0.08))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(themeTint.opacity(colorScheme == .dark ? 0.28 : 0.16), lineWidth: 1)
        }
    }
}

struct ReleaseGridCardView: View {
    let listing: Listing
    let isFavorite: Bool
    let themeTint: SwiftUI.Color
    let subtitleText: String?
    let status: ReleaseAcquisitionStatus?
    let onFavoriteToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RemoteArtworkView(
                urlString: listing.photoURL,
                contentMode: .fit,
                placeholderStyle: .from(format: listing.format)
            )
                .frame(width: artworkSize, height: artworkSize)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

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
                    if let status {
                        StatusBadge(status: status, themeTint: themeTint, usesCompactLabel: true)
                    }
                    if let subtitleText, subtitleText.isEmpty == false {
                        Text(subtitleText)
                            .font(.caption)
                            .foregroundColor(themeTint)
                            .lineLimit(1)
                    }
                    Text(listing.format)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                SwiftUI.Button(action: onFavoriteToggle) {
                    SwiftUI.Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isFavorite ? themeTint : .secondary)
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
    let themeTint: SwiftUI.Color
    let cardWidth: CGFloat
    let showsMetadata: Bool
    let subtitleText: String?
    let status: ReleaseAcquisitionStatus?
    let prefersCompactArtwork: Bool
    let onTap: () -> Void
    let onFavoriteToggle: () -> Void
    let normalizedDistanceFromCenter: CGFloat

    var body: some View {
        VStack(spacing: prefersCompactArtwork ? 10 : 14) {
            SwiftUI.Button(action: onTap) {
                RemoteArtworkView(
                    urlString: listing.photoURL,
                    contentMode: .fit,
                    placeholderStyle: .from(format: listing.format)
                )
                    .frame(width: artworkDimension, height: artworkDimension)
                    .background(SwiftUI.Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
                .frame(width: artworkDimension, height: artworkDimension)

            if showsMetadata {
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
                        if let status {
                            StatusBadge(status: status, themeTint: themeTint, usesCompactLabel: true)
                        }
                        if let subtitleText, subtitleText.isEmpty == false {
                            Text(subtitleText)
                                .font(.caption)
                                .foregroundColor(themeTint)
                                .multilineTextAlignment(.center)
                                .lineLimit(1)
                        }
                        Text(listing.format)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    SwiftUI.Button(action: onFavoriteToggle) {
                        SwiftUI.Image(systemName: isFavorite ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isFavorite ? themeTint : .secondary)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: cardWidth)
            }
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

    private var artworkDimension: CGFloat {
        let isPad = UIDevice.current.userInterfaceIdiom == .pad
        let scale: CGFloat = prefersCompactArtwork ? 0.88 : 1
        if prefersCompactArtwork {
            return min(cardWidth * scale, isPad ? 680 : 340)
        }
        return min(cardWidth * scale, isPad ? 520 : 360)
    }
}

struct StatusBadge: View {
    let status: ReleaseAcquisitionStatus
    let themeTint: SwiftUI.Color
    let usesCompactLabel: Bool

    var body: some View {
        HStack(spacing: 4) {
            SwiftUI.Image(systemName: status.systemImage)
                .font(.system(size: 10, weight: .bold))

            Text(usesCompactLabel ? status.shortLabel : status.label)
                .font(.caption2.weight(.semibold))
        }
        .foregroundColor(status.color(using: themeTint))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(status.color(using: themeTint).opacity(0.14))
            )
    }
}

private struct CoverFlowSearchModifier: ViewModifier {
    let isEnabled: Bool
    @Binding var text: String

    func body(content: Content) -> some View {
        if isEnabled {
            content.searchable(text: $text, prompt: "Search releases")
        } else {
            content
        }
    }
}

struct RSDRootView: View {
    @ObservedObject var appState: RSDAppState
    @ObservedObject private var library = ReleaseLibrary.shared
    @ObservedObject private var favoritesStore = FavoritesStore.shared
    @ObservedObject private var releaseStatusStore = ReleaseStatusStore.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchText = ""
    @State private var selectedCoverFlowListing: Listing?
    @State private var activeSectionID: String?
    @State private var selectedTab: RSDMainTab = .releases
    @State private var showsStartupAnimation = false
    @State private var showsImmersiveCoverFlowHint = false

    private var theme: RSDThemePalette {
        appState.selectedList.theme.palette(for: colorScheme)
    }

    init(appState: RSDAppState) {
        self.appState = appState
        let library = ReleaseLibrary.shared
        if library.releases.isEmpty || library.currentList.slug != appState.selectedList.slug {
            library.load(appState.selectedList)
        }
    }

    var body: some View {
        ZStack {
            GeometryReader { geometry in
                let isLandscape = geometry.size.width > geometry.size.height
                #if targetEnvironment(macCatalyst)
                let supportsImmersiveCoverFlow = false
                #else
                let supportsImmersiveCoverFlow = true
                #endif
                let isImmersiveCoverFlow = supportsImmersiveCoverFlow && appState.viewMode == .coverFlow && geometry.size.width > geometry.size.height

                TabView(selection: $selectedTab) {
                    releasesTab(isImmersiveCoverFlow: isImmersiveCoverFlow, isLandscape: isLandscape)
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
                .onAppear {
                    maybePresentImmersiveCoverFlowHint(isImmersive: isImmersiveCoverFlow)
                }
                .onChange(of: isImmersiveCoverFlow) { isImmersive in
                    maybePresentImmersiveCoverFlowHint(isImmersive: isImmersive)
                }
            }

            if showsStartupAnimation {
                RSDLaunchOverlayView {
                    withAnimation(.easeOut(duration: 0.18)) {
                        showsStartupAnimation = false
                    }
                }
                .transition(.opacity)
            }

            if showsImmersiveCoverFlowHint, selectedTab == .releases {
                RSDImmersiveCoverFlowHintView {
                    dismissImmersiveCoverFlowHint(markAsSeen: true)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
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
            if !RSDStartupPresentationState.hasPresented {
                RSDStartupPresentationState.hasPresented = true
                showsStartupAnimation = true
            }
        }
        .onReceive(appState.$selectedList) { list in
            if library.currentList.slug != list.slug || library.releases.isEmpty {
                library.load(list)
            }
            searchText = ""
        }
    }

    private func maybePresentImmersiveCoverFlowHint(isImmersive: Bool) {
        guard isImmersive,
              !showsStartupAnimation,
              !RSDStartupPresentationState.hasSeenImmersiveCoverFlowHint else {
            return
        }

        withAnimation(.spring(response: 0.36, dampingFraction: 0.9)) {
            showsImmersiveCoverFlowHint = true
        }
    }

    private func dismissImmersiveCoverFlowHint(markAsSeen: Bool) {
        if markAsSeen {
            RSDStartupPresentationState.hasSeenImmersiveCoverFlowHint = true
        }

        guard showsImmersiveCoverFlowHint else { return }
        withAnimation(.easeOut(duration: 0.22)) {
            showsImmersiveCoverFlowHint = false
        }
    }

    private func releasesTab(isImmersiveCoverFlow: Bool, isLandscape: Bool) -> some View {
        Group {
            if isImmersiveCoverFlow {
                NavigationStack {
                    ZStack {
                        LinearGradient(
                            colors: [theme.backgroundTop, theme.backgroundBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()

                        rootContent(isImmersiveCoverFlow: true, isLandscape: isLandscape)
                    }
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar(.hidden, for: .navigationBar)
                    .toolbar(.hidden, for: .tabBar)
                    .tint(theme.tint)
                    .accentColor(theme.tint)
                }
            } else {
                NavigationStack {
                    ZStack {
                        LinearGradient(
                            colors: [theme.backgroundTop, theme.backgroundBottom],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .ignoresSafeArea()

                        rootContent(isImmersiveCoverFlow: false, isLandscape: isLandscape)
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
            }
        }
    }

    @ViewBuilder
    private func rootContent(isImmersiveCoverFlow: Bool, isLandscape: Bool) -> some View {
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
            contentView(isImmersiveCoverFlow: isImmersiveCoverFlow, isLandscape: isLandscape)
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
                SwiftUI.Image(systemName: "bookmark")
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
            FavoritesView(list: appState.selectedList, showsDoneButton: true)
#if targetEnvironment(macCatalyst)
            .frame(minWidth: 760, idealWidth: 980, maxWidth: .infinity, minHeight: 620, idealHeight: 760, maxHeight: .infinity)
#endif
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

    private func contentView(isImmersiveCoverFlow: Bool, isLandscape: Bool) -> some View {
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
                                                themeTint: theme.tint,
                                                status: releaseStatusStore.status(for: listing, in: appState.selectedList),
                                                onFavoriteToggle: {
                                                    favoritesStore.toggle(listing, in: appState.selectedList)
                                                }
                                            )
                                        }
                                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                        .listRowBackground(SwiftUI.Color.clear)
                                    }
                                }
                                .id(section.id)
                            }
                        }
                        .listStyle(PlainListStyle())
                        .scrollContentBackground(.hidden)
                        .searchable(text: $searchText, prompt: "Search releases")

                        if sectionedReleases.count > 1 && isLandscape == false {
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
                let landscapeColumnSpacing = isLandscape ? gridColumnSpacing + 6 : gridColumnSpacing
                let landscapeRowSpacing = isLandscape ? gridRowSpacing + 6 : gridRowSpacing
                let landscapeContentPadding = isLandscape ? max(gridContentPadding - 4, 10) : gridContentPadding
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: gridMinimumWidth), spacing: landscapeColumnSpacing)],
                        spacing: landscapeRowSpacing
                    ) {
                        ForEach(filteredAndSortedReleases) { listing in
                            releaseNavigation(for: listing) {
                                ReleaseGridCardView(
                                    listing: listing,
                                    isFavorite: favoritesStore.contains(listing, in: appState.selectedList),
                                    themeTint: theme.tint,
                                    subtitleText: nil,
                                    status: releaseStatusStore.status(for: listing, in: appState.selectedList),
                                    onFavoriteToggle: {
                                        favoritesStore.toggle(listing, in: appState.selectedList)
                                    }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(landscapeContentPadding)
                }
                .background(
                    LinearGradient(
                        colors: [
                            theme.backgroundTop.opacity(colorScheme == .dark ? 0.34 : 0.2),
                            theme.backgroundBottom.opacity(colorScheme == .dark ? 0.24 : 0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                )
                .searchable(text: $searchText, prompt: "Search releases")

            case .coverFlow:
                GeometryReader { outerGeometry in
                    let availableWidth = outerGeometry.size.width
                    let containerHeight = outerGeometry.size.height
                    let isPad = UIDevice.current.userInterfaceIdiom == .pad
                    let cardWidth = isImmersiveCoverFlow
                        ? (isPad
                            ? min(max(min(availableWidth * 0.72, containerHeight * 1.12), 520), 760)
                            : min(max(min(availableWidth * 0.46, containerHeight * 0.68), 260), 420))
                        : (isPad
                            ? min(max(availableWidth * 0.72, 320), 560)
                            : min(max(availableWidth * 0.62, 240), 420))
                    let overlapSpacing = isImmersiveCoverFlow && isPad ? -cardWidth * 0.06 : -cardWidth * 0.14
                    let itemHeight = isImmersiveCoverFlow
                        ? (isPad
                            ? max(containerHeight + 40, cardWidth + 120)
                            : max(containerHeight - 28, cardWidth + 140))
                        : (isPad ? max(cardWidth + 150, 460) : max(cardWidth + 120, 360))
                    let contentHeight = isImmersiveCoverFlow
                        ? (isPad ? outerGeometry.size.height + 72 : outerGeometry.size.height + 40)
                        : (isPad ? max(cardWidth + 210, 560) : max(cardWidth + 180, 420))

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
                                        themeTint: theme.tint,
                                        cardWidth: cardWidth,
                                        showsMetadata: true,
                                        subtitleText: nil,
                                        status: releaseStatusStore.status(for: listing, in: appState.selectedList),
                                        prefersCompactArtwork: isImmersiveCoverFlow,
                                        onTap: {
                                            navigateToDetail(for: listing)
                                        },
                                        onFavoriteToggle: {
                                            favoritesStore.toggle(listing, in: appState.selectedList)
                                        },
                                        normalizedDistanceFromCenter: normalizedDistance
                                    )
                                }
                                .frame(width: cardWidth, height: itemHeight)
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .center)
                        .padding(.horizontal, max((outerGeometry.size.width - cardWidth) / 2, 24))
                        .padding(.top, isImmersiveCoverFlow ? (isPad ? 4 : 26) : 30)
                        .padding(.bottom, isImmersiveCoverFlow ? (isPad ? 4 : 14) : 30)
                        .frame(minHeight: contentHeight)
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .background(
                    LinearGradient(
                        colors: [
                            theme.backgroundTop.opacity(colorScheme == .dark ? 0.34 : 0.2),
                            theme.backgroundBottom.opacity(colorScheme == .dark ? 0.24 : 0.12),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                )
                .modifier(CoverFlowSearchModifier(isEnabled: isImmersiveCoverFlow == false, text: $searchText))
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
                        .foregroundColor(activeSectionID == section.id ? .white : .primary.opacity(0.8))
                        .frame(width: 20, height: itemHeight)
                        .background {
                            if activeSectionID == section.id {
                                Capsule()
                                    .fill(theme.tint.opacity(colorScheme == .dark ? 0.5 : 0.32))
                                    .padding(.horizontal, 1)
                                    .padding(.vertical, 2)
                            }
                        }
                }
            }
            .frame(maxHeight: .infinity, alignment: .center)
            .padding(.vertical, 10)
            .padding(.horizontal, 5)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(theme.tint.opacity(colorScheme == .dark ? 0.34 : 0.18), lineWidth: 1)
            }
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

private enum RSDStartupPresentationState {
    static var hasPresented = false
    static let debugLoopEnabled = false
    static var hasSeenImmersiveCoverFlowHint: Bool {
        get { UserDefaults.standard.bool(forKey: "hasSeenImmersiveCoverFlowHint") }
        set { UserDefaults.standard.set(newValue, forKey: "hasSeenImmersiveCoverFlowHint") }
    }
}

private struct RSDLaunchOverlayView: View {
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settled = false
    @State private var spinning = false
    @State private var fadingOut = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    SwiftUI.Color(red: 0.03, green: 0.04, blue: 0.06),
                    SwiftUI.Color(red: 0.08, green: 0.03, blue: 0.05),
                    SwiftUI.Color(red: 0.02, green: 0.02, blue: 0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            SwiftUI.Color(red: 0.83, green: 0.25, blue: 0.31).opacity(0.22),
                            .clear
                        ],
                        center: .center,
                        startRadius: 20,
                        endRadius: 340
                    )
                )
                .frame(width: 680, height: 680)
                .blur(radius: 16)

            RSDAnimatedLaunchRecord(spinning: spinning && !reduceMotion)
                .scaleEffect(settled ? 1.0 : 2.35)
                .offset(y: settled ? 0 : 188)
                .opacity(fadingOut ? 0 : 1)
                .animation(.spring(response: 0.92, dampingFraction: 0.86), value: settled)
                .animation(.easeInOut(duration: 0.28), value: fadingOut)
        }
        .ignoresSafeArea()
        .task {
            while !Task.isCancelled {
                settled = false
                spinning = false
                fadingOut = false

                try? await Task.sleep(nanoseconds: 70_000_000)
                settled = true

                if !reduceMotion {
                    try? await Task.sleep(nanoseconds: 760_000_000)
                    spinning = true
                }

                try? await Task.sleep(nanoseconds: reduceMotion ? 1_000_000_000 : 820_000_000)
                fadingOut = true

                try? await Task.sleep(nanoseconds: 280_000_000)
                if RSDStartupPresentationState.debugLoopEnabled {
                    try? await Task.sleep(nanoseconds: 220_000_000)
                    continue
                }

                onFinish()
                break
            }
        }
    }
}

private struct RSDImmersiveCoverFlowHintView: View {
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                SwiftUI.Image(systemName: "rectangle.rotate.vertical")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Landscape Cover Flow")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("Menus hide in this immersive mode. Rotate back to portrait to access filters and actions again.")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                SwiftUI.Button(action: onDismiss) {
                    SwiftUI.Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(8)
                        .background(.white.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.black.opacity(0.76))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 18, y: 10)
    }
}

private struct RSDAnimatedLaunchRecord: View {
    let spinning: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(SwiftUI.Color(red: 0.05, green: 0.05, blue: 0.07))
                .frame(width: 346 * 2, height: 346 * 2)
                .overlay {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    SwiftUI.Color(red: 0.36, green: 0.39, blue: 0.45),
                                    SwiftUI.Color(red: 0.11, green: 0.12, blue: 0.15),
                                    SwiftUI.Color(red: 0.03, green: 0.03, blue: 0.04)
                                ],
                                center: UnitPoint(x: 0.38, y: 0.28),
                                startRadius: 12,
                                endRadius: 520
                            )
                        )
                }
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(spinning ? .linear(duration: 2.4).repeatForever(autoreverses: false) : .default, value: spinning)

            let grooveBands: [(start: Double, end: Double, step: Double, opacity: Double)] = [
                (338, 326, 1.7, 0.34), // lead-in
                (320, 296, 2.0, 0.30),
                (288, 280, 1.7, 0.20), // shorter track
                (272, 238, 2.1, 0.28),
                (230, 214, 1.8, 0.22),
                (206, 196, 1.4, 0.34)  // lead-out
            ]

            Circle()
                .stroke(SwiftUI.Color(red: 0.30, green: 0.33, blue: 0.38).opacity(0.55), lineWidth: 2)
                .frame(width: 360 * 2, height: 360 * 2)
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(spinning ? .linear(duration: 2.4).repeatForever(autoreverses: false) : .default, value: spinning)

            Circle()
                .stroke(SwiftUI.Color(red: 0.18, green: 0.20, blue: 0.24).opacity(0.45), lineWidth: 0.9)
                .frame(width: 346 * 2, height: 346 * 2)
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(spinning ? .linear(duration: 2.4).repeatForever(autoreverses: false) : .default, value: spinning)

            ForEach(Array(grooveBands.enumerated()), id: \.offset) { bandIndex, band in
                ForEach(Array(stride(from: band.start, through: band.end, by: -band.step)), id: \.self) { radius in
                    let normalized = (radius - 196.0) / (338.0 - 196.0)
                    let grooveColor = SwiftUI.Color(
                        red: 0.18 + (0.16 * normalized),
                        green: 0.20 + (0.18 * normalized),
                        blue: 0.24 + (0.22 * normalized)
                    )
                    Circle()
                        .stroke(grooveColor.opacity(band.opacity), lineWidth: bandIndex == 0 || bandIndex == grooveBands.count - 1 ? 1.1 : 0.95)
                        .frame(width: radius * 2, height: radius * 2)
                        .rotationEffect(.degrees(spinning ? 360 : 0))
                        .animation(spinning ? .linear(duration: 2.4).repeatForever(autoreverses: false) : .default, value: spinning)
                }
            }

            Circle()
                .fill(SwiftUI.Color(red: 0.05, green: 0.06, blue: 0.08))
                .frame(width: 390, height: 390)
                .overlay {
                    Circle()
                        .stroke(SwiftUI.Color(red: 0.46, green: 0.50, blue: 0.57).opacity(0.4), lineWidth: 6)
                }
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(spinning ? .linear(duration: 2.4).repeatForever(autoreverses: false) : .default, value: spinning)

            Circle()
                .fill(SwiftUI.Color(red: 0.78, green: 0.23, blue: 0.28))
                .frame(width: 324, height: 324)
                .overlay {
                    Circle()
                        .stroke(SwiftUI.Color(red: 0.94, green: 0.84, blue: 0.82), lineWidth: 4)
                }
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(spinning ? .linear(duration: 2.4).repeatForever(autoreverses: false) : .default, value: spinning)

            ZStack {
                Text("RSD")
                    .font(.custom("RCA", size: 56))
                    .tracking(-0.6)
                    .foregroundStyle(SwiftUI.Color(red: 0.97, green: 0.91, blue: 0.89))
                    .shadow(color: SwiftUI.Color(red: 0.90, green: 0.81, blue: 0.79).opacity(0.28), radius: 1, y: 1)
                    .offset(y: -114)

                Text("assistant")
                    .font(.custom("RCA", size: 18))
                    .tracking(0.2)
                    .foregroundStyle(SwiftUI.Color(red: 0.97, green: 0.91, blue: 0.89))
                    .scaleEffect(x: 1.04, y: 1, anchor: .center)
                    .offset(y: -82)
            }
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(spinning ? .linear(duration: 2.4).repeatForever(autoreverses: false) : .default, value: spinning)

            HStack(spacing: 90) {
                VStack(spacing: 60) {
                    Capsule().fill(SwiftUI.Color(red: 0.94, green: 0.84, blue: 0.82)).frame(width: 114, height: 3)
                    Capsule().fill(SwiftUI.Color(red: 0.94, green: 0.84, blue: 0.82)).frame(width: 114, height: 3)
                }
                VStack(spacing: 60) {
                    Capsule().fill(SwiftUI.Color(red: 0.94, green: 0.84, blue: 0.82)).frame(width: 114, height: 3)
                    Capsule().fill(SwiftUI.Color(red: 0.94, green: 0.84, blue: 0.82)).frame(width: 114, height: 3)
                }
            }
            .rotationEffect(.degrees(spinning ? 360 : 0))
            .animation(spinning ? .linear(duration: 2.4).repeatForever(autoreverses: false) : .default, value: spinning)

            Circle()
                .stroke(SwiftUI.Color(red: 0.94, green: 0.84, blue: 0.82), lineWidth: 2)
                .frame(width: 54 * 2, height: 54 * 2)
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(spinning ? .linear(duration: 2.4).repeatForever(autoreverses: false) : .default, value: spinning)

            Circle()
                .fill(SwiftUI.Color(red: 0.05, green: 0.06, blue: 0.08))
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(spinning ? 360 : 0))
                .animation(spinning ? .linear(duration: 2.4).repeatForever(autoreverses: false) : .default, value: spinning)
        }
        .frame(width: 820, height: 820)
        .drawingGroup()
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
