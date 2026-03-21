//
//  Dictionary+FormEncoding.swift
//  Dobbie
//
//  Created by Apple on 05/12/25.
//
import Foundation

extension Dictionary where Key == String, Value == String {
    func percentEncoded() -> Data? {
        map { "\($0)=\($1.addingPercentEncoding(withAllowedCharacters: .urlQueryValueAllowed) ?? "")" }
            .joined(separator: "&")
            .data(using: .utf8)
    }
}

extension CharacterSet {
    static let urlQueryValueAllowed: CharacterSet = {
        let general = CharacterSet.urlQueryAllowed   // ← no NS
        let removed = CharacterSet(charactersIn: "&+=?/")
        return general.subtracting(removed)
    }()
}
