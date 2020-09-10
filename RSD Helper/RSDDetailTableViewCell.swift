//
//  RSDDetailTableViewCell.swift
//  RSD Helper
//
//  Created by David Strauss on 4/17/17.
//  Copyright © 2017 David Strauss. All rights reserved.
//

import UIKit

class RSDDetailTableViewCell: UITableViewCell {
    
    @IBOutlet weak var labelType: UILabel!
    @IBOutlet weak var labelInfo: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

    override func prepareForReuse() {
        
        labelType.text = ""
        labelInfo.text = ""
        
    }
}
