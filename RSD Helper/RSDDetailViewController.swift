//
//  RSDDetailViewController.swift
//  RSD Helper
//
//  Created by David Strauss on 4/17/17.
//  Copyright © 2017 David Strauss. All rights reserved.
//

import SwiftUI

enum MusicProvider: String {
    case appleMusic = "Apple Music"
    case spotify = "Spotify"
    case tidal = "TIDAL"
    case youtubeMusic = "YouTube Music"
    case deezer = "Deezer"
}

final class MusicLinkResolver {
    func resolveAppleMusicLink(for listing: Listing, completion: @escaping (URL?) -> Void) {
        let search = iTunes(session: URLSession.shared, debug: false)
        let query = "\(listing.artist) \(listing.album)"

        _ = search.search(for: query, ofType: .music(.album)) { result in
            guard let payload = result.value as? [String: Any],
                  let entries = payload["results"] as? [[String: Any]] else {
                completion(nil)
                return
            }

            let normalizedArtist = Self.normalize(listing.artist)
            let match = entries.first { entry in
                guard let artist = entry["artistName"] as? String else {
                    return false
                }
                return Self.normalize(artist) == normalizedArtist
            } ?? entries.first

            if let urlString = match?["collectionViewUrl"] as? String,
               let url = URL(string: urlString) {
                completion(url)
            } else {
                completion(nil)
            }
        }
    }

    func spotifySearchLink(for listing: Listing) -> URL? {
        searchURL(for: listing, baseURL: "https://open.spotify.com/search/")
    }

    func tidalSearchLink(for listing: Listing) -> URL? {
        searchURL(for: listing, baseURL: "https://listen.tidal.com/search?q=")
    }

    func youtubeMusicSearchLink(for listing: Listing) -> URL? {
        searchURL(for: listing, baseURL: "https://music.youtube.com/search?q=")
    }

    func deezerSearchLink(for listing: Listing) -> URL? {
        searchURL(for: listing, baseURL: "https://www.deezer.com/search/")
    }

    private func searchURL(for listing: Listing, baseURL: String) -> URL? {
        let query = "\(listing.artist) \(listing.album)"
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else {
            return nil
        }
        return URL(string: "\(baseURL)\(encodedQuery)")
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct ReleaseDetailView: View {
    let listing: Listing
    let list: RSDListDefinition

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var favoritesStore = FavoritesStore.shared
    @State private var appleMusicURL: URL?

    private let musicLinkResolver = MusicLinkResolver()
    private var theme: RSDThemePalette {
        list.theme.palette(for: colorScheme)
    }
    private var alternatePreviewLinks: [(provider: MusicProvider, url: URL)] {
        let candidates: [(provider: MusicProvider, url: URL?)] = [
            (provider: MusicProvider.spotify, url: musicLinkResolver.spotifySearchLink(for: listing)),
            (provider: MusicProvider.tidal, url: musicLinkResolver.tidalSearchLink(for: listing)),
            (provider: MusicProvider.youtubeMusic, url: musicLinkResolver.youtubeMusicSearchLink(for: listing)),
            (provider: MusicProvider.deezer, url: musicLinkResolver.deezerSearchLink(for: listing)),
        ]
        return candidates.compactMap { item in
            guard let url = item.url else { return nil }
            return (provider: item.provider, url: url)
        }
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundTop, theme.backgroundBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    RemoteArtworkView(
                        urlString: listing.photoURL,
                        placeholderStyle: .from(format: listing.format),
                        priority: .high
                    )
                    .frame(width: 320, height: 320)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .frame(maxWidth: .infinity)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(listing.album)
                            .font(.title2)
                            .fontWeight(.bold)
                        Text(listing.artist)
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 12) {
                        SwiftUI.Button {
                            toggleFavorite()
                        } label: {
                            Label(isFavorite ? "Favorited" : "Save Favorite", systemImage: isFavorite ? "heart.fill" : "heart")
                        }
                        .buttonStyle(DetailActionButtonStyle(fillColor: UIColor(theme.tint)))
                        .frame(maxWidth: .infinity)

                        if let appleMusicURL = appleMusicURL {
                            SwiftUI.Button {
                                UIApplication.shared.open(appleMusicURL)
                            } label: {
                                Label("Apple Music", systemImage: "music.note")
                            }
                            .buttonStyle(DetailActionButtonStyle(fillColor: .black))
                            .frame(maxWidth: .infinity)
                        }
                    }

                    if alternatePreviewLinks.isEmpty == false {
                        Menu {
                            ForEach(alternatePreviewLinks, id: \.provider.rawValue) { item in
                                SwiftUI.Button(item.provider.rawValue) {
                                    UIApplication.shared.open(item.url)
                                }
                            }
                        } label: {
                            Label("More Previews", systemImage: "play.circle")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DetailActionButtonStyle(fillColor: UIColor(theme.tint).withAlphaComponent(0.88)))
                        .accessibilityLabel("More preview services")
                        .accessibilityHint("Opens a menu of other music services")
                    }

                    Group {
                        detailRow(title: "Format", value: listing.format)
                        detailRow(title: "Label", value: listing.label)
                        detailRow(title: "Quantity", value: listing.quantityDisplayValue)
                        detailRow(title: "Details", value: listing.moreInfo)
                    }
                }
                .padding()
            }
        }
        .navigationTitle("Release")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(theme.navigationBar.opacity(colorScheme == .dark ? 0.92 : 0.98), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .tint(theme.tint)
        .accentColor(theme.tint)
        .onAppear {
            resolveLinks()
        }
    }

    private var isFavorite: Bool {
        favoritesStore.contains(listing, in: list)
    }

    private func toggleFavorite() {
        favoritesStore.toggle(listing, in: list)
    }

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(value)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func resolveLinks() {
        guard appleMusicURL == nil else {
            return
        }

        musicLinkResolver.resolveAppleMusicLink(for: listing) { url in
            DispatchQueue.main.async {
                appleMusicURL = url
            }
        }
    }
}

struct DetailActionButtonStyle: ButtonStyle {
    let fillColor: UIColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SwiftUI.Color(fillColor))
                    .opacity(configuration.isPressed ? 0.82 : 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
