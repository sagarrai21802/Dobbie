//
//  PostView.swift
//  Dobbie
//
//  SwiftUI version of PostViewController - LinkedIn Themed
//

import SwiftUI

// MARK: - LinkedIn Theme Colors
struct LinkedInColors {
    static let primaryBlue = Color(hex: "0A66C2")      // LinkedIn brand blue
    static let darkBackground = Color(hex: "1B1F23")   // Dark mode background
    static let secondaryDark = Color(hex: "283340")    // Card backgrounds
    static let lightBlue = Color(hex: "70B5F9")        // Light blue accent
    static let white = Color.white
    static let grayText = Color(hex: "B0B7BF")
    static let successGreen = Color(hex: "057642")
}

struct PostView: View {
    @StateObject private var linkedInManager = LinkedInManager()
    @StateObject private var contentGenerator = ContentGenerator()
    @StateObject private var imageGenerator = ImageGenerator()
    
    @State private var topic: String = ""
    @FocusState private var isTopicFocused: Bool
    
    var body: some View {
        ZStack {
            // LinkedIn Dark Theme Background
            LinearGradient(
                colors: [LinkedInColors.darkBackground, Color(hex: "0D1117")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Topic Input
                    topicInputSection
                    
                    // Generate Content Button
                    generateContentButton
                    
                    // Generated Content
                    if !contentGenerator.generatedContent.isEmpty {
                        contentSection
                        
                        // Generate Image Button
                        generateImageButton
                        
                        // Generated Image Preview
                        if imageGenerator.generatedImage != nil || imageGenerator.isGenerating {
                            imageSection
                        }
                    }
                    
                    // LinkedIn Section
                    linkedInSection
                    
                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
        }
        .alert("Error", isPresented: .init(
            get: { linkedInManager.errorMessage != nil || contentGenerator.errorMessage != nil || imageGenerator.errorMessage != nil },
            set: { if !$0 { linkedInManager.errorMessage = nil; contentGenerator.errorMessage = nil; imageGenerator.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(linkedInManager.errorMessage ?? contentGenerator.errorMessage ?? imageGenerator.errorMessage ?? "Unknown error")
        }
        .overlay {
            if linkedInManager.isLoading || contentGenerator.isGenerating {
                loadingOverlay
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 8) {
            // LinkedIn-style icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [LinkedInColors.primaryBlue, LinkedInColors.lightBlue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 70, height: 70)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            .shadow(color: LinkedInColors.primaryBlue.opacity(0.4), radius: 15, x: 0, y: 8)
            
            Text("Dobbie")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("AI-Powered LinkedIn Content & Images")
                .font(.subheadline)
                .foregroundColor(LinkedInColors.grayText)
        }
        .padding(.top, 20)
    }
    
    // MARK: - Topic Input Section
    private var topicInputSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What would you like to post about?")
                .font(.headline)
                .foregroundColor(.white.opacity(0.9))
            
            TextField("Enter your topic...", text: $topic)
                .focused($isTopicFocused)
                .padding()
                .background(LinkedInColors.secondaryDark)
                .cornerRadius(12)
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LinkedInColors.primaryBlue.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Generate Content Button
    private var generateContentButton: some View {
        Button {
            isTopicFocused = false
            imageGenerator.clearImage()
            Task {
                await contentGenerator.generateContent(for: topic)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "wand.and.stars")
                Text("Generate Content")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [LinkedInColors.primaryBlue, Color(hex: "004182")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
            .shadow(color: LinkedInColors.primaryBlue.opacity(0.4), radius: 15, x: 0, y: 8)
        }
        .disabled(topic.isEmpty || contentGenerator.isGenerating)
        .opacity(topic.isEmpty ? 0.6 : 1.0)
    }
    
    // MARK: - Content Section
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Generated Content")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = contentGenerator.generatedContent
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                            .font(.caption)
                    }
                    .foregroundColor(LinkedInColors.lightBlue)
                }
            }
            
            TextEditor(text: $contentGenerator.generatedContent)
                .frame(minHeight: 180)
                .padding()
                .background(LinkedInColors.secondaryDark)
                .cornerRadius(12)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(LinkedInColors.primaryBlue.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Generate Image Button
    private var generateImageButton: some View {
        Button {
            Task {
                await imageGenerator.generateImage(for: contentGenerator.generatedContent)
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "photo.badge.plus")
                Text(imageGenerator.generatedImage == nil ? "Generate Image" : "Regenerate Image")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(
                    colors: [LinkedInColors.lightBlue, LinkedInColors.primaryBlue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(contentGenerator.generatedContent.isEmpty || imageGenerator.isGenerating)
        .opacity(imageGenerator.isGenerating ? 0.7 : 1.0)
    }
    
    // MARK: - Image Section
    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Generated Image")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                
                Spacer()
                
                if imageGenerator.generatedImage != nil {
                    Button {
                        imageGenerator.clearImage()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle")
                            Text("Remove")
                                .font(.caption)
                        }
                        .foregroundColor(LinkedInColors.grayText)
                    }
                }
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinkedInColors.secondaryDark)
                    .frame(height: 250)
                
                if imageGenerator.isGenerating {
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.3)
                            .tint(LinkedInColors.lightBlue)
                        Text("Generating image...")
                            .font(.subheadline)
                            .foregroundColor(LinkedInColors.grayText)
                    }
                } else if let image = imageGenerator.generatedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .cornerRadius(12)
                        .frame(maxHeight: 250)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(LinkedInColors.primaryBlue.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - LinkedIn Section
    private var linkedInSection: some View {
        VStack(spacing: 16) {
            Rectangle()
                .fill(LinkedInColors.primaryBlue.opacity(0.3))
                .frame(height: 1)
                .padding(.vertical, 8)
            
            if linkedInManager.isAuthenticated {
                // Post to LinkedIn button
                Button {
                    Task {
                        await linkedInManager.postToLinkedIn(
                            content: contentGenerator.generatedContent,
                            imageData: imageGenerator.getImageData()
                        )
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image("LinkedIn_logo_initials")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text(imageGenerator.generatedImage != nil ? "Post with Image to LinkedIn" : "Post to LinkedIn")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinkedInColors.primaryBlue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: LinkedInColors.primaryBlue.opacity(0.4), radius: 10, x: 0, y: 5)
                }
                .disabled(contentGenerator.generatedContent.isEmpty)
                .opacity(contentGenerator.generatedContent.isEmpty ? 0.6 : 1.0)
                
                // Post status
                postStatusView
                
            } else {
                // Connect to LinkedIn button
                Button {
                    linkedInManager.connectToLinkedIn()
                } label: {
                    HStack(spacing: 12) {
                        Image("LinkedIn_logo_initials")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("Connect to LinkedIn")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinkedInColors.primaryBlue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(color: LinkedInColors.primaryBlue.opacity(0.4), radius: 10, x: 0, y: 5)
                }
            }
        }
    }
    
    // MARK: - Post Status View
    @ViewBuilder
    private var postStatusView: some View {
        switch linkedInManager.postStatus {
        case .idle:
            EmptyView()
        case .posting:
            HStack {
                ProgressView()
                    .tint(LinkedInColors.lightBlue)
                Text("Posting to LinkedIn...")
                    .foregroundColor(LinkedInColors.grayText)
            }
            .padding()
            .background(LinkedInColors.secondaryDark)
            .cornerRadius(12)
        case .success:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(LinkedInColors.successGreen)
                Text("Posted successfully!")
                    .foregroundColor(LinkedInColors.successGreen)
            }
            .padding()
            .background(LinkedInColors.successGreen.opacity(0.15))
            .cornerRadius(12)
        case .error(let message):
            HStack {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                Text(message)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Loading Overlay
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(LinkedInColors.lightBlue)
                
                Text(contentGenerator.isGenerating ? "Generating content..." : "Connecting...")
                    .foregroundColor(.white)
                    .fontWeight(.medium)
            }
            .padding(40)
            .background(LinkedInColors.darkBackground)
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(LinkedInColors.primaryBlue.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Preview
#Preview {
    PostView()
}
