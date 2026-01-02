//
//  LinkedInManager.swift
//  Dobbie
//
//  SwiftUI-compatible LinkedIn OAuth Manager
//

import Foundation
import AuthenticationServices
import Combine

@MainActor
class LinkedInManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var postStatus: PostStatus = .idle
    
    enum PostStatus: Equatable {
        case idle
        case posting
        case success
        case error(String)
    }
    
    // MARK: - Private Properties
    private var webAuthSession: ASWebAuthenticationSession?
    private var accessToken: String?
    private var memberUrn: String?
    
    // MARK: - Public Methods
    
    /// Start LinkedIn OAuth flow
    func connectToLinkedIn() {
        isLoading = true
        errorMessage = nil
        
        let authURLString = "https://www.linkedin.com/oauth/v2/authorization?" +
            "response_type=code" +
            "&client_id=\(LinkedIn.clientId)" +
            "&redirect_uri=\(LinkedIn.redirectURI)" +
            "&scope=\(LinkedIn.scope)" +
            "&state=\(LinkedIn.state)"
        
        guard let authURL = URL(string: authURLString) else {
            errorMessage = "Invalid auth URL"
            isLoading = false
            return
        }
        
        webAuthSession = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "dobbie"
        ) { [weak self] callbackURL, error in
            Task { @MainActor in
                self?.handleAuthCallback(callbackURL: callbackURL, error: error)
            }
        }
        
        webAuthSession?.presentationContextProvider = self
        webAuthSession?.prefersEphemeralWebBrowserSession = false
        webAuthSession?.start()
    }
    
    /// Post content to LinkedIn
    func postToLinkedIn(content: String) async {
        guard let token = accessToken, let urn = memberUrn else {
            postStatus = .error("Not authenticated")
            return
        }
        
        postStatus = .posting
        
        let ugcPost: [String: Any] = [
            "author": urn,
            "lifecycleState": "PUBLISHED",
            "specificContent": [
                "com.linkedin.ugc.ShareContent": [
                    "shareCommentary": ["text": content],
                    "shareMediaCategory": "NONE"
                ]
            ],
            "visibility": ["com.linkedin.ugc.MemberNetworkVisibility": "PUBLIC"]
        ]
        
        var request = URLRequest(url: URL(string: "https://api.linkedin.com/v2/ugcPosts")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2.0.0", forHTTPHeaderField: "X-Restli-Protocol-Version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ugcPost)
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            
            if status == 201 {
                postStatus = .success
            } else {
                postStatus = .error("Failed to post (HTTP \(status))")
            }
        } catch {
            postStatus = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Private Methods
    
    private func handleAuthCallback(callbackURL: URL?, error: Error?) {
        isLoading = false
        
        if let error = error {
            errorMessage = "Auth failed: \(error.localizedDescription)"
            print("❌ Auth failed: \(error)")
            return
        }
        
        guard let callbackURL = callbackURL,
              let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
            errorMessage = "No authorization code received"
            print("❌ No authorization code in callback")
            return
        }
        
        print("✅ Received LinkedIn auth code")
        Task {
            await exchangeCodeForToken(code: code)
        }
    }
    
    private func exchangeCodeForToken(code: String) async {
        isLoading = true
        
        let body: [String: String] = [
            "code": code,
            "redirect_uri": LinkedIn.redirectURI
        ]
        
        var request = URLRequest(url: URL(string: "http://localhost:4000/linkedin/exchange")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        
        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(LinkedInTokenResponse.self, from: data)
            
            accessToken = response.access_token
            memberUrn = response.member_urn
            isAuthenticated = true
            isLoading = false
            
            print("✅ Access token received, member URN: \(response.member_urn)")
        } catch {
            errorMessage = "Token exchange failed: \(error.localizedDescription)"
            isLoading = false
            print("❌ Token exchange failed: \(error)")
        }
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding
extension LinkedInManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}

// LinkedInTokenResponse is defined in PostViewController.swift
// No need to redeclare it here
