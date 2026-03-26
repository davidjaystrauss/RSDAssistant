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

struct FavoritesView: View {
    let list: RSDListDefinition
    var showsDoneButton: Bool = true

    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var appState = RSDAppState.shared
    @ObservedObject private var library = ReleaseLibrary.shared
    @ObservedObject private var favoritesStore = FavoritesStore.shared
    @ObservedObject private var selectedStoreStore = SelectedStoreStore.shared
    @Environment(\.presentationMode) private var presentationMode
    @State private var searchText = ""
    @State private var shareDocument: ShareDocument?
    @State private var isPreparingShare = false
    @State private var selectedCoverFlowListing: Listing?

    private var theme: RSDThemePalette {
        list.theme.palette(for: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [theme.backgroundTop, theme.backgroundBottom],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                Group {
                    if filteredFavorites.isEmpty {
                        VStack(spacing: 12) {
                            Text("No Favorites Yet")
                                .font(.title3)
                            Text("Save releases from \(list.displayName) and they’ll show up here.")
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                    } else {
                        switch appState.favoritesViewMode {
                        case .list:
                            List(filteredFavorites) { listing in
                                NavigationLink(destination: ReleaseDetailView(listing: listing, list: list)) {
                                    ReleaseRowView(
                                        listing: listing,
                                        isFavorite: true,
                                        onFavoriteToggle: {
                                            favoritesStore.toggle(listing, in: list)
                                        }
                                    )
                                }
                            }
                            .listStyle(PlainListStyle())
                            .scrollContentBackground(.hidden)

                        case .grid:
                            ScrollView {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 16)], spacing: 18) {
                                    ForEach(filteredFavorites) { listing in
                                        NavigationLink(destination: ReleaseDetailView(listing: listing, list: list)) {
                                            ReleaseGridCardView(
                                                listing: listing,
                                                isFavorite: true,
                                                onFavoriteToggle: {
                                                    favoritesStore.toggle(listing, in: list)
                                                }
                                            )
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding()
                            }

                        case .coverFlow:
                            GeometryReader { outerGeometry in
                                let cardWidth: CGFloat = 240
                                let overlapSpacing: CGFloat = -32

                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: overlapSpacing) {
                                        ForEach(filteredFavorites) { listing in
                                            GeometryReader { itemGeometry in
                                                let frame = itemGeometry.frame(in: .global)
                                                let containerMidX = outerGeometry.frame(in: .global).midX
                                                let distance = frame.midX - containerMidX
                                                let normalizedDistance = max(-1, min(1, distance / 260))

                                                CoverFlowCardView(
                                                    listing: listing,
                                                    isFavorite: true,
                                                    onTap: {
                                                        selectedCoverFlowListing = listing
                                                    },
                                                    onFavoriteToggle: {
                                                        favoritesStore.toggle(listing, in: list)
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
                        }
                    }
                }
            }
            .navigationTitle("Favorites")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search favorites")
            .toolbarBackground(AnyShapeStyle(theme.navigationBar.opacity(colorScheme == .dark ? 0.92 : 0.98)), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .tint(theme.tint)
            .accentColor(theme.tint)
            .toolbar(content: toolbarContent)
        }
        .sheet(item: $shareDocument) { document in
            ActivityShareSheet(activityItems: [document.url])
        }
        .sheet(item: $selectedCoverFlowListing) { listing in
            NavigationStack {
                ReleaseDetailView(listing: listing, list: list)
            }
            .tint(theme.tint)
            .accentColor(theme.tint)
        }
    }

    private var favoriteListings: [Listing] {
        favoritesStore.favorites(in: list, from: library.releases)
    }

    private var filteredFavorites: [Listing] {
        let query = searchText.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        guard query.isEmpty == false else {
            return favoriteListings
        }
        return favoriteListings.filter { $0.searchableText.contains(query) }
    }

    @ToolbarContentBuilder
    private func toolbarContent() -> some ToolbarContent {
        SwiftUI.ToolbarItemGroup(placement: .topBarTrailing) {
            if favoriteListings.isEmpty == false {
                SwiftUI.Button {
                    exportFavoritesPDF()
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
                Picker("View", selection: $appState.favoritesViewMode) {
                    ForEach(RSDViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
            } label: {
                SwiftUI.Image(systemName: "rectangle.3.group")
            }

            if showsDoneButton {
                SwiftUI.Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
            }
        }
    }

    private func exportFavoritesPDF() {
        let listings = favoriteListings
        guard listings.isEmpty == false else {
            return
        }

        isPreparingShare = true
        Task {
            let url = await FavoriteExportBuilder.makePDF(
                for: listings,
                list: list,
                selectedStore: selectedStoreStore.selectedStore
            )
            await MainActor.run {
                isPreparingShare = false
                shareDocument = ShareDocument(url: url)
            }
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

enum FavoriteExportBuilder {
    static func makePDF(for listings: [Listing], list: RSDListDefinition, selectedStore: ParticipatingStoreRecord?) async -> URL {
        let artworkImages = await loadArtworkImages(for: listings)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(sanitizedFileName(list.displayName))-favorites.pdf")
        let theme = theme(for: list)
        let includeCategory = listings.contains { !$0.releaseCategoryFilterValue.isEmpty }
        let includeQuantity = listings.contains { $0.quantityValue != nil }

        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)

        try? renderer.writePDF(to: url) { context in
            let margin: CGFloat = 28
            let contentRect = pageRect.insetBy(dx: margin, dy: margin)
            let bannerHeight: CGFloat = 88
            let tableHeaderHeight: CGFloat = 28
            let minimumRowHeight: CGFloat = 78
            let artworkSize = CGSize(width: 46, height: 46)
            let printBlack = UIColor(red: 0.08, green: 0.08, blue: 0.08, alpha: 1)
            let printGray = UIColor(red: 0.42, green: 0.42, blue: 0.44, alpha: 1)
            let printLightGray = UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1)
            let printWhite = UIColor.white
            let notesSectionHeight: CGFloat = 132
            let columnSpecs = tableColumns(
                totalWidth: contentRect.width,
                includeCategory: includeCategory,
                includeQuantity: includeQuantity
            )

            let headerTitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 28, weight: .bold),
                .foregroundColor: printWhite,
            ]
            let headerSubtitleAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: printWhite.withAlphaComponent(0.92),
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

                let titleRect = CGRect(x: bannerRect.minX + 20, y: bannerRect.minY + 14, width: bannerRect.width * 0.62, height: 34)
                let subtitleRect = CGRect(x: bannerRect.minX + 20, y: bannerRect.minY + 46, width: bannerRect.width * 0.62, height: 18)
                let metadataRect = CGRect(x: bannerRect.midX + 20, y: bannerRect.minY + 18, width: bannerRect.width * 0.32, height: 44)

                "Record Store Day Favorites".draw(in: titleRect, withAttributes: headerTitleAttributes)
                list.displayName.draw(in: subtitleRect, withAttributes: headerSubtitleAttributes)

                let metadataParagraph = NSMutableParagraphStyle()
                metadataParagraph.alignment = .right
                let metadataAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 11, weight: .medium),
                    .foregroundColor: printWhite.withAlphaComponent(0.92),
                    .paragraphStyle: metadataParagraph,
                ]
                let storeLine = selectedStore.map { "Store: \($0.displayName)" } ?? "Store: ____________________"
                let metadata = "\(listings.count) favorites • Generated \(DateFormatter.favoriteExport.string(from: Date()))\n\(storeLine)"
                metadata.draw(in: metadataRect, withAttributes: metadataAttributes)

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

            while rowIndex < listings.count || rowIndex == listings.count {
                context.beginPage()
                var yPosition = drawPageHeader()
                let reserveNotesOnThisPage = (listings.count - rowIndex) <= finalPageCapacity

                while rowIndex < listings.count {
                    let listing = listings[rowIndex]
                    let artworkImage = artworkImages[listing.id] ?? UIImage(named: "filler")
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

                    let displayIndex = rowIndex + 1
                    let rowFill = rowIndex.isMultiple(of: 2) ? printLightGray : printWhite
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
                        case .pickedUp:
                            drawCheckbox(in: CGRect(x: rect.midX - 9, y: rect.midY - 9, width: 18, height: 18))
                        }
                    }

                    yPosition += measuredRowHeight + 6
                    rowIndex += 1
                }

                if rowIndex >= listings.count {
                    drawGlobalNotesSection(startY: yPosition + 4)
                    break
                }
            }
        }

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
        guard let url = URL(string: listing.photoURL), listing.photoURL.isEmpty == false else {
            return UIImage(named: "filler")
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

        let fittedRect = AVMakeRect(aspectRatio: image.size, insideRect: rect.insetBy(dx: 2, dy: 2))
        image.draw(in: fittedRect)
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

    private static func drawCheckbox(in rect: CGRect) {
        let checkboxPath = UIBezierPath(roundedRect: rect, cornerRadius: 4)
        UIColor(red: 0.38, green: 0.38, blue: 0.4, alpha: 1).setStroke()
        checkboxPath.lineWidth = 1.5
        checkboxPath.stroke()
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

    private static func sanitizedFileName(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
    }

    private static func theme(for list: RSDListDefinition) -> PDFTheme {
        let region = list.subtitle.lowercased()
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

        columns.append(PDFColumn(kind: .pickedUp, title: "Got It", width: 48))

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

private enum PDFColumnKind {
    case art
    case release
    case format
    case label
    case category
    case quantity
    case pickedUp
}

private extension DateFormatter {
    static let favoriteExport: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
