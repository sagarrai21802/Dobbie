//
//  RootView.swift
//  Dobbie
//
//  Root orchestrator for the app flow
//

import SwiftUI

struct RootView: View {
    @State private var isSplashActive = true
    @State private var showOnboarding = true
    
    var body: some View {
        ZStack {
            if isSplashActive {
                SplashScreen(isActive: Binding(
                    get: { !isSplashActive },
                    set: { if $0 { isSplashActive = false } }
                ))
                .transition(.opacity)
            } else if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding)
                    .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)))
            } else {
                PostView()
                    .transition(.opacity)
            }
        }
    }
}

#Preview {
    RootView()
}
