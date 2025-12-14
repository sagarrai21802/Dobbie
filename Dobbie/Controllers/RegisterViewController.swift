//
//  RegisterViewController.swift
//  Dobbie
//
//  Created by Apple on 27/11/25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class RegisterViewController: UIViewController {
    
    @IBOutlet weak var nameTextfield: UITextField!
    @IBOutlet weak var emailTextfield: UITextField!
    @IBOutlet weak var passwordTextfield: UITextField!
 

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func signUpButton(_ sender: UIButton) {
        if let name = nameTextfield.text, let email = emailTextfield.text , let password = passwordTextfield.text {
            Auth.auth().createUser(withEmail: email, password: password) { (authResult, error) in
                if let err = error {
                    print(err.localizedDescription)
                } else {
                    print("user created")
                    self.performSegue(withIdentifier: "RegisterToPoster", sender: self)
                }
            }
        }
    }
    
    
    
}
