//
//  RSDViewController.swift
//  RSD Helper
//
//  Created by David Strauss on 4/14/17.
//  Copyright © 2017 David Strauss. All rights reserved.
//

import UIKit
import StoreKit

class RSDViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UISearchBarDelegate, RSDFavoritesViewControllerDelegate, RSDDetailViewControllerDelegate, RSDDetailVCDelegate {

    func updateFavoriteListings(_ array: [Listing]) {
        
        favoriteListings = array
        
    }

    @IBOutlet weak var collectionViewRSD: UICollectionView!
    
    var albumImage: UIImage?
    var listingsArray = [Listing]()
    var selectedListing : Listing?
    var favoriteListings : [Listing] = []
    var searchBar = UISearchBar()
    var searchActive : Bool = false
    var filtered:[Listing] = []
    var filteredFormat:[Listing] = []
    var scrollingStopped = true
    var cameFromHome = true
    var count = 0
    var visualBG: UIVisualEffectView?
    var sorting = ["artist", "album", "format"]
    var currentSort = "artist"
    var indexToPass = 0
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        collectionViewRSD.register(UINib(nibName: "RSDCollectionSearchReusableView", bundle: nil), forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "RSDSearchHeaderView")
        
        readDataFromFile()
        
        if let flowLayout = self.collectionViewRSD?.collectionViewLayout as? UICollectionViewFlowLayout {

            flowLayout.headerReferenceSize = CGSize(width: self.collectionViewRSD.frame.size.width, height: 40)
            
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        if let data = UserDefaults.standard.data(forKey: "2019FavoritesList") {
            let listings = NSKeyedUnarchiver.unarchiveObject(with: data) as? [Listing]
            favoriteListings = listings!
        } else {
            print("There is an issue")
        }
        
        collectionViewRSD.reloadData()
        
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        collectionViewRSD.reloadData()
    }
    
    func readDataFromFile() {
        
        do {
            if let file = Bundle.main.url(forResource: "rsdbf2019", withExtension: "json") {
                let data = try Data(contentsOf: file)
                let json = try JSONSerialization.jsonObject(with: data, options: [])
                if let _ = json as? [String: Any] {
                } else if let listings = json as? [[String: Any]] {
                    for listing in listings {
                        let newListing = Listing(artist: listing["Artist"] as! String, album: listing["Album"] as! String, format: listing["Format"] as! String, label: listing["Label"] as! String, quantity: String(describing: listing["Quantity"]!), photoURL: listing["PhotoURL"] as! String, moreInfo: listing["More Info"] as! String)
                        
                        listingsArray.append(newListing)
                        listingsArray.sort(by: { $0.artist < $1.artist })
                    }
                } else {
                    print("JSON is invalid")
                }
            } else {
                print("no json file found")
            }
        } catch {
            print(error.localizedDescription)
        }
        
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if searchActive {
            return (filtered.count)
        } else {
            return (listingsArray.count)
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "RSDCollectionCell", for: indexPath) as? RSDCollectionViewCell
        
        let tap = RSDLikeGesture(target: self, action: #selector(doubleTapped(gesture:)))
        tap.numberOfTapsRequired = 2
        
        if searchActive {
            tap.listing = filtered[indexPath.row]
        } else {
            tap.listing = listingsArray[indexPath.row]
        }
        
        tap.indexP = indexPath
        
        for listing in favoriteListings {
            if listing.photoURL == tap.listing.photoURL {
                tap.isFavorite = true
            }
        }
        
        cell?.buttonAlbum.addGestureRecognizer(tap)
        
        if(searchActive){
            cell?.labelArtist.text = filtered[indexPath.row].artist
            cell?.labelAlbum.text = filtered[indexPath.row].album
            
            if (listingsArray[indexPath.row].format.range(of: "Box") != nil) {
                cell?.imageFormatIcon.image = UIImage(named: "RSD_Format_Box_Icon")
            } else if (listingsArray[indexPath.row].format.range(of: "EP") != nil) {
                cell?.imageFormatIcon.image = UIImage(named: "SingleIcon")
            } else if (listingsArray[indexPath.row].format.range(of: "Cassette") != nil) {
                 cell?.imageFormatIcon.image = UIImage(named: "CassetteIcon")
            } else if (listingsArray[indexPath.row].format.range(of: "CD") != nil) {
                 cell?.imageFormatIcon.image = UIImage(named: "CDIcon")
            } else {
                cell?.imageFormatIcon.image = UIImage(named: "iconLarge")
            }
            
            if (listingsArray[indexPath.row].format.range(of: "2 x") != nil) {
               cell?.labelRecordSize.text = "2 x"
               cell?.labelRecordSize.isHidden = false
            }  else if (listingsArray[indexPath.row].format.range(of: "3 x") != nil) {
               cell?.labelRecordSize.text = "3 x"
               cell?.labelRecordSize.isHidden = false
            } else if (listingsArray[indexPath.row].format.range(of: "7") != nil) {
                cell?.labelRecordSize.text = "7\""
                cell?.labelRecordSize.isHidden = false
            } else if (listingsArray[indexPath.row].format.range(of: "12") != nil) || (listingsArray[indexPath.row].format.range(of: "LP") != nil) {
                cell?.labelRecordSize.text = "12\""
                cell?.labelRecordSize.isHidden = false
            } else if (listingsArray[indexPath.row].format.range(of: "3\"") != nil) {
                cell?.labelRecordSize.text = "3\""
                cell?.labelRecordSize.isHidden = false
            } else if (listingsArray[indexPath.row].format.range(of: "10") != nil) {
                cell?.labelRecordSize.text = "10\""
                cell?.labelRecordSize.isHidden = false
            } else {
                cell?.labelRecordSize.isHidden = true
            }
            
            cell?.imageAlbum.kf.indicatorType = .activity
            cell?.imageAlbum.kf.setImage(with: URL(string: self.filtered[indexPath.row].photoURL), placeholder: UIImage(named: "filler"), options: nil, progressBlock: nil, completionHandler: { (image, error, cache, url) in

                let albumImage = TVButtonLayer(image: (cell?.imageAlbum.image)!)
                cell?.buttonAlbum.layers = [albumImage]
                cell?.buttonAlbum.layoutSubviews()

            })
        } else {
        cell?.labelArtist.text = listingsArray[indexPath.row].artist
        cell?.labelAlbum.text = listingsArray[indexPath.row].album
        
        if (listingsArray[indexPath.row].format.range(of: "Box") != nil) {
            cell?.imageFormatIcon.image = UIImage(named: "RSD_Format_Box_Icon")
        } else if (listingsArray[indexPath.row].format.range(of: "EP") != nil) {
            cell?.imageFormatIcon.image = UIImage(named: "SingleIcon")
        } else if (listingsArray[indexPath.row].format.range(of: "Cassette") != nil) {
             cell?.imageFormatIcon.image = UIImage(named: "CassetteIcon")
        } else if (listingsArray[indexPath.row].format.range(of: "CD") != nil) {
             cell?.imageFormatIcon.image = UIImage(named: "CDIcon")
        } else {
            cell?.imageFormatIcon.image = UIImage(named: "iconLarge")
        }
            
        if (listingsArray[indexPath.row].format.range(of: "2 x") != nil) {
           cell?.labelRecordSize.text = "2 x"
           cell?.labelRecordSize.isHidden = false
        }  else if (listingsArray[indexPath.row].format.range(of: "3 x") != nil) {
           cell?.labelRecordSize.text = "3 x"
           cell?.labelRecordSize.isHidden = false
        } else if (listingsArray[indexPath.row].format.range(of: "7") != nil) {
            cell?.labelRecordSize.text = "7\""
            cell?.labelRecordSize.isHidden = false
        } else if (listingsArray[indexPath.row].format.range(of: "12") != nil) || (listingsArray[indexPath.row].format.range(of: "LP") != nil) {
            cell?.labelRecordSize.text = "12\""
            cell?.labelRecordSize.isHidden = false
        } else if (listingsArray[indexPath.row].format.range(of: "3\"") != nil) {
            cell?.labelRecordSize.text = "3\""
            cell?.labelRecordSize.isHidden = false
        } else if (listingsArray[indexPath.row].format.range(of: "10") != nil) {
            cell?.labelRecordSize.text = "10\""
            cell?.labelRecordSize.isHidden = false
        } else {
            cell?.labelRecordSize.isHidden = true
        }

        cell?.imageAlbum.kf.indicatorType = .activity
        cell?.imageAlbum.kf.setImage(with: URL(string: self.listingsArray[indexPath.row].photoURL), placeholder: UIImage(named: "filler"), options: nil, progressBlock: nil, completionHandler: { (image, error, cache, url) in
            
            let albumImage = TVButtonLayer(image: (cell?.imageAlbum.image)!)
            cell?.buttonAlbum.layers = [albumImage]
            cell?.buttonAlbum.layoutSubviews()
            
        })
        
        }
        
        cell?.buttonAlbum.shadowColor = .clear
        
//        cell?.imageFormatIcon.isHidden = true
        return cell!
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
    
            if searchActive {
                selectedListing = filtered[indexPath.row]
                indexToPass = indexPath.row
            } else {
                selectedListing = listingsArray[indexPath.row]
            }
        
        
        
            performSegue(withIdentifier: "segueDetailView", sender: nil)
            
            collectionView.deselectItem(at: indexPath, animated: false)
            
            return
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didHighlightItemAt indexPath: IndexPath) {
        
        let cell = collectionViewRSD.cellForItem(at: indexPath)
        
        cell?.backgroundColor = UIColor.secondarySystemBackground
        
    }
    
    func collectionView(_ collectionView: UICollectionView, didUnhighlightItemAt indexPath: IndexPath) {
        
        let cell = collectionViewRSD.cellForItem(at: indexPath)
        
        cell?.backgroundColor = UIColor.systemBackground
        
    }
    
    func collectionView(_ collectionView: UICollectionView, viewForSupplementaryElementOfKind kind: String, at indexPath: IndexPath) -> UICollectionReusableView {
        
        if kind == UICollectionView.elementKindSectionHeader {
            let headerView = collectionView.dequeueReusableSupplementaryView(ofKind: UICollectionView.elementKindSectionHeader, withReuseIdentifier: "RSDSearchHeaderView", for: indexPath) as! RSDCollectionSearchReusableView
            headerView.searchBar.delegate = self
            return headerView
        }
        else {
            return UICollectionReusableView()
        }
        
    }
    
    
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        
        if segue.identifier == "segueDetailView" {
            
            let destinationNavigationController = segue.destination as! UINavigationController
            let targetController = destinationNavigationController.topViewController as! RSDDetailViewController
            targetController.passedListing = selectedListing
            if searchActive {
                targetController.fromSearch = true
            } else {
                targetController.fromSearch = false
            }
            targetController.fromHome = true
            targetController.delegate = self
            targetController.newDelegate = self
        
        } else if segue.identifier == "segueFavorites" {
            
            let vc = segue.destination as! RSDFavoritesViewController
            vc.favoriteListings = favoriteListings
            vc.delegate = self
            
        }
        
    }
    
    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchActive = true;
    }
    
    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchActive = false;
        self.collectionViewRSD.reloadData()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchActive = false;
        collectionViewRSD.reloadData()
        searchBar.endEditing(true)
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.collectionViewRSD.reloadData()
        searchActive = true;
    }
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        
        if searchText.count > 0 {
            searchActive = true
            
            filtered = listingsArray.filter({ (text) -> Bool in
            
                let tmp: NSString = text.artist as NSString
                let range = tmp.range(of: searchText, options: NSString.CompareOptions.caseInsensitive)
                return range.location != NSNotFound
            })
        } else {
            filtered = listingsArray
            searchBar.text = ""
            searchActive = false
        }
        
        
        if(filtered.count == 0){
            searchActive = false;
        } else {
            searchActive = true;
        }
        
        //causing keyboard dismissal on every keystroke?
//        self.collectionViewRSD.reloadData()
    }
    
    func favoritesListUpdated(_ favoritesList: [Listing]) {
        
        favoriteListings = favoritesList
//        UserDefaults.standard.setValue(favoriteListings, forKey: "favoritesList")
        let encodedData = NSKeyedArchiver.archivedData(withRootObject: self.favoriteListings)
        let userDefaults = UserDefaults.standard
        userDefaults.set(encodedData, forKey: "2019FavoritesList")
    }
    
    func wasSearchActive(_ bool: Bool) {
        
        searchActive = bool
        
    }
    
    func cameFromHome(_ bool: Bool) {
        
        cameFromHome = true
        
    }
    
    @objc func doubleTapped(gesture: RSDLikeGesture) {
        // Add/Remove From Favorites
        
        let i = arc4random_uniform(9)
        
        if gesture.isFavorite {
            let likeImage = UIImage(named: "unlikeBig")
            let likeImageView = UIImageView(image: likeImage)
            likeImageView.frame = (gesture.view?.frame)!
            likeImageView.center.x = (gesture.view?.center.x)! + 12
            likeImageView.center.y = (gesture.view?.center.y)! + 13
            likeImageView.frame.size.height = (gesture.view?.frame.size.height)! / 2
            likeImageView.frame.size.width = (gesture.view?.frame.size.width)! / 2
            gesture.view?.addSubview(likeImageView)
            gesture.view?.bringSubviewToFront(likeImageView)
            likeImageView.alpha = 0
            
            //Remove from favorites
            if self.favoriteListings.contains(where: { $0.photoURL == (gesture.listing.photoURL) }) {
                for listing in self.favoriteListings {
                    if listing.photoURL == gesture.listing.photoURL {
                        self.favoriteListings.remove(at: self.favoriteListings.firstIndex(of: listing)!)
                    }
                }
                let encodedData = NSKeyedArchiver.archivedData(withRootObject: self.favoriteListings)
                let userDefaults = UserDefaults.standard
                userDefaults.set(encodedData, forKey: "2019FavoritesList")
            }
            
            UIView.animate(withDuration: 0.1, animations: {
                
                //Fade in heart image
                likeImageView.alpha = 1
                
                
            }) { (success) in
                
                UIView.animate(withDuration: 0.5, animations: {
                    
                    //Fade out heart image
                    likeImageView.alpha = 0
                    
                }) { (success) in
                    
                    gesture.view?.willRemoveSubview(likeImageView)
                    self.collectionViewRSD.reloadItems(at: [gesture.indexP])
                }
                
            }
        } else {
            let likeImage = UIImage(named: "likeBig")
            let likeImageView = UIImageView(image: likeImage)
            likeImageView.frame = (gesture.view?.frame)!
            likeImageView.center.x = (gesture.view?.center.x)! + 12
            likeImageView.center.y = (gesture.view?.center.y)! + 13
            likeImageView.frame.size.height = (gesture.view?.frame.size.height)! / 2
            likeImageView.frame.size.width = (gesture.view?.frame.size.width)! / 2
            gesture.view?.addSubview(likeImageView)
            gesture.view?.bringSubviewToFront(likeImageView)
            likeImageView.alpha = 0
            
            //Add to favorites
            if !(self.favoriteListings.contains(where: { $0.photoURL == (gesture.listing.photoURL) })) {
                self.favoriteListings.append(gesture.listing)
                let encodedData = NSKeyedArchiver.archivedData(withRootObject: self.favoriteListings)
                let userDefaults = UserDefaults.standard
                userDefaults.set(encodedData, forKey: "2019FavoritesList")
            }
            
            UIView.animate(withDuration: 0.1, animations: {
                
                //Fade in heart image
                likeImageView.alpha = 1
                
                
            }) { (success) in
                
                UIView.animate(withDuration: 0.5, animations: {
                    
                    //Fade out heart image
                    likeImageView.alpha = 0
                    
                }) { (success) in
                    
                    gesture.view?.willRemoveSubview(likeImageView)
                    self.collectionViewRSD.reloadItems(at: [gesture.indexP])
                    
                    print(i)
                    
                    if i == 6 {
                        SKStoreReviewController.requestReview()
                    }
                }
                
            }
        }
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        

        
    }
    
    @IBAction func buttonSortPressed(_ sender: Any) {
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            
        let sortByArtist = UIAlertAction(title: "Sort By Artist", style: .default, handler: { (action) -> Void in
            
            if self.searchActive {
                self.filtered.sort(by: { $0.artist < $1.artist })
            } else {
                self.listingsArray.sort(by: { $0.artist < $1.artist })
            }
            self.collectionViewRSD.reloadData()
            self.currentSort = "artist"
            
        })

        let sortByAlbum = UIAlertAction(title: "Sort By Album", style: .default) { (action) in
            
            if self.searchActive {
                self.filtered.sort(by: { $0.album < $1.album })
            } else {
                self.listingsArray.sort(by: { $0.album < $1.album })
            }
            self.collectionViewRSD.reloadData()
            self.currentSort = "album"
            
        }
        
        let sortByFormat = UIAlertAction(title: "Sort By Format", style: .default, handler: { (action) -> Void in
            
            if self.searchActive {
                self.filtered.sort(by: { $0.format < $1.format })
            } else {
                self.listingsArray.sort(by: { $0.format < $1.format })
            }
            self.collectionViewRSD.reloadData()
            self.currentSort = "format"
            
        })
        
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) -> Void in })
        
        
        switch currentSort {
        case "artist":
            alertController.addAction(sortByAlbum)
            alertController.addAction(sortByFormat)
            
        case "album":
            alertController.addAction(sortByArtist)
            alertController.addAction(sortByFormat)
            
        case "format":
            alertController.addAction(sortByArtist)
            alertController.addAction(sortByAlbum)
            
        default:
            break
        }
        
        alertController.addAction(cancelButton)
        
        self.navigationController!.present(alertController, animated: true, completion: nil)
        
    }
    
}

extension UIImageView {
    public func imageFromServerURL(_ urlString: String) {
        
        URLSession.shared.dataTask(with: URL(string: urlString)! as URL, completionHandler: { (data, response, error) -> Void in
            
            if error != nil {
                print(error!)
                return
            }
            DispatchQueue.main.async(execute: { () -> Void in
                let image = UIImage(data: data!)
                self.image = image
            })
            
        }).resume()
    }
}

extension UIImage {
    
    public func imageFromServerURL(_ urlString: String) -> UIImage {
        
        var image = UIImage()
        
        URLSession.shared.dataTask(with: URL(string: urlString)! as URL, completionHandler: { (data, response, error) -> Void in
            
            if error != nil {
                print(error!)
                return
            }
            DispatchQueue.main.async(execute: { () -> Void in
                image = UIImage(data: data!)!
            })
            
        }).resume()
        return image
    }
    
}

//extension RSDViewController: UIViewControllerPreviewingDelegate {
//
//    public func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
//
//        guard let indexPath = collectionViewRSD.indexPathForItem(at: location), let cell = collectionViewRSD.cellForItem(at: indexPath) as? RSDCollectionViewCell else {
//            return nil
//        }
//
//        guard let detailViewController =
//            storyboard?.instantiateViewController(
//                withIdentifier: "RSDDetailViewController") as?
//            RSDDetailViewController else { return nil }
//
//        if searchActive {
//            detailViewController.passedListing = filtered[indexPath.row]
//        } else {
//            detailViewController.passedListing = listingsArray[indexPath.row]
//        }
//        detailViewController.preferredContentSize =
//            CGSize(width: 0.0, height: 600)
//
//        previewingContext.sourceRect = cell.frame
//        detailViewController.delegate = self
//
//        let navigationController = UINavigationController(rootViewController: detailViewController)
//        navigationController.navigationBar.barStyle = .black
//        navigationController.navigationBar.barTintColor = UIColor.black
//
//        return navigationController
//
//    }
//
//    func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
//        show(viewControllerToCommit, sender: self)
//        performSegue(withIdentifier: "segueDetailView", sender: nil)
//    }
//
//    fileprivate func viewControllerForListing(_ listing: Listing) -> UIViewController {
//        let RSDDetailVC = RSDDetailViewController()
//        RSDDetailVC.passedListing = listing
//        return RSDDetailVC
//    }
//
//}

extension UIImage {
    class func imageWithLabel(label: UILabel) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(label.bounds.size, false, 0.0)
        label.layer.render(in: UIGraphicsGetCurrentContext()!)
        let img = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return img!
    }
}

class RSDLikeGesture: UITapGestureRecognizer {
    var isFavorite = false
    var listing: Listing!
    var indexP: IndexPath!
    var tvView: UIView!
}
