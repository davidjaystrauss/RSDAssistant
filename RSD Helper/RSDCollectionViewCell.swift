//
//  RSDCollectionViewCell.swift
//  RSD Helper
//
//  Created by David Strauss on 5/23/17.
//  Copyright © 2017 David Strauss. All rights reserved.
//

import UIKit

class RSDCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var buttonAlbum: TVButton!
    @IBOutlet weak var imageAlbum: UIImageView!
    @IBOutlet weak var imageFormatIcon: UIImageView!
    @IBOutlet weak var labelRecordSize: UILabel!
    @IBOutlet weak var labelArtist: UILabel!
    @IBOutlet weak var labelAlbum: UILabel!
    @IBOutlet weak var labelFormat: UILabel!
    
    override func awakeFromNib() {
        
//        imageAlbum.image = imageAlbum.imageFromServerURL(listingsArray[indexPath.row].photoURL)
        
//        buttonAlbum.layoutSubviews()
//        imageAlbum.layer.cornerRadius = 20
    }
    
    override func prepareForReuse() {
        
        let background = TVButtonLayer(image: UIImage(named: "filler")!)
        buttonAlbum.layers = [background]
        buttonAlbum.layoutSubviews()
        buttonAlbum.parallaxIntensity = 1.0
        buttonAlbum.shadowColor = .clear
        labelArtist.text = ""
        labelAlbum.text = ""
        imageAlbum.image = UIImage()
//        labelFormat.text = ""
        
    }
}
