//
//  LogoViewController.swift
//  Dobbie
//
//  Created by Apple on 27/11/25.
//

import UIKit

class LogoViewController: UIViewController {
    
    @IBOutlet weak var logo: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
//        logo.isUserInteractionEnabled = true
      

          // add it to the image view;
//          logo.addGestureRecognizer(tapGesture)
          // make sure imageView can be interacted with by user
//        logo.isUserInteractionEnabled = true
        

        // Do any additional setup after loading the view.
    }

    @IBAction func imageTapped(_ sender: UITapGestureRecognizer) {
        // handle tap here
        print("image tapped")
        self.performSegue(withIdentifier: "goToPoster", sender: self)
    }

   

}
