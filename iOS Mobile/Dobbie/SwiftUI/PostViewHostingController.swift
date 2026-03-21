//
//  PostViewHostingController.swift
//  Dobbie
//
//  Bridge between UIKit and SwiftUI PostView
//

import SwiftUI
import UIKit

/// UIHostingController wrapper to embed PostView in UIKit navigation
class PostViewHostingController: UIHostingController<PostView> {
    
    required init?(coder: NSCoder) {
        super.init(coder: coder, rootView: PostView())
    }
    
    override init(rootView: PostView) {
        super.init(rootView: rootView)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Hide the navigation bar for a cleaner look
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        // Make background transparent so SwiftUI gradient shows
        view.backgroundColor = .clear
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
}

// MARK: - Easy Instantiation
extension PostViewHostingController {
    
    /// Create instance programmatically
    static func create() -> PostViewHostingController {
        return PostViewHostingController(rootView: PostView())
    }
}
