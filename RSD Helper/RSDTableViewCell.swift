//
//  RSDTableViewCell.swift
//  RSD Helper
//
//  Created by David Strauss on 4/15/17.
//  Copyright © 2017 David Strauss. All rights reserved.
//

import UIKit

class RSDTableViewCell: UITableViewCell {

    @IBOutlet weak var imageAlbum: UIImageView!
    @IBOutlet weak var labelArtist: UILabel!
    @IBOutlet weak var labelAlbum: UILabel!
    @IBOutlet weak var labelFormat: UILabel!
    @IBOutlet weak var likeView: UIView!
    @IBOutlet weak var tvButton: UIButton!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
     
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    override func prepareForReuse() {
        
        imageAlbum.image = UIImage(named: "filler")
        labelArtist.text = ""
        labelAlbum.text = ""
        labelFormat.text = ""
        likeView.isHidden = true
        
    }
    
    deinit {
        
        imageAlbum.image = nil
        labelArtist.text = ""
        labelAlbum.text = ""
        labelFormat.text = ""
        
    }
    
    func animateLikeView() {
        
        self.likeView.superview?.frame.origin.x = (self.likeView.superview?.frame.origin.x)! - 50
        
        UIView.animate(withDuration: 0.2, delay: 0.8, options: .beginFromCurrentState, animations: {
            
            self.likeView.isHidden = false
            self.likeView.superview?.frame.origin.x = (self.likeView.superview?.frame.origin.x)! + 50
            
        }) { (Bool) in
        
                self.likeView.isHidden = true

        }
        
    }
}
