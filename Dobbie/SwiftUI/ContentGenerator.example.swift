//
//  ContentGenerator.example.swift
//  Dobbie
//
//  TEMPLATE FILE - Copy this to ContentGenerator.swift and fill in your API key
//

import Foundation
import Combine

@MainActor
class ContentGenerator: ObservableObject {
    
    @Published var generatedContent: String = ""
    @Published var isGenerating = false
    @Published var errorMessage: String?
    
    private let apiKey = "YOUR_GEMINI_API_KEY"
    private let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"
    
    func generateContent(for topic: String) async {
        guard !topic.isEmpty else {
            errorMessage = "Please enter a topic"
            return
        }
        
        isGenerating = true
        errorMessage = nil
        
        guard let url = URL(string: endpoint) else {
            errorMessage = "Invalid endpoint URL"
            isGenerating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        let prompt = topic + " The generated content will not have any stuff that is not the expected response"
        
        let body: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let apiResponse = try JSONDecoder().decode(APIResponse.self, from: data)
            
            if let text = apiResponse.candidates.first?.content.parts.first?.text {
                generatedContent = text
            } else {
                errorMessage = "No content generated"
            }
        } catch {
            errorMessage = "Generation failed: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
    
    func clearContent() {
        generatedContent = ""
        errorMessage = nil
    }
}
