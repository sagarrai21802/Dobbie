//
//  PostView.swift
//  Dobbie
//
//  SwiftUI version of PostViewController - Professional LinkedIn Style
//

import SwiftUI

struct PostView: View {
    @StateObject private var linkedInManager = LinkedInManager()
    @StateObject private var contentGenerator = ContentGenerator()
    
    @State private var topic: String = ""
    @FocusState private var isTopicFocused: Bool
    @State private var showCopiedToast = false
    
    // LinkedIn Brand Colors
    private let linkedInBlue = Color(red: 0/255, green: 119/255, blue: 181/255)
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.systemGroupedBackground)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Input Section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Topic")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                                .textCase(.uppercase)
                            
                            TextField("What do you want to talk about?", text: $topic)
                                .padding()
                                .background(Color(UIColor.secondarySystemGroupedBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color(UIColor.separator), lineWidth: 0.5)
                                )
                                .focused($isTopicFocused)
                        }
                        .padding(.horizontal)
                        
                        // Action Button
                        Button {
                            isTopicFocused = false
                            Task {
                                await contentGenerator.generateContent(for: topic)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "pencil.line")
                                Text("Draft Post")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(topic.isEmpty ? Color.gray.opacity(0.3) : linkedInBlue)
                            .foregroundColor(.white)
                            .cornerRadius(25) // Pill shape
                        }
                        .disabled(topic.isEmpty || contentGenerator.isGenerating)
                        .padding(.horizontal)
                        
                        // Output Section
                        if !contentGenerator.generatedContent.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Preview")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                    
                                    Spacer()
                                    
                                    Button {
                                        UIPasteboard.general.string = contentGenerator.generatedContent
                                        withAnimation { showCopiedToast = true }
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                            withAnimation { showCopiedToast = false }
                                        }
                                    } label: {
                                        Label("Copy", systemImage: "doc.on.doc")
                                            .font(.caption)
                                            .foregroundColor(linkedInBlue)
                                    }
                                }
                                
                                TextEditor(text: $contentGenerator.generatedContent)
                                    .frame(minHeight: 200)
                                    .padding(8)
                                    .background(Color(UIColor.secondarySystemGroupedBackground))
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color(UIColor.separator), lineWidth: 0.5)
                                    )
                                
                                // Post Action
                                if linkedInManager.isAuthenticated {
                                    Button {
                                        Task {
                                            await linkedInManager.postToLinkedIn(content: contentGenerator.generatedContent)
                                        }
                                    } label: {
                                        HStack {
                                            if linkedInManager.postStatus == .posting {
                                                ProgressView()
                                                    .tint(.white)
                                                    .scaleEffect(0.8)
                                            } else {
                                                Image(systemName: "paperplane.fill")
                                            }
                                            Text("Post Now")
                                                .fontWeight(.semibold)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(linkedInBlue)
                                        .foregroundColor(.white)
                                        .cornerRadius(25)
                                    }
                                    .padding(.top, 8)
                                    
                                    if case .success = linkedInManager.postStatus {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                            Text("Posted successfully")
                                                .font(.caption)
                                                .foregroundColor(.green)
                                        }
                                        .padding(.top, 4)
                                    } else if case .error(let msg) = linkedInManager.postStatus {
                                        Text(msg)
                                            .font(.caption)
                                            .foregroundColor(.red)
                                            .padding(.top, 4)
                                    }
                                    
                                } else {
                                    Button {
                                        linkedInManager.connectToLinkedIn()
                                    } label: {
                                        HStack {
                                            Image(systemName: "person.crop.circle.badge.plus")
                                            Text("Connect LinkedIn Profile")
                                                .fontWeight(.semibold)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.white)
                                        .foregroundColor(linkedInBlue)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 25)
                                                .stroke(linkedInBlue, lineWidth: 1)
                                        )
                                    }
                                    .padding(.top, 8)
                                }
                            }
                            .padding()
                            .background(Color(UIColor.systemBackground))
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
                            .padding(.horizontal)
                        }
                        
                        Spacer()
                    }
                    .padding(.top)
                }
                
                // Overlay Loading
                if contentGenerator.isGenerating {
                    Color.black.opacity(0.2).ignoresSafeArea()
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Drafting content...")
                            .font(.headline)
                            .padding(.top)
                    }
                    .padding(30)
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .shadow(radius: 10)
                }
                
                // Copied Toast
                if showCopiedToast {
                    VStack {
                        Spacer()
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Copied to clipboard")
                        }
                        .padding()
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(25)
                        .padding(.bottom, 50)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if linkedInManager.isAuthenticated {
                       Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(linkedInBlue)
                    }
                }
            }
        }
        .alert("Message", isPresented: .init(
            get: { linkedInManager.errorMessage != nil || contentGenerator.errorMessage != nil },
            set: { if !$0 { linkedInManager.errorMessage = nil; contentGenerator.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(linkedInManager.errorMessage ?? contentGenerator.errorMessage ?? "")
        }
    }
}

#Preview {
    PostView()
}
