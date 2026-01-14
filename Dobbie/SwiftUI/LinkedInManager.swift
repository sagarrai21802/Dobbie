//
//  LinkedInManager.swift
//  Dobbie
//
//  SwiftUI-compatible LinkedIn OAuth Manager with token persistence
//

import Foundation
import AuthenticationServices
import Combine
import Security

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
    
    enum LinkedInError: LocalizedError {
        case uploadRegistrationFailed
        case imageUploadFailed
        case invalidResponse
        case postFailed
        
        var errorDescription: String? {
            switch self {
            case .uploadRegistrationFailed:
                return "Failed to register image upload with LinkedIn"
            case .imageUploadFailed:
                return "Failed to upload image to LinkedIn"
            case .invalidResponse:
                return "Invalid response from LinkedIn"
            case .postFailed:
                return "Failed to create LinkedIn post"
            }
        }
    }
    
    // MARK: - Private Properties
    private var webAuthSession: ASWebAuthenticationSession?
    private var accessToken: String?
    private var memberUrn: String?
    
    // Keychain keys
    private let tokenKey = "com.dobbie.linkedin.accessToken"
    private let urnKey = "com.dobbie.linkedin.memberUrn"
    
    // MARK: - Initialization
    override init() {
        super.init()
        loadSavedCredentials()
    }
    
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
    
    /// Disconnect from LinkedIn (clear saved credentials)
    func disconnect() {
        accessToken = nil
        memberUrn = nil
        isAuthenticated = false
        deleteFromKeychain(key: tokenKey)
        deleteFromKeychain(key: urnKey)
        print("✅ Disconnected from LinkedIn")
    }
    
    /// Post content to LinkedIn (with optional image)
    func postToLinkedIn(content: String, imageData: Data? = nil) async {
        guard let token = accessToken, let urn = memberUrn else {
            postStatus = .error("Not authenticated")
            return
        }
        
        postStatus = .posting
        
        do {
            var mediaAsset: String? = nil
            
            // If we have an image, upload it first
            if let imageData = imageData {
                mediaAsset = try await uploadImageToLinkedIn(token: token, authorUrn: urn, imageData: imageData)
            }
            
            // Create the post
            try await createLinkedInPost(token: token, authorUrn: urn, content: content, mediaAsset: mediaAsset)
            postStatus = .success
            
        } catch {
            postStatus = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Keychain Helpers
    
    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        
        // Delete existing item first
        deleteFromKeychain(key: key)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            print("✅ Saved to Keychain: \(key)")
        } else {
            print("❌ Failed to save to Keychain: \(status)")
        }
    }
    
    private func loadFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    private func deleteFromKeychain(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    private func loadSavedCredentials() {
        if let savedToken = loadFromKeychain(key: tokenKey),
           let savedUrn = loadFromKeychain(key: urnKey) {
            accessToken = savedToken
            memberUrn = savedUrn
            isAuthenticated = true
            print("✅ Loaded saved LinkedIn credentials")
        }
    }
    
    private func saveCredentials() {
        guard let token = accessToken, let urn = memberUrn else { return }
        saveToKeychain(key: tokenKey, value: token)
        saveToKeychain(key: urnKey, value: urn)
    }
    
    // MARK: - Image Upload
    
    /// Upload image to LinkedIn and return the asset URN
    private func uploadImageToLinkedIn(token: String, authorUrn: String, imageData: Data) async throws -> String {
        // Step 1: Register the upload
        let registerRequest = try await registerImageUpload(token: token, authorUrn: authorUrn)
        
        // Step 2: Upload the image binary
        try await uploadImageBinary(uploadUrl: registerRequest.uploadUrl, imageData: imageData)
        
        // Return the asset URN for use in the post
        return registerRequest.asset
    }
    
    /// Register an image upload with LinkedIn
    private func registerImageUpload(token: String, authorUrn: String) async throws -> (uploadUrl: String, asset: String) {
        let registerBody: [String: Any] = [
            "registerUploadRequest": [
                "recipes": ["urn:li:digitalmediaRecipe:feedshare-image"],
                "owner": authorUrn,
                "serviceRelationships": [
                    [
                        "relationshipType": "OWNER",
                        "identifier": "urn:li:userGeneratedContent"
                    ]
                ]
            ]
        ]
        
        var request = URLRequest(url: URL(string: "https://api.linkedin.com/v2/assets?action=registerUpload")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2.0.0", forHTTPHeaderField: "X-Restli-Protocol-Version")
        request.httpBody = try JSONSerialization.data(withJSONObject: registerBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        guard status == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            print("❌ Register upload failed: HTTP \(status) - \(errorMsg)")
            throw LinkedInError.uploadRegistrationFailed
        }
        
        // Parse the response to get upload URL and asset
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = json["value"] as? [String: Any],
              let uploadMechanism = value["uploadMechanism"] as? [String: Any],
              let mediaUpload = uploadMechanism["com.linkedin.digitalmedia.uploading.MediaUploadHttpRequest"] as? [String: Any],
              let uploadUrl = mediaUpload["uploadUrl"] as? String,
              let asset = value["asset"] as? String else {
            throw LinkedInError.invalidResponse
        }
        
        print("✅ Got upload URL and asset: \(asset)")
        return (uploadUrl, asset)
    }
    
    /// Upload the actual image binary data
    private func uploadImageBinary(uploadUrl: String, imageData: Data) async throws {
        var request = URLRequest(url: URL(string: uploadUrl)!)
        request.httpMethod = "PUT"
        request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        guard status == 201 || status == 200 else {
            print("❌ Image upload failed: HTTP \(status)")
            throw LinkedInError.imageUploadFailed
        }
        
        print("✅ Image uploaded successfully")
    }
    
    /// Create the LinkedIn post (with or without media)
    private func createLinkedInPost(token: String, authorUrn: String, content: String, mediaAsset: String?) async throws {
        var ugcPost: [String: Any]
        
        if let asset = mediaAsset {
            // Post with image
            ugcPost = [
                "author": authorUrn,
                "lifecycleState": "PUBLISHED",
                "specificContent": [
                    "com.linkedin.ugc.ShareContent": [
                        "shareCommentary": ["text": content],
                        "shareMediaCategory": "IMAGE",
                        "media": [
                            [
                                "status": "READY",
                                "media": asset
                            ]
                        ]
                    ]
                ],
                "visibility": ["com.linkedin.ugc.MemberNetworkVisibility": "PUBLIC"]
            ]
        } else {
            // Text-only post
            ugcPost = [
                "author": authorUrn,
                "lifecycleState": "PUBLISHED",
                "specificContent": [
                    "com.linkedin.ugc.ShareContent": [
                        "shareCommentary": ["text": content],
                        "shareMediaCategory": "NONE"
                    ]
                ],
                "visibility": ["com.linkedin.ugc.MemberNetworkVisibility": "PUBLIC"]
            ]
        }
        
        var request = URLRequest(url: URL(string: "https://api.linkedin.com/v2/ugcPosts")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("2.0.0", forHTTPHeaderField: "X-Restli-Protocol-Version")
        request.httpBody = try? JSONSerialization.data(withJSONObject: ugcPost)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        
        if let body = data as Data?, let str = String(data: body, encoding: .utf8) {
            print("🔍 Post response: \(str)")
        }
        
        guard status == 201 else {
            print("❌ Post failed: HTTP \(status)")
            throw LinkedInError.postFailed
        }
        
        print("✅ Posted to LinkedIn successfully")
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
            
            // Save credentials to Keychain for persistence
            saveCredentials()
            
            print("✅ Access token received and saved, member URN: \(response.member_urn)")
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
