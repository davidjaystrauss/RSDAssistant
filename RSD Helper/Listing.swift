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
    var quantity: String
    var photoURL: String
    var moreInfo: String
    
    public init(artist: String,
                album: String,
                format: String,
                label: String,
                quantity: String,
                photoURL: String,
                moreInfo: String)
    {
        self.artist = artist
        self.album = album
        self.format = format
        self.label = label
        self.quantity = quantity
        self.photoURL = photoURL
        self.moreInfo = moreInfo
    }
    
    required init(coder aDecoder: NSCoder) {

        self.artist = aDecoder.decodeObject(forKey: "artist") as! String
        self.album = aDecoder.decodeObject(forKey: "album") as! String
        self.format = aDecoder.decodeObject(forKey: "format") as! String
        self.label = aDecoder.decodeObject(forKey: "label") as! String
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
        aCoder.encode(self.quantity, forKey: "quantity")
        aCoder.encode(self.photoURL, forKey: "photoURL")
        aCoder.encode(self.moreInfo, forKey: "moreInfo")
    }
    
}
