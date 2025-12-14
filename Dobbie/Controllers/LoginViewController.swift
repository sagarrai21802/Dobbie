//
//  LoginViewController.swift
//  Dobbie
//
//  Created by Apple on 27/11/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class LoginViewController: UIViewController {
    
    @IBOutlet weak var emailtextfield: UITextField!
//    @IBOutlet weak var emailtextfield : UILabel!
//    @IBOutlet weak var passwordTextField : UILabel!
    @IBOutlet weak var passwordTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    @IBAction func loginButtonPressed(_ sender : UIButton ){
        if let email = emailtextfield.text , let password = passwordTextField.text {
            Auth.auth().signIn(withEmail: email, password: password) { authresult, error in
                if let err = error {
                    print("error in trying to login \(err.localizedDescription)")
                    return
                } else {
                    print("user sign up successfully")
                    self.performSegue(withIdentifier: "loginToPoster", sender: self)
                }
            }
        }
    }
     

}
