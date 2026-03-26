//
//  Listing.swift
//  RSD Helper
//
//  Created by David Strauss on 4/15/17.
//  Copyright © 2017 David Strauss. All rights reserved.
//

import Foundation

class Listing: NSObject, NSCoding {
    
    var artist: String
    var album: String
    var format: String
    var label: String
    var releaseCategory: String
    var quantity: String
    var photoURL: String
    var moreInfo: String
    
    public init(artist: String,
                album: String,
                format: String,
                label: String,
                releaseCategory: String,
                quantity: String,
                photoURL: String,
                moreInfo: String)
    {
        self.artist = artist
        self.album = album
        self.format = format
        self.label = label
        self.releaseCategory = releaseCategory
        self.quantity = quantity
        self.photoURL = photoURL
        self.moreInfo = moreInfo
    }
    
    required init(coder aDecoder: NSCoder) {

        self.artist = aDecoder.decodeObject(forKey: "artist") as! String
        self.album = aDecoder.decodeObject(forKey: "album") as! String
        self.format = aDecoder.decodeObject(forKey: "format") as! String
        self.label = aDecoder.decodeObject(forKey: "label") as! String
        self.releaseCategory = (aDecoder.decodeObject(forKey: "releaseCategory") as? String) ?? ""
        self.quantity = aDecoder.decodeObject(forKey: "quantity") as! String
        self.photoURL = aDecoder.decodeObject(forKey: "photoURL") as! String
        self.moreInfo = aDecoder.decodeObject(forKey: "moreInfo") as! String
        super.init()
    }
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(self.artist, forKey: "artist")
        aCoder.encode(self.album, forKey: "album")
        aCoder.encode(self.format, forKey: "format")
        aCoder.encode(self.label, forKey: "label")
        aCoder.encode(self.releaseCategory, forKey: "releaseCategory")
        aCoder.encode(self.quantity, forKey: "quantity")
        aCoder.encode(self.photoURL, forKey: "photoURL")
        aCoder.encode(self.moreInfo, forKey: "moreInfo")
    }
    
}

extension Listing: Identifiable {
    var id: String {
        let source = "\(artist)|\(album)|\(format)|\(label)"
        let filtered = source
            .lowercased()
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")
        return filtered
    }
}

extension Listing {
    static let quantityFilterOptions = ["1-1000", "1001-3000", "3001-10000", "10001+"]

    var quantityDisplayValue: String {
        let trimmed = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty || trimmed == "0" ? "N/A" : trimmed
    }

    var quantityValue: Int? {
        let trimmed = quantity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false, trimmed != "0", let value = Int(trimmed) else {
            return nil
        }
        return value
    }

    var quantityFilterValue: String {
        guard let quantityValue else {
            return ""
        }

        switch quantityValue {
        case 1...1000:
            return "1-1000"
        case 1001...3000:
            return "1001-3000"
        case 3001...10000:
            return "3001-10000"
        default:
            return "10001+"
        }
    }

    var searchableText: String {
        [
            artist,
            album,
            format,
            label,
            releaseCategory,
            quantity,
            moreInfo,
        ]
        .joined(separator: "\n")
        .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    }

    var formatFilterValue: String {
        let trimmed = format.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            return trimmed
        }

        var normalized = trimmed
            .replacingOccurrences(of: "“", with: "\"")
            .replacingOccurrences(of: "”", with: "\"")
            .replacingOccurrences(of: "″", with: "\"")
            .replacingOccurrences(of: "‟", with: "\"")
            .replacingOccurrences(of: "’", with: "'")

        normalized = normalized.replacingOccurrences(
            of: #"(?i)\bbox\s*set\b|\bboxset\b"#,
            with: "Box Set",
            options: .regularExpression
        )

        normalized = normalized.replacingOccurrences(
            of: #"(?i)\b(\d+)\s*[x×]\s*lp\b"#,
            with: "$1 LP",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"(?i)\b(\d+)\s*lp\b"#,
            with: "$1 LP",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"(?i)\b(\d+)\s*[x×]\s*cd\b"#,
            with: "$1 CD",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"(?i)\b(\d+)\s*cd\b"#,
            with: "$1 CD",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"\b(7|10|12)\s*"\s*"#,
            with: "$1\" ",
            options: .regularExpression
        )
        normalized = normalized.replacingOccurrences(
            of: #"\s{2,}"#,
            with: " ",
            options: .regularExpression
        )

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var labelFilterValue: String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var releaseCategoryFilterValue: String {
        releaseCategory.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct FlexibleString: Decodable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            value = string
            return
        }

        if let intValue = try? container.decode(Int.self) {
            value = String(intValue)
            return
        }

        if let doubleValue = try? container.decode(Double.self) {
            value = String(doubleValue)
            return
        }

        value = ""
    }
}

struct ReleaseDocument: Decodable {
    let schemaVersion: Int
    let event: ReleaseEvent
    let releases: [ReleaseRecord]
}

struct ReleaseEvent: Decodable {
    let slug: String
    let name: String
    let kind: String
    let releaseDate: String
}

struct ReleaseRecord: Decodable {
    let id: String
    let artist: String
    let title: String
    let format: String
    let label: String
    let releaseCategory: String?
    let quantity: FlexibleString?
    let details: String
    let imageURL: String
    let appleMusic: AppleMusicMetadata?

    func asListing() -> Listing {
        let preferredArtworkURL = preferredImageURL

        return Listing(
            artist: artist,
            album: title,
            format: format,
            label: label,
            releaseCategory: releaseCategory ?? "",
            quantity: quantity?.value ?? "",
            photoURL: preferredArtworkURL,
            moreInfo: details
        )
    }

    private var preferredImageURL: String {
        if let renderedArtworkURL = appleMusic?.artwork?.renderedURL,
           renderedArtworkURL.isEmpty == false {
            return renderedArtworkURL
        }

        let normalizedImageURL = imageURL.lowercased()
        if normalizedImageURL.contains("recordstoreday.com") || normalizedImageURL.contains("recordstoreday.co.uk") {
            return ""
        }

        return imageURL
    }
}

struct AppleMusicMetadata: Decodable {
    let albumID: String?
    let albumURL: String?
    let artistName: String?
    let artistURL: String?
    let artwork: AppleMusicArtwork?
}

struct AppleMusicArtwork: Decodable {
    let urlTemplate: String?
    let width: Int?
    let height: Int?
    let bgColor: String?
    let textColor1: String?
    let textColor2: String?
    let textColor3: String?
    let textColor4: String?

    var renderedURL: String? {
        guard let urlTemplate else {
            return nil
        }

        let renderedWidth = width ?? 600
        let renderedHeight = height ?? renderedWidth

        return urlTemplate
            .replacingOccurrences(of: "{w}", with: String(renderedWidth))
            .replacingOccurrences(of: "{h}", with: String(renderedHeight))
    }
}

private struct LegacyReleaseRecord: Decodable {
    enum CodingKeys: String, CodingKey {
        case artist = "Artist"
        case album = "Album"
        case format = "Format"
        case label = "Label"
        case quantity = "Quantity"
        case photoURL = "PhotoURL"
        case moreInfo = "More Info"
    }

    let artist: String
    let album: String
    let format: String
    let label: String
    let quantity: FlexibleString?
    let photoURL: String
    let moreInfo: String

    func asListing() -> Listing {
        Listing(
            artist: artist,
            album: album,
            format: format,
            label: label,
            releaseCategory: "",
            quantity: quantity?.value ?? "",
            photoURL: photoURL,
            moreInfo: moreInfo
        )
    }
}

enum ListingLoader {
    static func loadCanonicalListings(from data: Data) throws -> [Listing] {
        let decoder = JSONDecoder()
        let document = try decoder.decode(ReleaseDocument.self, from: data)
        return document.releases.map { $0.asListing() }
    }

    static func loadListings(from data: Data) throws -> [Listing] {
        let decoder = JSONDecoder()

        if let document = try? decoder.decode(ReleaseDocument.self, from: data) {
            return document.releases.map { $0.asListing() }
        }

        let legacyReleases = try decoder.decode([LegacyReleaseRecord].self, from: data)
        return legacyReleases.map { $0.asListing() }
    }
}
