//
//  SplashScreen.swift
//  Dobbie
//
//  Apps launch screen with logo animation
//

import SwiftUI

struct SplashScreen: View {
    @Binding var isActive: Bool
    @State private var size = 0.8
    @State private var opacity = 0.5
    
    // LinkedIn Blue
    private let linkedInBlue = Color(red: 0/255, green: 119/255, blue: 181/255)
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            
            VStack {
                VStack(spacing: 20) {
                    // Logo Icon
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(linkedInBlue)
                            .frame(width: 100, height: 100)
                        
                        Text("D")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .shadow(color: linkedInBlue.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    Text("Dobbie")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(Color.primary)
                    
                    Text("Your LinkedIn AI Assistant")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .scaleEffect(size)
                .opacity(opacity)
                .onAppear {
                    withAnimation(.easeIn(duration: 1.2)) {
                        self.size = 1.0
                        self.opacity = 1.0
                    }
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation {
                    self.isActive = true
                }
            }
        }
    }
}

#Preview {
    SplashScreen(isActive: .constant(false))
}
