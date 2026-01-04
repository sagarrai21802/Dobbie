//
//  ImageGenerator.swift
//  Dobbie
//
//  Image generation using Gemini Imagen API
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ImageGenerator: ObservableObject {
    
    @Published var generatedImage: UIImage?
    @Published var isGenerating = false
    @Published var errorMessage: String?
    
    // TODO: Replace with your Gemini API key (same as ContentGenerator)
    private let apiKey = "AIzaSyBzQWibhq-YMFSsa20wnOzD9bKJumsvH3Q"
    
    // Gemini image generation endpoint - using Imagen 4 model (Available to your API key)
    private let imagenEndpoint = "https://generativelanguage.googleapis.com/v1beta/models/imagen-4.0-generate-001:predict"
    
    /// Generate an image based on the provided content
    /// Creates a professional LinkedIn-style visual from the content topic
    func generateImage(for content: String) async {
        guard !content.isEmpty else {
            errorMessage = "Please provide content first"
            return
        }
        
        isGenerating = true
        errorMessage = nil
        generatedImage = nil
        
        // Create an optimized prompt for LinkedIn-style professional images
        let imagePrompt = createImagePrompt(from: content)
        
        guard let url = URL(string: "\(imagenEndpoint)?key=\(apiKey)") else {
            errorMessage = "Invalid endpoint URL"
            isGenerating = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Using Imagen 4 API format
        let body: [String: Any] = [
            "instances": [
                ["prompt": imagePrompt]
            ],
            "parameters": [
                "sampleCount": 1,
                "aspectRatio": "1:1"
                // personGeneration parameter removed as it may vary in support for Imagen 4
            ]
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0
            
            // Debug: Print response for troubleshooting
            if let responseString = String(data: data, encoding: .utf8) {
                print("🔍 Imagen Response: \(responseString)")
            }
            
            if statusCode != 200 {
                if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let error = errorJson["error"] as? [String: Any],
                   let message = error["message"] as? String {
                    errorMessage = "Image generation failed: \(message)"
                } else {
                    errorMessage = "Image generation failed (HTTP \(statusCode))"
                }
                isGenerating = false
                return
            }
            
            // Parse the response - looking for bytesBase64Encoded
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let predictions = json["predictions"] as? [[String: Any]],
               let firstPrediction = predictions.first,
               let bytesBase64 = firstPrediction["bytesBase64Encoded"] as? String,
               let imageData = Data(base64Encoded: bytesBase64),
               let image = UIImage(data: imageData) {
                generatedImage = image
            } else {
                errorMessage = "Could not parse image from response"
            }
            
        } catch {
            errorMessage = "Image generation failed: \(error.localizedDescription)"
        }
        
        isGenerating = false
    }
    
    /// Create an optimized prompt for professional LinkedIn-style images
    private func createImagePrompt(from content: String) -> String {
        // Extract key themes from content (first 200 chars for context)
        let truncatedContent = String(content.prefix(200))
        
        let prompt = """
        Create a professional, modern, minimalist illustration for a LinkedIn post about: \(truncatedContent). 
        Style: Clean corporate design, soft gradients, abstract geometric shapes, 
        professional color palette with blues and whites, suitable for business social media. 
        No text or words in the image. High quality, polished, modern aesthetic.
        """
        
        return prompt
    }
    
    /// Get the generated image as Data for uploading
    func getImageData(compressionQuality: CGFloat = 0.8) -> Data? {
        return generatedImage?.jpegData(compressionQuality: compressionQuality)
    }
    
    /// Clear the generated image
    func clearImage() {
        generatedImage = nil
        errorMessage = nil
    }
}
