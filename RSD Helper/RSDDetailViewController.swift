//
//  RSDDetailViewController.swift
//  RSD Helper
//
//  Created by David Strauss on 4/17/17.
//  Copyright © 2017 David Strauss. All rights reserved.
//

import UIKit
import Social
import StoreKit
import MediaPlayer

protocol RSDDetailViewControllerDelegate {
    func wasSearchActive(_ bool: Bool)
    func cameFromHome(_ bool: Bool)
}

protocol RSDDetailVCDelegate {
    func updateFavoriteListings(_ array: [Listing])
}

class RSDDetailViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var buttonBack: UIBarButtonItem!
    @IBOutlet weak var tableViewDetail: UITableView!
    
    var passedListing: Listing?
    var fromSearch = false
    var fromHome = false
    var isFavorited = false
    var delegate: RSDDetailViewControllerDelegate!
    var newDelegate: RSDDetailVCDelegate!
    var favoriteListings : [Listing] = []
    var canPlay = true
    var canStream = true
    let systemMusicPlayer = MPMusicPlayerController.systemMusicPlayer
    var albumID = [""]
    var noMatchingEntries = false
    var passedIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()

        tableViewDetail.rowHeight = UITableView.automaticDimension
        tableViewDetail.estimatedSectionHeaderHeight = 280
        
        tableViewDetail.estimatedRowHeight = 50;
        tableViewDetail.backgroundView = UIView()
        
        navigationItem.title = passedListing!.artist
        
        if let data = UserDefaults.standard.data(forKey: "2018FavoritesList") {
            let listings = NSKeyedUnarchiver.unarchiveObject(with: data) as? [Listing]
            favoriteListings = listings!
        } else {
            print("There is an issue")
        }
        
        if !(self.favoriteListings.contains(where: { $0.photoURL == (self.passedListing?.photoURL) })) {
            
            isFavorited = false
            
        } else {
            
            isFavorited = true
            
        }
        
        appleMusicCheckIfDeviceCanPlayback()
        
        if canPlay {
            self.searchiTunes((self.passedListing?.album)!)
        }
        
        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        
        tableViewDetail.register(UINib(nibName: "RSDDetailHeaderView", bundle: nil), forHeaderFooterViewReuseIdentifier: "RSDDetailHeaderView")
        
    }
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        tableViewDetail.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        return
        
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        return 3
        
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "RSDDetailCell", for: indexPath) as? RSDDetailTableViewCell
        
        switch indexPath.row {
        case 0:
            cell?.labelType.text = "Label"
            cell?.labelInfo.text = passedListing?.label
        case 1:
            cell?.labelType.text = "Quantity"
            if let newQuantity = passedListing?.quantity {
                if newQuantity == "0" {
                    cell?.labelInfo.text = "N/A"
                } else {
                    cell?.labelInfo.text = newQuantity
                }
            }
//            cell?.labelInfo.text = passedListing?.quantity
        case 2:
            cell?.labelType.text = "More Info"
            cell?.labelInfo.text = passedListing?.moreInfo
        default:
            cell?.labelType.text = ""
        }
        
        
        return cell!
        
        
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let headerView = tableView.dequeueReusableHeaderFooterView(withIdentifier: "RSDDetailHeaderView") as! RSDDetailHeaderView
        
//        headerView.imageAlbum.imageFromServerURL(urlString: (passedListing?.photoURL)!)
        headerView.imageAlbum.kf.setImage(with: URL(string:
            (passedListing?.photoURL)!), placeholder: UIImage(named: "filler"), options: nil, progressBlock: nil, completionHandler: { (image, error, cache, url) in

            let albumImage = TVButtonLayer(image: (headerView.imageAlbum.image)!)

            headerView.tvButton.layers = [albumImage]

            headerView.tvButton.layoutSubviews()

        })
        
        headerView.tvButton.shadowColor = .clear
        
        let tap = RSDLikeGesture(target: self, action: #selector(doubleTapped(gesture:)))
        tap.numberOfTapsRequired = 2
        tap.listing = passedListing
        tap.tvView = headerView.tvButton
        
        for listing in favoriteListings {
            if listing.photoURL == tap.listing.photoURL {
                tap.isFavorite = true
            }
        }
        
        headerView.tvButton.addGestureRecognizer(tap)
        
        headerView.labelAlbum.text = passedListing?.album
        headerView.labelFormat.text = passedListing?.format
//        headerView.delegate = self
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {

        return 260

    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        
        return 1
        
    }

    @IBAction func buttonBackPressed(_ sender: Any) {
        
        if fromSearch && fromHome {
            self.delegate.wasSearchActive(true)
            self.delegate.cameFromHome(true)
        } else if !fromSearch && fromHome {
            self.delegate.wasSearchActive(false)
            self.delegate.cameFromHome(true)
        } else {
            self.delegate.cameFromHome(false)
        }
        navigationController?.dismiss(animated: true, completion: nil)
        
    }
    
    @IBAction func buttonSharePressed(_ sender: Any) {
        
        
        
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        var addFavorites = UIAlertAction()
        var removeFavorites = UIAlertAction()
        
//        if isFavorited {
//
//            removeFavorites = UIAlertAction(title: "Remove From Favorites", style: .destructive) { (action) in
//
//                if self.favoriteListings.contains(where: { $0.album == (self.passedListing?.album) }) {
////                    self.favoriteListings.remove(at: self.passedIndex)
////                    if let listicle = self.favoriteListings.index(of: self.passedListing!) {
////                        self.favoriteListings.remove(at: listicle)
////                    }
//                    for listing in self.favoriteListings {
//                        if listing.artist == self.passedListing?.artist {
//                            self.favoriteListings.remove(at: self.favoriteListings.index(of: listing)!)
//                        }
//                    }
//                    self.isFavorited = false
//                    let encodedData = NSKeyedArchiver.archivedData(withRootObject: self.favoriteListings)
//                    let userDefaults = UserDefaults.standard
//                    userDefaults.set(encodedData, forKey: "2018FavoritesList")
//                }
//
//
//            }
//
//        } else {
//
//            addFavorites = UIAlertAction(title: "Add To Favorites", style: .default, handler: { (action) -> Void in
//
//                if !(self.favoriteListings.contains(where: { $0 == (self.passedListing) })) {
//                    self.favoriteListings.append(self.passedListing!)
//                    let encodedData = NSKeyedArchiver.archivedData(withRootObject: self.favoriteListings)
//                    let userDefaults = UserDefaults.standard
//                    userDefaults.set(encodedData, forKey: "2018FavoritesList")
//                    self.isFavorited = true
//                }
//
//            })
//        }
        
        let  shareAlbum = UIAlertAction(title: "Share To Facebook", style: .default, handler: { (action) -> Void in
            
            let vc = SLComposeViewController(forServiceType:SLServiceTypeFacebook)
            let headerView = self.tableViewDetail.headerView(forSection: 0) as! RSDDetailHeaderView
            vc?.add(headerView.imageAlbum.image)
            self.present(vc!, animated: true, completion: nil)
            
        })
        
        
        let streamAlbum = UIAlertAction(title: "Stream on Apple Music", style: .default, handler: { (action) -> Void in
            
            
            self.appleMusicRequestPermission()
            self.appleMusicCheckIfDeviceCanPlayback()
            if self.canPlay {
                self.systemMusicPlayer.setQueue(with: self.albumID)
                
//                self.appleMusicFetchStorefrontRegion()
//                self.appleMusicPlayTrackId(ids: ["44733748"])
                self.appleMusicPlay()
                
                
            }
            
        })
        
        let cancelButton = UIAlertAction(title: "Cancel", style: .cancel, handler: { (action) -> Void in
            print("Cancel button tapped")
        })
        
        
//        if isFavorited {
//            alertController.addAction(removeFavorites)
//        }
//        else {
//            alertController.addAction(addFavorites)
//        }
        if canStream && noMatchingEntries == false {
            alertController.addAction(streamAlbum)
        }
        alertController.addAction(shareAlbum)
        alertController.addAction(cancelButton)
        
        self.navigationController!.present(alertController, animated: true, completion: nil)
        
    }
    
    @objc func doubleTapped(gesture: RSDLikeGesture) {
        // Add/Remove From Favorites
        
        if gesture.isFavorite {
            let likeImage = UIImage(named: "unlikeBig")
            let likeImageView = UIImageView(image: likeImage)
            likeImageView.frame = (gesture.view?.frame)!
            likeImageView.center.x = (gesture.tvView?.center.x)! - 100
            likeImageView.center.y = (gesture.tvView?.center.y)! + 15
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
                self.isFavorited = false
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
                    self.tableViewDetail.reloadData()
                }
                
            }
        } else {
            let likeImage = UIImage(named: "likeBig")
            let likeImageView = UIImageView(image: likeImage)
            likeImageView.frame = (gesture.view?.frame)!
            likeImageView.center.x = (gesture.tvView?.center.x)! - 100
            likeImageView.center.y = (gesture.tvView?.center.y)! + 15
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
                self.isFavorited = true
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
                    self.tableViewDetail.reloadData()
                }
                
            }
        }
    }
    
    func appleMusicCheckIfDeviceCanPlayback() {
        let serviceController = SKCloudServiceController()
        serviceController.requestCapabilities { (capability, error) in
            switch capability {
                
            case []:
                
                print("The user doesn't have an Apple Music subscription available. Now would be a good time to prompt them to buy one?")
                self.canPlay = false
                
            case SKCloudServiceCapability.musicCatalogPlayback:
                
                print("The user has an Apple Music subscription and can playback music!")
                self.canPlay = true
                
            case SKCloudServiceCapability.addToCloudMusicLibrary:
                
                print("The user has an Apple Music subscription, can playback music AND can add to the Cloud Music Library")
                self.canPlay = true
                
            default: break
                
            }
        }
        
    }
    
    func appleMusicRequestPermission() {
        
        switch SKCloudServiceController.authorizationStatus() {
            
        case .authorized:
            
            print("The user's already authorized - we don't need to do anything more here, so we'll exit early.")
            return
            
        case .denied:
            
            print("The user has selected 'Don't Allow' in the past - so we're going to show them a different dialog to push them through to their Settings page and change their mind, and exit the function early.")
            
            // Show an alert to guide users into the Settings
            
            let alert = UIAlertController(title: "Oops!", message: "You previously chose not to allow RSD Assistant to access your library, please navigate to Settings -> Privacy -> Media & Apple Music and enable this option.", preferredStyle: .alert)
            
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (success) in
                guard let settingsUrl = URL(string: UIApplication.openSettingsURLString) else {
                    return
                }
                
                if UIApplication.shared.canOpenURL(settingsUrl) {
                    UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                        print("Settings opened: \(success)") // Prints true
                    })
                }
            }))
            
            present(alert, animated: true, completion: nil)
            
            return
            
        case .notDetermined:
            
            print("The user hasn't decided yet - so we'll break out of the switch and ask them.")
            break
            
        case .restricted:
            
            print("User may be restricted; for example, if the device is in Education mode, it limits external Apple Music usage. This is similar behaviour to Denied.")
            return
            
        }
        
        SKCloudServiceController.requestAuthorization { (status:SKCloudServiceAuthorizationStatus) in
            
            switch status {
                
            case .authorized:
                
                print("All good - the user tapped 'OK', so you're clear to move forward and start playing.")
                
            case .denied:
                
                print("The user tapped 'Don't allow'. Read on about that below...")
                
            case .notDetermined:
                
                print("The user hasn't decided or it's not clear whether they've confirmed or denied.")
                
            default: break
                
            }
            
        }
        
    }
    
    func appleMusicPlayTrackId(ids:[String]) {
        
        searchiTunes((passedListing?.album)!)
        
    }
    
    func appleMusicPlay() {

            self.systemMusicPlayer.play()
        
    }
    
    func searchiTunes(_ string: String) {

        let iT = iTunes(session: URLSession.shared, debug: false)
        iT.search(for: string, ofType: .music(.album)) { result in
            // handle the Result<Any, SearchError>
//            print(result)
            

                for (key, value) in result.value as! [String: Any] {
    //                print(value)
                    if let info = value as? [[String:Any]] {
                        let count = info.count
                        if count > 0 {
                            if let collectionName = info[0]["collectionName"] {
//                                print(collectionName)
                                //check against Artist name to confirm
                                for listing in info {
                                    print(listing)
                                    if info[0]["artistName"] as? String == self.passedListing?.artist {
                                        if let id = info[0]["collectionId"] {
                                            self.albumID = [String(describing: id)]
                                            
                                            self.canStream = true
                                            self.noMatchingEntries = false
                                            
                                        }
                                    } else {
                                        self.noMatchingEntries = true
                                    }
                                //get album ID and pass to player
                                }
                                
                            } 
                        } else {
                            //display alert "Can Not Be Found In Apple Music"
//                            let alert = UIAlertController(title: "Unable to Locate", message: "Apple Music does not currently carry this title to stream.", preferredStyle: .alert)
//                            alert.addAction(UIAlertAction(title: "Aww man...", style: .default) { action in
//                                // perhaps use action.title here
//                            })
//                            
//                            self.present(alert, animated: true)
                            self.canStream = false
                        }
                    }
                }
            }
        
    }
    
    func appleMusicFetchStorefrontRegion() {
        
        let serviceController = SKCloudServiceController()
            
        
        serviceController.requestStorefrontIdentifier { (id, error) in
            
            guard error == nil else {
                
                print("An error occured. Handle it here.")
                return
                
            }
            
            guard let id = id, id.count >= 6 else {
                
                print("Handle the error - the callback didn't contain a valid storefrontID.")
                return
                
            }
            
            let index = id.index(id.startIndex, offsetBy: 5)
            let trimmedId = id.substring(to: index)
            
            print("Success! The user's storefront ID is: \(trimmedId)")
            
            }
            
    }
}
