//
//  RSDFavoritesViewController.swift
//  RSD Helper
//
//  Created by David Strauss on 4/18/17.
//  Copyright © 2017 David Strauss. All rights reserved.
//

import UIKit

protocol RSDFavoritesViewControllerDelegate {
    func favoritesListUpdated(_ favoritesList: [Listing])
}

class RSDFavoritesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UICollectionViewDataSource, UICollectionViewDelegate, RSDDetailViewControllerDelegate, RSDDetailVCDelegate {


    var favoriteListings: [Listing]?
    var selectedListing : Listing?
    var delegate: RSDFavoritesViewControllerDelegate!
    var fromHome = false
    var searchActive = false
    var indexToPass = 0
    @IBOutlet weak var tableViewFavorites: UITableView!
    @IBOutlet weak var collectionViewFavorites: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()


    }
    
//    override func viewDidAppear(_ animated: Bool) {
//        
//        collectionViewFavorites.reloadData()
//        
//    }
//
//    override func viewWillLayoutSubviews() {
////        collectionViewFavorites.reloadData()
//    }
//    
    override func viewWillAppear(_ animated: Bool) {
        if let data = UserDefaults.standard.data(forKey: "2019FavoritesList") {
            let listings = NSKeyedUnarchiver.unarchiveObject(with: data) as? [Listing]
            favoriteListings = listings!
        } else {
            print("Unable to parse favorites")
        }
        collectionViewFavorites.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        collectionViewFavorites.reloadData()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
    selectedListing = favoriteListings?[indexPath.row]
    
    
    performSegue(withIdentifier: "segueDetailView", sender: nil)
    
    tableView.deselectRow(at: indexPath, animated: false)
    
    return
        
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        if let favorites = favoriteListings {
            if favorites.count > 0 {
            return favoriteListings!.count
            }
            else {
            return 0
            }
        }
        else {
            return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "RSDCell", for: indexPath) as? RSDTableViewCell

        cell?.labelArtist.text = favoriteListings![indexPath.row].artist
        cell?.labelAlbum.text = favoriteListings![indexPath.row].album
        cell?.labelFormat.text = favoriteListings![indexPath.row].format
        cell?.imageAlbum.imageFromServerURL(favoriteListings![indexPath.row].photoURL)
        
        return cell!
        
    }
    
    func tableView(_ tableView: UITableView, editActionsForRowAt indexPath: IndexPath) -> [UITableViewRowAction]? {
        
        let more = UITableViewRowAction(style: .default, title: "\u{232B}") { action, index in
            self.favoriteListings!.remove(at: indexPath.row)
            self.delegate.favoritesListUpdated(self.favoriteListings!)
            self.tableViewFavorites.reloadData()
        }
        more.backgroundColor = UIColor.systemRed
        
        return [more]
        
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        return 1
        
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        
        if let favlistct = favoriteListings?.count {
            return favlistct
        } else {
            return 0
        }
        
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RSDCollectionCell", for: indexPath) as? RSDCollectionViewCell
        
        //        let background = TVButtonLayer(image: UIImage(named: "rsdbf")!)
        //        cell!.buttonAlbum.layers = [background]
        //        cell!.labelArtist.text = "Against Me!"
        //        cell!.labelAlbum.text = "An Album By Against Me!"
        //        cell?.labelFormat.text = "12\" Vinyl"
        
        cell?.labelArtist.text = favoriteListings?[indexPath.row].artist
        cell?.labelAlbum.text = favoriteListings?[indexPath.row].album
        //        cell?.labelFormat.text = listingsArray[indexPath.row].format
        cell?.imageFormatIcon.image = UIImage(named: "RSD_Format_Icon_Dark")
        
        if (favoriteListings?[indexPath.row].format.range(of: "Box") != nil) {
            
            cell?.imageFormatIcon.image = UIImage(named: "RSD_Format_Box_Icon")
            
            
        } else if (favoriteListings?[indexPath.row].format.range(of: "EP") != nil) {
            
            cell?.imageFormatIcon.image = UIImage(named: "SingleIcon")
            
        } else if (favoriteListings?[indexPath.row].format.range(of: "Cassette") != nil) {

             cell?.imageFormatIcon.image = UIImage(named: "CassetteIcon")
            
        } else if (favoriteListings?[indexPath.row].format.range(of: "CD") != nil) {

             cell?.imageFormatIcon.image = UIImage(named: "CDIcon")
            
        } else {
            cell?.imageFormatIcon.image = UIImage(named: "iconLarge")
        }
        
        if (favoriteListings?[indexPath.row].format.range(of: "2 x") != nil) {
           cell?.labelRecordSize.text = "2 x"
           cell?.labelRecordSize.isHidden = false
        }  else if (favoriteListings?[indexPath.row].format.range(of: "3 x") != nil) {
           cell?.labelRecordSize.text = "3 x"
           cell?.labelRecordSize.isHidden = false
        } else if (favoriteListings?[indexPath.row].format.range(of: "7") != nil) {
            cell?.labelRecordSize.text = "7\""
            cell?.labelRecordSize.isHidden = false
        } else if (favoriteListings?[indexPath.row].format.range(of: "12") != nil) || (favoriteListings?[indexPath.row].format.range(of: "LP") != nil) {
            cell?.labelRecordSize.text = "12\""
            cell?.labelRecordSize.isHidden = false
        } else if (favoriteListings?[indexPath.row].format.range(of: "3\"") != nil) {
            cell?.labelRecordSize.text = "3\""
            cell?.labelRecordSize.isHidden = false
        } else if (favoriteListings?[indexPath.row].format.range(of: "10") != nil) {
            cell?.labelRecordSize.text = "10\""
            cell?.labelRecordSize.isHidden = false
        } else {
            cell?.labelRecordSize.isHidden = true
        }
        
        //        cell?.imageAlbum.imageFromServerURL(listingsArray[indexPath.row].photoURL)
        cell?.imageAlbum.kf.indicatorType = .activity
        cell?.imageAlbum.kf.setImage(with: URL(string: (favoriteListings?[indexPath.row].photoURL)!), placeholder: UIImage(named: "filler"), options: nil, progressBlock: nil, completionHandler: { (image, error, cache, url) in
            
            let albumImage = TVButtonLayer(image: (cell?.imageAlbum.image)!)
            cell?.buttonAlbum.layers = [albumImage] //, formatNumber]
            cell?.buttonAlbum.layoutSubviews()
        
        })
        
        cell?.buttonAlbum.shadowColor = .clear
        //        cell?.imageAlbum.image = cell?.imageAlbum.image?.imageFromServerURL(listingsArray[indexPath.row].photoURL)
        
        
        
//        cell?.imageFormatIcon.isHidden = true
        //        cell?.imageAlbum.isHidden = true
        
        return cell!
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        
        //            if searchActive {
        //                selectedListing = filtered[indexPath.row]
        //            } else {
        selectedListing = favoriteListings?[indexPath.row]
        //            }
        indexToPass = indexPath.row
        
        performSegue(withIdentifier: "segueDetailView", sender: nil)
        
        collectionView.deselectItem(at: indexPath, animated: false)
        
        return
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        
        let cell = collectionViewFavorites.cellForItem(at: indexPath)
        
        cell?.backgroundColor = UIColor.secondarySystemBackground
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        
        let cell = collectionViewFavorites.cellForItem(at: indexPath)
        
        cell?.backgroundColor = UIColor.systemBackground
        
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "segueDetailView" {
            let destinationNavigationController = segue.destination as! UINavigationController
            let targetController = destinationNavigationController.topViewController as! RSDDetailViewController
            targetController.passedListing = selectedListing
            targetController.fromHome = false
            targetController.delegate = self
            targetController.passedIndex = indexToPass
            
        }
    }
    
    func cameFromHome(_ bool: Bool) {
        
        fromHome = bool
        
    }
    
    func wasSearchActive(_ bool: Bool) {
        
        searchActive = bool
        
    }
    
    func updateFavoriteListings(_ array: [Listing]) {
        
        collectionViewFavorites.reloadData()
        
    }
}
