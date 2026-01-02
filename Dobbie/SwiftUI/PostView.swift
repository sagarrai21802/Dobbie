//
//  PostView.swift
//  Dobbie
//
//  SwiftUI version of PostViewController
//

import SwiftUI

struct PostView: View {
    @StateObject private var linkedInManager = LinkedInManager()
    @StateObject private var contentGenerator = ContentGenerator()
    
    @State private var topic: String = ""
    @FocusState private var isTopicFocused: Bool
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                    
                    // Topic Input
                    topicInputSection
                    
                    // Generate Button
                    generateButton
                    
                    // Generated Content
                    if !contentGenerator.generatedContent.isEmpty {
                        contentSection
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
            get: { linkedInManager.errorMessage != nil || contentGenerator.errorMessage != nil },
            set: { if !$0 { linkedInManager.errorMessage = nil; contentGenerator.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(linkedInManager.errorMessage ?? contentGenerator.errorMessage ?? "Unknown error")
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
            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("Dobbie")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("AI-Powered LinkedIn Content")
                .font(.subheadline)
                .foregroundColor(.gray)
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
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                .foregroundColor(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Generate Button
    private var generateButton: some View {
        Button {
            isTopicFocused = false
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
                    colors: [Color(hex: "667eea"), Color(hex: "764ba2")],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(16)
            .shadow(color: Color(hex: "667eea").opacity(0.4), radius: 20, x: 0, y: 10)
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
                    Image(systemName: "doc.on.doc")
                        .foregroundColor(.gray)
                }
            }
            
            TextEditor(text: $contentGenerator.generatedContent)
                .frame(minHeight: 200)
                .padding()
                .background(Color.white.opacity(0.1))
                .cornerRadius(16)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
    
    // MARK: - LinkedIn Section
    private var linkedInSection: some View {
        VStack(spacing: 16) {
            Divider()
                .background(Color.white.opacity(0.2))
            
            if linkedInManager.isAuthenticated {
                // Post to LinkedIn button
                Button {
                    Task {
                        await linkedInManager.postToLinkedIn(content: contentGenerator.generatedContent)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image("LinkedIn_logo_initials")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 24, height: 24)
                        Text("Post to LinkedIn")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color(hex: "0077B5"))
                    .foregroundColor(.white)
                    .cornerRadius(16)
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
                    .background(Color(hex: "0077B5"))
                    .foregroundColor(.white)
                    .cornerRadius(16)
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
                    .tint(.white)
                Text("Posting...")
                    .foregroundColor(.gray)
            }
        case .success:
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Posted successfully!")
                    .foregroundColor(.green)
            }
            .padding()
            .background(Color.green.opacity(0.1))
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
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(contentGenerator.isGenerating ? "Generating..." : "Connecting...")
                    .foregroundColor(.white)
                    .fontWeight(.medium)
            }
            .padding(40)
            .background(Color(hex: "1a1a2e").opacity(0.9))
            .cornerRadius(20)
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
