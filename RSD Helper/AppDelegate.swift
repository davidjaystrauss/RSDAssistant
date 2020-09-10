//
//  AppDelegate.swift
//  RSD Helper
//
//  Created by David Strauss on 4/14/17.
//  Copyright © 2017 David Strauss. All rights reserved.
//

import UIKit
import Firebase

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        FirebaseApp.configure()
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        
        completionHandler(handleQuickAction(shortcutItem: shortcutItem))
        
    }

    enum Shortcut: String {
        case favorites = "Favorites"
        case locator = "Find A Store"
    }
    
    func handleQuickAction(shortcutItem: UIApplicationShortcutItem) -> Bool {
        
        var quickActionHandled = false
        let type = shortcutItem.type.components(separatedBy: ".").last
        if let shortcutType = Shortcut.init(rawValue: type!) {
            switch shortcutType {
            case .favorites:
                
                let nextController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RSDFavoritesViewController") as? RSDFavoritesViewController
                if let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RSDViewController") as? RSDViewController {
                    if let window = self.window, let rootViewController = window.rootViewController as? UINavigationController {
                        rootViewController.pushViewController(nextController!, animated: true)
                    }
                }
                
                quickActionHandled = true
            case .locator:
                
                let nextController = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RSDStoreMapViewController") as? RSDStoreMapViewController
                if let controller = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "RSDViewController") as? RSDViewController {
                    if let window = self.window, let rootViewController = window.rootViewController as? UINavigationController {
                        rootViewController.pushViewController(nextController!, animated: true)
                    }
                }
                
            }
        }
        
        return quickActionHandled
    }

}

