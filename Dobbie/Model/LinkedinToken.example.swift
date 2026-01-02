//
//  LinkedinToken.example.swift
//  Dobbie
//
//  TEMPLATE FILE - Copy this to LinkedinToken.swift and fill in your credentials
//

import Foundation

struct LinkedInToken: Decodable {
    let access_token: String
    let expires_in: Int
}

enum LinkedIn {
    static let clientId     = "YOUR_LINKEDIN_CLIENT_ID"
    static let clientSecret = "YOUR_LINKEDIN_CLIENT_SECRET"
    static let redirectURI  = "http://localhost:4000/linkedin"
    static let state        = UUID().uuidString
    static let scope        = "openid profile w_member_social"
}
