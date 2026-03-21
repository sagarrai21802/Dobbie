////
////  PostViewController.swift
////  Dobbie
////
////  Created by Apple on 27/11/25.
////
//
//import UIKit
//import AuthenticationServices
//
//class PostViewController: UIViewController {
//
//    // MARK: - Outlets
//    @IBOutlet weak var topicTextField: UITextField!
//    @IBOutlet weak var TexTfield: UITextView!
//
//    // MARK: - Properties
//    private var webAuthSession: ASWebAuthenticationSession?
//    private let network = NetworkManager()
//
//    // MARK: - Life-cycle
//    override func viewDidLoad() {
//        super.viewDidLoad()
//    }
//
//    // MARK: - Actions
//    @IBAction func Connect(_ sender: UIButton) {
//        let authURLString = "https://www.linkedin.com/oauth/v2/authorization?" +
//                            "response_type=code" +
//                            "&client_id=\(LinkedIn.clientId)" +
//                            "&redirect_uri=\(LinkedIn.redirectURI)" +
//                            "&scope=w_member_social" +
//                            "&state=\(LinkedIn.state)"
//
//        guard let authURL = URL(string: authURLString) else { return }
//
//        webAuthSession = ASWebAuthenticationSession(
//            url: authURL,
//            callbackURLScheme: "dobbie") { [weak self] callback, error in
//                guard error == nil,
//                      let callback = callback,
//                      let query = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
//                      let code = query.first(where: { $0.name == "code" })?.value else {
//                    print("❌ Auth failed")
//                    return
//                }
//                self?.exchangeCodeForToken(code: code)
//            }
//
//        webAuthSession?.presentationContextProvider = self
//        webAuthSession?.start()
//    }
//
//    @IBAction func genertatecontentbutton(_ sender: UIButton) {
//        guard let topic = topicTextField.text, !topic.isEmpty else { return }
//
//        sender.isEnabled = false
//        let originalTitle = sender.title(for: .normal)
//        sender.setTitle("Loading...", for: .normal)
//
//        network.sendTopic(with: topic) { [weak self] responseText in
//            DispatchQueue.main.async {
//                self?.TexTfield.text = responseText ?? "No content generated"
//
//                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
//                    sender.setTitle(originalTitle, for: .normal)
//                    sender.isEnabled = true
//                }
//            }
//        }
//    }
//
//    // MARK: - LinkedIn OAuth
//    private func exchangeCodeForToken(code: String) {
//        let body = [
//            "grant_type": "authorization_code",
//            "code": code,
//            "redirect_uri": LinkedIn.redirectURI,
//            "client_id": LinkedIn.clientId,
//            "client_secret": LinkedIn.clientSecret
//        ]
//
//        var req = URLRequest(url: URL(string: "https://www.linkedin.com/oauth/v2/accessToken")!)
//        req.httpMethod = "POST"
//        req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
//        req.httpBody = body.percentEncoded()
//
//        URLSession.shared.dataTask(with: req) { data, resp, err in
//            if let err = err { print("❌ Token request error:", err); return }
//            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
//            print("🔍 Token HTTP status:", status)
//            if let body = data, let str = String(data: body, encoding: .utf8) {
//                print("🔍 Token response body:", str)
//            }
//            guard let data = data,
//                  let token = try? JSONDecoder().decode(LinkedInToken.self, from: data) else {
//                print("❌ Could not decode token"); return
//            }
//            print("✅ Access-token:", token.access_token)
//            // 1.  Get real numeric URN
//            self.fetchMemberURN(token: token.access_token)
//        }.resume()
//    }
//
//    // 2.  Fetch numeric member id → real URN
//    private func fetchMemberURN(token: String) {
//        var req = URLRequest(url: URL(string: "https://api.linkedin.com/v2/me")!)
//        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//
//        URLSession.shared.dataTask(with: req) { data, resp, err in
//            if let err = err { print("❌ /me error:", err); return }
//            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
//            print("🔍 /me HTTP status:", status)
//            if let body = data, let str = String(data: body, encoding: .utf8) {
//                print("🔍 /me raw body:", str)
//            }
//            guard let data = data,
//                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
//                  let id = json["id"] as? String else {
//                print("❌ no 'id' in /me response"); return
//            }
//            let urn = "urn:li:person:\(id)"
//            print("✅ Member URN:", urn)
//            DispatchQueue.main.async { self.postToLinkedIn(token: token, authorURN: urn) }
//        }.resume()
//    }
//
//    // 3.  Post with real URN
//    private func postToLinkedIn(token: String, authorURN: String) {
//        let postText = TexTfield.text ?? "Hello from Dobbie!"
//
//        let ugcPost: [String: Any] = [
//            "author": authorURN,                    // ← real numeric URN
//            "lifecycleState": "PUBLISHED",
//            "specificContent": [
//                "com.linkedin.ugc.ShareContent": [
//                    "shareCommentary": ["text": postText],
//                    "shareMediaCategory": "NONE"
//                ]
//            ],
//            "visibility": ["com.linkedin.ugc.MemberNetworkVisibility": "PUBLIC"]
//        ]
//
//        var req = URLRequest(url: URL(string: "https://api.linkedin.com/v2/ugcPosts")!)
//        req.httpMethod = "POST"
//        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
//        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
//        req.httpBody = try? JSONSerialization.data(withJSONObject: ugcPost)
//
//        URLSession.shared.dataTask(with: req) { data, resp, _ in
//            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
//            print("🔍 Post HTTP status:", status)
//            if let body = data, let str = String(data: body, encoding: .utf8) {
//                print("🔍 Post response body:", str)
//            }
//            DispatchQueue.main.async {
//                let ok = status == 201
//                let alert = UIAlertController(title: ok ? "Posted!" : "Failed", message: nil, preferredStyle: .alert)
//                alert.addAction(UIAlertAction(title: "OK", style: .default))
//                self.present(alert, animated: true)
//            }
//        }.resume()
//    }
//}
//
//extension PostViewController: ASWebAuthenticationPresentationContextProviding {
//    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
//        view.window!
//    }
//}


//
//  PostViewController.swift
//  Dobbie
//
//  Created by Apple on 27/11/25.
//

import UIKit
import AuthenticationServices

class PostViewController: UIViewController {

    // MARK: - Outlets
    @IBOutlet weak var topicTextField: UITextField!
    @IBOutlet weak var TexTfield: UITextView!

    // MARK: - Properties
    private var webAuthSession: ASWebAuthenticationSession?
    private let network = NetworkManager()

    // MARK: - Life-cycle
    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Actions
    @IBAction func Connect(_ sender: UIButton) {
        // Updated scope and redirect URI
        let authURLString = "https://www.linkedin.com/oauth/v2/authorization?" +
                            "response_type=code" +
                            "&client_id=\(LinkedIn.clientId)" +
                            "&redirect_uri=\(LinkedIn.redirectURI)" +
                            "&scope=\(LinkedIn.scope)" +  // Now includes openid profile
                            "&state=\(LinkedIn.state)"

        guard let authURL = URL(string: authURLString) else { return }

        webAuthSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "dobbie") { [weak self] callback, error in
                guard error == nil,
                      let callback = callback,
                      let query = URLComponents(url: callback, resolvingAgainstBaseURL: false)?.queryItems,
                      let code = query.first(where: { $0.name == "code" })?.value else {
                    print("❌ Auth failed")
                    return
                }
                // Send code to backend instead of exchanging here
                self?.exchangeCodeForToken(code: code)
            }

        webAuthSession?.presentationContextProvider = self
        webAuthSession?.start()
    }

    @IBAction func genertatecontentbutton(_ sender: UIButton) {
        guard let topic = topicTextField.text, !topic.isEmpty else { return }

        sender.isEnabled = false
        let originalTitle = sender.title(for: .normal)
        sender.setTitle("Loading...", for: .normal)

        network.sendTopic(with: topic) { [weak self] responseText in
            DispatchQueue.main.async {
                self?.TexTfield.text = responseText ?? "No content generated"

                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    sender.setTitle(originalTitle, for: .normal)
                    sender.isEnabled = true
                }
            }
        }
    }

    // MARK: - LinkedIn OAuth
    private func exchangeCodeForToken(code: String) {
        // Send code to backend for secure exchange
        let body = [
            "code": code,
            "redirect_uri": LinkedIn.redirectURI
        ]

        var req = URLRequest(url: URL(string: "http://localhost:4000/linkedin/exchange")!)  // Your backend
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, resp, err in
            if let err = err {
                print("❌ Token exchange error:", err)
                DispatchQueue.main.async { self.showAlert(title: "Error", message: "Failed to connect to LinkedIn") }
                return
            }
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            print("🔍 Exchange HTTP status:", status)
            if let body = data, let str = String(data: body, encoding: .utf8) {
                print("🔍 Exchange response body:", str)
            }
            guard let data = data,
                  let response = try? JSONDecoder().decode(LinkedInTokenResponse.self, from: data) else {
                print("❌ Could not decode token response")
                DispatchQueue.main.async { self.showAlert(title: "Error", message: "Failed to get access token") }
                return
            }
            print("✅ Access-token received, member URN:", response.member_urn)
            // Now post directly with the received token and URN
            DispatchQueue.main.async { self.postToLinkedIn(token: response.access_token, authorURN: response.member_urn) }
        }.resume()
    }

    // MARK: - LinkedIn Posting
    private func postToLinkedIn(token: String, authorURN: String) {
        let postText = TexTfield.text ?? "Hello from Dobbie!"

        let ugcPost: [String: Any] = [
            "author": authorURN,
            "lifecycleState": "PUBLISHED",
            "specificContent": [
                "com.linkedin.ugc.ShareContent": [
                    "shareCommentary": ["text": postText],
                    "shareMediaCategory": "NONE"
                ]
            ],
            "visibility": ["com.linkedin.ugc.MemberNetworkVisibility": "PUBLIC"]
        ]

        var req = URLRequest(url: URL(string: "https://api.linkedin.com/v2/ugcPosts")!)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.setValue("2.0.0", forHTTPHeaderField: "X-Restli-Protocol-Version")  // Required header
        req.httpBody = try? JSONSerialization.data(withJSONObject: ugcPost)

        URLSession.shared.dataTask(with: req) { data, resp, _ in
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            print("🔍 Post HTTP status:", status)
            if let body = data, let str = String(data: body, encoding: .utf8) {
                print("🔍 Post response body:", str)
            }
            DispatchQueue.main.async {
                let ok = status == 201
                let alert = UIAlertController(
                    title: ok ? "Posted!" : "Failed",
                    message: ok ? "Successfully posted to LinkedIn" : "Failed to post. Check console for details.",
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
            }
        }.resume()
    }

    private func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

extension PostViewController: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        view.window!
    }
}

// Add this struct for the backend response
struct LinkedInTokenResponse: Decodable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
    let member_id: String
    let member_urn: String
}

//extension PostViewController {
//    func handleLinkedInCallback(code: String) {
//        print("🔄 Handling LinkedIn callback with code")
//        exchangeCodeForToken(code: code)
//    }
//}


extension PostViewController {
    func handleLinkedInCallback(code: String) {
        print("🔄 Handling LinkedIn callback with code")
        exchangeCodeForToken(code: code)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Check for pending LinkedIn code (in case callback happened when VC wasn't visible)
        if let pendingCode = UserDefaults.standard.string(forKey: "pending_linkedin_code") {
            UserDefaults.standard.removeObject(forKey: "pending_linkedin_code")
            print("🔄 Processing pending LinkedIn code")
            exchangeCodeForToken(code: pendingCode)
        }
    }
}
