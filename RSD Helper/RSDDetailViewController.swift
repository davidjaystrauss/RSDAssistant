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
    @ObservedObject private var releaseStatusStore = ReleaseStatusStore.shared
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
                            Label(isFavorite ? "Wishlisted" : "Add to Wishlist", systemImage: isFavorite ? "bookmark.fill" : "bookmark")
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

                    statusSection

                    Group {
                        detailRow(title: "Format", value: listing.format)
                        detailRow(title: "Label", value: listing.label)
                        detailRow(title: "Quantity", value: listing.quantityDisplayValue)
                        detailsSection
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

    private var releaseStatus: ReleaseAcquisitionStatus? {
        releaseStatusStore.status(for: listing, in: list)
    }

    private var parsedDetails: ParsedReleaseDetails {
        ReleaseDetailsParser.parse(listing.moreInfo)
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

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Release Status")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(ReleaseAcquisitionStatus.allCases) { status in
                    SwiftUI.Button {
                        releaseStatusStore.setStatus(status, for: listing, in: list)
                    } label: {
                        HStack {
                            Label(status.label, systemImage: status.systemImage)
                            Spacer()
                            if releaseStatus == status {
                                SwiftUI.Image(systemName: "checkmark")
                                    .font(.caption.weight(.bold))
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DetailActionButtonStyle(fillColor: UIColor(status.color(using: theme.tint))))
                }

                if releaseStatus != nil {
                    SwiftUI.Button {
                        releaseStatusStore.setStatus(nil, for: listing, in: list)
                    } label: {
                        Label("Clear Status", systemImage: "xmark.circle")
                    }
                    .buttonStyle(DetailSecondaryButtonStyle(strokeColor: UIColor(theme.tint)))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            if parsedDetails.descriptionText.isEmpty == false {
                detailRow(title: "Details", value: parsedDetails.descriptionText)
            }

            if parsedDetails.trackSections.isEmpty == false {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Tracklist")
                        .font(.headline)

                    ForEach(parsedDetails.trackSections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            if section.title.isEmpty == false {
                                Text(section.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(theme.tint)
                            }

                            ForEach(section.items) { item in
                                HStack(alignment: .top, spacing: 10) {
                                    if item.marker.isEmpty == false {
                                        Text(item.marker)
                                            .font(.caption.monospacedDigit().weight(.semibold))
                                            .foregroundColor(theme.tint)
                                            .frame(width: 34, alignment: .leading)
                                    }
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Text(item.title)
                                            .font(.body)
                                            .foregroundColor(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        if item.duration.isEmpty == false {
                                            Text(item.duration)
                                                .font(.caption.monospacedDigit())
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(theme.tint.opacity(colorScheme == .dark ? 0.14 : 0.08))
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if parsedDetails.descriptionText.isEmpty {
                detailRow(title: "Details", value: listing.moreInfo)
            }
        }
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

struct DetailSecondaryButtonStyle: ButtonStyle {
    let strokeColor: UIColor

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(SwiftUI.Color(strokeColor))
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(SwiftUI.Color(strokeColor).opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(SwiftUI.Color(strokeColor).opacity(configuration.isPressed ? 0.6 : 0.9), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

private struct ParsedReleaseDetails {
    let descriptionText: String
    let trackSections: [ParsedTrackSection]
}

private struct ParsedTrackSection: Identifiable {
    let title: String
    let items: [ParsedTrackItem]

    var id: String { title + "::" + String(items.count) }
}

private struct ParsedTrackItem: Identifiable {
    let marker: String
    let title: String
    let duration: String

    var id: String { marker + "::" + title + "::" + duration }
}

private enum ReleaseDetailsParser {
    static func parse(_ raw: String) -> ParsedReleaseDetails {
        let cleaned = sanitize(raw)
        guard let trackRange = trackStartRange(in: cleaned) else {
            return ParsedReleaseDetails(descriptionText: cleaned, trackSections: [])
        }

        let description = String(cleaned[..<trackRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        let trackBody = String(cleaned[trackRange.lowerBound...])
        let sections = parseTrackSections(from: trackBody)

        return ParsedReleaseDetails(
            descriptionText: description,
            trackSections: sections
        )
    }

    private static func sanitize(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\u{0001}", with: " ")
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func trackStartRange(in value: String) -> Range<String.Index>? {
        let patterns = [
            #"(?i)\btrack ?list(?:ing)?\b"#,
            #"(?i)\btracks?:\b"#,
            #"(?i)\bside a\b"#,
            #"(?i)\bdisc (?:one|1)\b"#,
            #"\bA1[\.\s]"#,
            #"\bLP1\b"#,
        ]

        for pattern in patterns {
            if let range = value.range(of: pattern, options: .regularExpression) {
                return range
            }
        }

        let markerExpression = #"(?:(?<=\s)|^)(?:[A-D]\d{1,2}|(?:0?\d{1,2})[\.\)])\s+"#
        let matches = value.ranges(of: markerExpression)
        if matches.count >= 4, let first = matches.first {
            let prefix = String(value[..<first.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            if prefix.count >= 24 {
                return first
            }
        }

        return nil
    }

    private static func parseTrackSections(from rawTrackBody: String) -> [ParsedTrackSection] {
        var normalized = rawTrackBody
        let replacements: [(String, String)] = [
            (#"(?i)\btrack ?list(?:ing)?\s*:?"#, "Tracklist\n"),
            (#"(?i)\btracks?\s*:"# , "Tracklist\n"),
            (#"(?i)\s*(SIDE\s+[A-Z0-9]+|DISC\s+(?:ONE|TWO|THREE|FOUR|\d+)|LP\s*\d+|LP\d+)\s*:\s*"#, "\n$1\n"),
            (#"(?i)\s+(SIDE\s+[A-Z0-9]+|DISC\s+(?:ONE|TWO|THREE|FOUR|\d+)|LP\s*\d+|LP\d+)\b"#, "\n$1"),
            (#"\b([A-Z]\d{1,2})([A-Za-z])"#, "$1. $2"),
            (#"(?<!\n)\b([A-Z]\d{1,2})[\.\:\-]?\s*"#, "\n$1 "),
            (#"(?<!\n)(?<![A-Za-z])(\d{1,2})\)\s*"#, "\n$1. "),
            (#"(?<!\n)(?<!\d)(\d{1,2})\.\s*"#, "\n$1. "),
            (#"(?<!\n)(?<!\d)(0\d{1})(?=\s+[A-Za-z\"'])"#, "\n$1. "),
        ]

        for (pattern, replacement) in replacements {
            normalized = normalized.replacingOccurrences(of: pattern, with: replacement, options: .regularExpression)
        }

        let lines = normalized
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        var sections: [ParsedTrackSection] = []
        var currentTitle = ""
        var currentItems: [ParsedTrackItem] = []

        func commitSection() {
            guard currentItems.isEmpty == false else { return }
            sections.append(ParsedTrackSection(title: currentTitle, items: currentItems))
            currentItems = []
        }

        for line in lines {
            if line.lowercased() == "tracklist" {
                continue
            }

            if line.range(of: #"(?i)^(SIDE\s+[A-Z0-9]+|DISC\s+(?:ONE|TWO|THREE|FOUR|\d+)|LP\s*\d+|LP\d+)\b"#, options: .regularExpression) != nil {
                commitSection()
                currentTitle = line
                continue
            }

            if let range = line.range(of: #"^(?:([A-Z]\d{1,2})|(\d{1,2}[\.\)]?))\s+"#, options: .regularExpression) {
                let marker = String(line[..<range.upperBound]).trimmingCharacters(in: .whitespacesAndNewlines)
                let details = parseTrackTitleAndDuration(String(line[range.upperBound...]))
                currentItems.append(ParsedTrackItem(marker: marker, title: details.title, duration: details.duration))
            } else if currentTitle.isEmpty == false || sections.isEmpty == false {
                if currentItems.isEmpty == false, looksLikeTrackContinuation(line) {
                    let last = currentItems.removeLast()
                    currentItems.append(
                        ParsedTrackItem(
                            marker: last.marker,
                            title: "\(last.title) \(line)".trimmingCharacters(in: .whitespacesAndNewlines),
                            duration: last.duration
                        )
                    )
                } else {
                    let details = parseTrackTitleAndDuration(line)
                    currentItems.append(ParsedTrackItem(marker: "", title: details.title, duration: details.duration))
                }
            }
        }

        commitSection()
        return sections
    }

    private static func parseTrackTitleAndDuration(_ value: String) -> (title: String, duration: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let range = trimmed.range(of: #"(?:\s+|[\-–—]\s*)(\d{1,2}:\d{2}(?::\d{2})?)$"#, options: .regularExpression) else {
            return (trimmed, "")
        }

        let duration = String(trimmed[range]).trimmingCharacters(in: CharacterSet(charactersIn: "-–— ").union(.whitespacesAndNewlines))
        let title = String(trimmed[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        return (title, duration)
    }

    private static func looksLikeTrackContinuation(_ value: String) -> Bool {
        value.range(of: #"(?i)^(SIDE\s+[A-Z0-9]+|DISC\s+(?:ONE|TWO|THREE|FOUR|\d+)|LP\s*\d+|LP\d+)\b"#, options: .regularExpression) == nil
            && value.range(of: #"^(?:([A-Z]\d{1,2})|(\d{1,2}[\.\)]?))\s+"#, options: .regularExpression) == nil
    }
}

private extension String {
    func ranges(of pattern: String) -> [Range<String.Index>] {
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let searchRange = NSRange(startIndex..<endIndex, in: self)
        return expression.matches(in: self, range: searchRange).compactMap { match in
            Range(match.range, in: self)
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
