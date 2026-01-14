//
//  LoginViewController.swift
//  Dobbie
//
//  Created by Apple on 27/11/25.
//

import UIKit

class LoginViewController: UIViewController {
    
    @IBOutlet weak var emailtextfield: UITextField!
    @IBOutlet weak var passwordTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func loginButtonPressed(_ sender : UIButton ){
        if let email = emailtextfield.text, !email.isEmpty,
           let password = passwordTextField.text, !password.isEmpty {
            // TODO: Implement your own authentication logic here
            print("Login attempt with email: \(email)")
            self.performSegue(withIdentifier: "loginToPoster", sender: self)
        } else {
            print("Please enter email and password")
        }
    }
     

}
