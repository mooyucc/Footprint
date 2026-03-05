//
//  AppleSignInButton.swift
//  Footprint
//
//  Created on 2026/01/26.
//  Apple Sign In 按钮视图，从 AppleSignInManager.swift 提取
//

import SwiftUI
import AuthenticationServices

/// Apple Sign In 按钮视图
struct AppleSignInButton: View {
    @ObservedObject var signInManager: AppleSignInManager
    @EnvironmentObject private var languageManager: LanguageManager
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: {
            performAppleSignIn()
        }) {
            HStack {
                Image(systemName: "applelogo")
                    .font(.system(size: 16, weight: .medium))
                Text(languageManager.localizedString(for: "sign_in_with_apple"))
                    .font(.system(size: 16, weight: .medium))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.black)
            .cornerRadius(8)
        }
    }
    
    private func performAppleSignIn() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        
        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = signInManager
        authorizationController.performRequests()
    }
}
