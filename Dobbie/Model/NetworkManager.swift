//
//  NetworkManager.swift
//  Dobbie
//
//  Created by Apple on 03/12/25.
//
import Foundation

class NetworkManager {
    
    let apiKey = "AIzaSyAUsAqfNq3WA6k6_TKggaPUiD7-SceMGbM"
    let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    
    func sendTopic(with topic: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: endpoint) else {
            completion(nil)
            return
        }
 
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": topic + "The generated content will not have any stuff that is not the expected response means no here is the answer , here is the resule and will not contain any hyphens or any other content that shows it is ai genertaed , only and only the written content and also it should soound like human not ai written so write it in a way that shows human opinion"]]]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            print("Failed to serialize JSON: \(error)")
            completion(nil)
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print("API call error: \(error?.localizedDescription ?? "Unknown error")")
                completion(nil)
                return
            }
            
            do {
                let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
                let text = apiResponse.candidates.first?.content.parts.first?.text
                completion(text)
            } catch {
                print("Decoding error: \(error)")
                completion(nil)
            }
        }.resume()
    }
}
