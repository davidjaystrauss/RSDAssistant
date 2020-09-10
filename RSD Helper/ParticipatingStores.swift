//
//  ParticipatingStores.swift
//  RSD Helper
//
//  Created by David Strauss on 1/31/18.
//  Copyright © 2018 David Strauss. All rights reserved.
//

import Foundation
import MapKit
import Contacts

class ParticipatingStore: NSObject, MKAnnotation {
    
    var latitude: String?
    var longitude: String?
    var name: String?
    var address: String?
    var city: String?
    var state: String?
    var zipcode: String?
    var subtitle: String?
    var coordinate: CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: ((latitude as NSString?)?.doubleValue)!, longitude: ((longitude as NSString?)?.doubleValue)!)
    }
    
    var title: String? {
        return name
    }
    
    func mapItem() -> MKMapItem {
        let addressDict = [CNPostalAddressStreetKey: address]
        let placemark = MKPlacemark(coordinate: coordinate, addressDictionary: addressDict)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = name
        return mapItem
    }
}
