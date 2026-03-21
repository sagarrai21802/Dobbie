//
//  Secrets.swift
//  Dobbie
//
//  Secure access to API keys from xcconfig/Info.plist
//

import Foundation

enum Secrets {
    
    /// Gemini API Key for content generation
    static var geminiAPIKey: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "GEMINI_API_KEY") as? String,
              !key.isEmpty,
              key != "YOUR_GEMINI_API_KEY_HERE" else {
            fatalError("⚠️ GEMINI_API_KEY not configured. Please set it in Secrets.xcconfig")
        }
        return key
    }
    
    /// LinkedIn Client ID
    static var linkedInClientId: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "LINKEDIN_CLIENT_ID") as? String,
              !key.isEmpty,
              key != "YOUR_LINKEDIN_CLIENT_ID" else {
            fatalError("⚠️ LINKEDIN_CLIENT_ID not configured. Please set it in Secrets.xcconfig")
        }
        return key
    }
    
    /// LinkedIn Client Secret
    static var linkedInClientSecret: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "LINKEDIN_CLIENT_SECRET") as? String,
              !key.isEmpty,
              key != "YOUR_LINKEDIN_CLIENT_SECRET" else {
            fatalError("⚠️ LINKEDIN_CLIENT_SECRET not configured. Please set it in Secrets.xcconfig")
        }
        return key
    }
    
    /// LinkedIn Redirect URI
    static var linkedInRedirectURI: String {
        guard let key = Bundle.main.object(forInfoDictionaryKey: "LINKEDIN_REDIRECT_URI") as? String,
              !key.isEmpty,
              key != "YOUR_REDIRECT_URI" else {
            fatalError("⚠️ LINKEDIN_REDIRECT_URI not configured. Please set it in Secrets.xcconfig")
        }
        return key
    }
}
