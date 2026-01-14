//
//  OnboardingView.swift
//  Dobbie
//
//  Onboarding slides to explain app features
//

import SwiftUI

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    
    // LinkedIn Blue
    private let linkedInBlue = Color(red: 0/255, green: 119/255, blue: 181/255)
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                TabView(selection: $currentPage) {
                    OnboardingPage(
                        imageName: "brain.head.profile",
                        title: "Smart Content Generation",
                        description: "Generate professional LinkedIn posts in seconds using advanced AI technology tailored for your audience.",
                        color: linkedInBlue
                    )
                    .tag(0)
                    
                    OnboardingPage(
                        imageName: "slider.horizontal.3",
                        title: "Refine & Polish",
                        description: "Edit generated drafts, add hashtags, and perfect your message before sharing it with your network.",
                        color: Color.purple
                    )
                    .tag(1)
                    
                    OnboardingPage(
                        imageName: "paperplane.fill",
                        title: "Post to LinkedIn",
                        description: "Seamlessly publish your content directly to your LinkedIn profile with a single tap.",
                        color: linkedInBlue
                    )
                    .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
                .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
                
                // Navigation Buttons
                HStack {
                    if currentPage < 2 {
                        Button("Skip") {
                            completeOnboarding()
                        }
                        .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button {
                            withAnimation {
                                currentPage += 1
                            }
                        } label: {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .foregroundColor(linkedInBlue)
                            .fontWeight(.semibold)
                        }
                    } else {
                        Button {
                            completeOnboarding()
                        } label: {
                            Text("Get Started")
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(linkedInBlue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 30)
                    }
                }
                .padding(30)
            }
        }
    }
    
    private func completeOnboarding() {
        withAnimation {
            showOnboarding = false
            // Save state if needed (e.g. UserDefaults)
             UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        }
    }
}

struct OnboardingPage: View {
    let imageName: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(color.opacity(0.1))
                    .frame(width: 200, height: 200)
                
                Image(systemName: imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(color)
            }
            .padding(.bottom, 20)
            
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal, 30)
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(showOnboarding: .constant(true))
}
