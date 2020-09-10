//
//  RSDStoreMapViewController.swift
//  RSD Helper
//
//  Created by David Strauss on 1/31/18.
//  Copyright © 2018 David Strauss. All rights reserved.
//

import UIKit
import MapKit
import CoreLocation

class RSDStoreMapViewController: UIViewController, MKMapViewDelegate, CLLocationManagerDelegate {

    @IBOutlet weak var RSDMapView: MKMapView!
    
    let regionRadius: CLLocationDistance = 50000
    let locationManager = CLLocationManager()
    
    var storeArray = [ParticipatingStore]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        RSDMapView.showsUserLocation = true
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        
        getLocation()
        
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getLocation() {
        
        let status  = CLLocationManager.authorizationStatus()

        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }

        if status == .denied || status == .restricted {
            let alert = UIAlertController(title: "Location Services Disabled", message: "Please enable Location Services in Settings", preferredStyle: .alert)
            
            let okAction = UIAlertAction(title: "OK", style: .default, handler: nil)
            alert.addAction(okAction)
            
            present(alert, animated: true, completion: nil)
            return
        }

        locationManager.delegate = self
        locationManager.startUpdatingLocation()
        
    }
    
    func centerMapOnLocation(location: CLLocation) {
        let coordinateRegion = MKCoordinateRegion.init(center: location.coordinate,
                                                                  latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)

        RSDMapView.setRegion(coordinateRegion, animated: true)
    }
    
    func getJsonFromURL() {
        
        let url = NSURL(string: "http://www.recordstoreday.com/VenueLocationSearch.json?t=1&can_sell=1")

        UIApplication.shared.isNetworkActivityIndicatorVisible = true
        URLSession.shared.dataTask(with: (url as URL?)!, completionHandler: {(data, response, error) -> Void in
            
            if error == nil {
            
                if let jsonObj = ((try? JSONSerialization.jsonObject(with: data!, options: .allowFragments) as? NSDictionary) as NSDictionary??) {

    //                print(jsonObj!.value(forKey: "venues")!)
                    
                    if let stores = jsonObj!.value(forKey: "venues") as? NSArray {
                        
                        for store in stores {
                            
                            let newStore = ParticipatingStore()
                            
                            if let storeDict = store as? NSDictionary {
                                
                                if let latitude = storeDict.value(forKey: "latitude") {
                                    
                                    newStore.latitude = latitude as? String
                                    
                                }
                                
                                if let longitude = storeDict.value(forKey: "longitude") {
                                    
                                    newStore.longitude = longitude as? String
                                    
                                }
                                
                                if let name = storeDict.value(forKey: "name") {

                                    newStore.name = name as? String
                                    
                                }
                                
                                if let address = storeDict.value(forKey: "address") {
                                    
                                    newStore.address = address as? String
                                    
                                }
                                
                                if let city = storeDict.value(forKey: "city") {
                                    
                                    newStore.city = city as? String
                                    
                                }
                                
                                if let state = storeDict.value(forKey: "state") {
                                    
                                    newStore.state = state as? String
                                    
                                }
                                
                                if let zipcode = storeDict.value(forKey: "zipcode") {
                                    
                                    newStore.zipcode = zipcode as? String
                                    
                                }
                                
                                self.storeArray.append(newStore)
                                
                            }
                            
                        }
                    }
                    }
                    
                    OperationQueue.main.addOperation({
                        self.RSDMapView.addAnnotations(self.storeArray)
                        UIApplication.shared.isNetworkActivityIndicatorVisible = false
                        
    //                    let generator = UIImpactFeedbackGenerator(style: .light)
    //                    generator.impactOccurred()
                        
                    })
                
            }
        }).resume()
            
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        let currentLocation = locations.last!
        
        print("Current location: \(currentLocation)")
        
        locationManager.stopUpdatingLocation()
        
        centerMapOnLocation(location: currentLocation)
        
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        
        print("Error \(error)")
        
    }
    
    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
        
        getJsonFromURL()
        
    }
    
    func mapViewDidStopLocatingUser(_ mapView: MKMapView) {
        
        
    }
    
    func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        
        
        
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        
        guard let annotation = annotation as? ParticipatingStore else { return nil }
        
        let identifier = "marker"
        var view: MKMarkerAnnotationView
        
        if let dequeuedView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
            as? MKMarkerAnnotationView {
            dequeuedView.annotation = annotation
            view = dequeuedView
        } else {

            view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.canShowCallout = true
            view.calloutOffset = CGPoint(x: 0, y: 5)
            view.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
            view.rightCalloutAccessoryView?.tintColor = UIColor.systemBlue
            
        }
        return view
        
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView,
                 calloutAccessoryControlTapped control: UIControl) {
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        let location = view.annotation as! ParticipatingStore
        let launchOptions = [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving]
        location.mapItem().openInMaps(launchOptions: launchOptions)
    }

}
