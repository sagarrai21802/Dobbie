//
//  ContentGenerator.swift
//  Dobbie
//
//  Content generation using Gemini API for LinkedIn posts
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ContentGenerator: ObservableObject {
    
    @Published var generatedContent: String = ""
    @Published var isGenerating = false
    @Published var errorMessage: String?
    
    // Gemini API key from secure config
    private var apiKey: String { Secrets.geminiAPIKey }
    
    // Gemini text generation endpoint - using gemini-3-flash-preview
    private let geminiEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-flash-preview:generateContent"
    
    /// Generate LinkedIn content based on the provided topic
    func generateContent(for topic: String) async {
        guard !topic.isEmpty else {
            errorMessage = "Please enter a topic"
            return
        }
        
        isGenerating = true
        errorMessage = nil
        generatedContent = ""
        
        guard let url = URL(string: geminiEndpoint) else {
            errorMessage = "Invalid endpoint URL"
            isGenerating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        
        let prompt = """
        You are a professional LinkedIn content strategist. Write a compelling LinkedIn post about: \(topic)
        
        STRICT REQUIREMENTS:
        1. LENGTH: 150-250 words (optimal for LinkedIn engagement)
        2. STRUCTURE:
           - Start with a powerful hook (question, bold statement, or surprising fact)
           - Use short paragraphs (1-2 sentences each)
           - Include white space for readability
           - End with a clear call-to-action asking for engagement
        
        3. TONE: Professional yet conversational, authentic, and relatable
        
        4. FORMAT:
           - Use 2-4 relevant emojis strategically (not excessive)
           - Add line breaks between paragraphs
           - Include 3-5 relevant hashtags at the END only
        
        5. ENGAGEMENT TACTICS:
           - Share a personal insight or lesson learned
           - Include a actionable takeaway for readers
           - Ask a thought-provoking question at the end
        
        6. AVOID:
           - Generic corporate jargon
           - Overly salesy language
           - Too many hashtags or emojis
           - Starting with "I'm excited to announce..."
        
        OUTPUT: Generate ONLY the post content ready to copy-paste. No explanations, no meta text, no quotes around it.
        """
        
        let body: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": prompt]
                    ]
                ]
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            
            // Debug: Print response for troubleshooting
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔍 Gemini Response: \(responseString)")
            }
            
            if statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    errorMessage = "Content generation failed: \(message)"
                } else {
                    errorMessage = "Content generation failed (HTTP \(statusCode))"
                }
                isGenerating = false
                return
            }
            
            // Parse the response
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let candidates = json["candidates"] as? [[String: Any]],
               let firstCandidate = candidates.first,
               let content = firstCandidate["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let firstPart = parts.first,
               let text = firstPart["text"] as? String {
                generatedContent = text.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                errorMessage = "Could not parse content from response"
            }
            
        } catch {
            errorMessage = "Content generation failed: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
    
    /// Clear the generated content
    func clearContent() {
        generatedContent = ""
        errorMessage = nil
    }
}
