//
//  RegisterViewController.swift
//  Dobbie
//
//  Created by Apple on 27/11/25.
//

import UIKit

class RegisterViewController: UIViewController {
    
    @IBOutlet weak var nameTextfield: UITextField!
    @IBOutlet weak var emailTextfield: UITextField!
    @IBOutlet weak var passwordTextfield: UITextField!
 

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    @IBAction func signUpButton(_ sender: UIButton) {
        if let name = nameTextfield.text, !name.isEmpty,
           let email = emailTextfield.text, !email.isEmpty,
           let password = passwordTextfield.text, !password.isEmpty {
            // TODO: Implement your own registration logic here
            print("Registration attempt - Name: \(name), Email: \(email)")
            self.performSegue(withIdentifier: "RegisterToPoster", sender: self)
        } else {
            print("Please fill in all fields")
        }
    }
    
    
    
}
