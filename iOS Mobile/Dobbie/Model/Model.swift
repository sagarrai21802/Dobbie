//
//  Model.swift
//  Dobbie
//
//  Created by Apple on 03/12/25.
//

import Foundation

struct APIResponse: Codable {
    let candidates: [Candidate]
    
    struct Candidate: Codable {
        let content: Content
        
        struct Content: Codable {
            let parts: [Part]
            
            struct Part: Codable {
                let text: String
            }
        }
    }
}
