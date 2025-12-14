////
////  AppDelegate.swift
////  Dobbie
////
////  Created by Apple on 27/11/25.
////
//
//import UIKit
//import FirebaseCore
//
//
//@main
//class AppDelegate: UIResponder, UIApplicationDelegate {
//
//
//
//    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
//        FirebaseApp.configure()
//        // Override point for customization after application launch.
//        return true
//    }
//
//    // MARK: UISceneSession Lifecycle
//
//    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
//        // Called when a new scene session is being created.
//        // Use this method to select a configuration to create the new scene with.
//        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
//    }
//
//    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
//        // Called when the user discards a scene session.
//        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
//        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
//    }
//
//
//}
//



//
//  AppDelegate.swift
//  Dobbie
//
//  Created by Apple on 27/11/25.
//

import UIKit
import FirebaseCore

@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        // Override point for customization after application launch.
        return true
    }

    // Handle LinkedIn OAuth callback
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        if url.scheme == "dobbie" && url.host == "linkedin" {
            // Extract authorization code from URL
            guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                print("❌ No authorization code in callback URL")
                return false
            }
            
            print("✅ Received LinkedIn auth code:", code)
            
            // Pass the code to your PostViewController
            // Get reference to current PostViewController instance
            if let navigationController = UIApplication.shared.keyWindow?.rootViewController as? UINavigationController,
               let postVC = navigationController.topViewController as? PostViewController {
                postVC.handleLinkedInCallback(code: code)
            } else if let postVC = UIApplication.shared.keyWindow?.rootViewController as? PostViewController {
                postVC.handleLinkedInCallback(code: code)
            } else {
                // If PostViewController is not currently visible, store the code for later use
                UserDefaults.standard.set(code, forKey: "pending_linkedin_code")
                print("🔄 Stored LinkedIn code for later processing")
            }
            
            return true
        }
        return false
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
}
