//
//  LinkedInToken.swift
//  Dobbie
//
//  LinkedIn OAuth configuration and token models
//

import Foundation

struct LinkedInToken: Decodable {
    let access_token: String
    let expires_in: Int
}

enum LinkedIn {
    static var clientId: String { Secrets.linkedInClientId }
    static var clientSecret: String { Secrets.linkedInClientSecret }
    static var redirectURI: String { Secrets.linkedInRedirectURI }
    static let state = UUID().uuidString
    static let scope = "openid profile w_member_social"
}
