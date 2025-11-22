//
//  AppleSignInManager.swift
//  Footprint
//
//  Created on 2025/10/19.
//

import Foundation
import AuthenticationServices
import SwiftUI
import Combine

class AppleSignInManager: NSObject, ObservableObject, ASAuthorizationControllerDelegate {
    @Published var isSignedIn: Bool = false
    @Published var userID: String = ""
    @Published var userName: String = ""
    @Published var userEmail: String = ""
    @Published var customUserName: String = "" // 自定义用户名
    @Published var userAvatarData: Data? = nil // 用户头像数据
    
    static let shared = AppleSignInManager()
    
    override init() {
        super.init()
        checkUserAuthenticationStatus()
    }
    
    // 检查用户认证状态
    func checkUserAuthenticationStatus() {
        if let userID = UserDefaults.standard.string(forKey: "appleUserID") {
            self.userID = userID
            self.userName = UserDefaults.standard.string(forKey: "appleUserName") ?? "Apple ID 用户"
            self.userEmail = UserDefaults.standard.string(forKey: "appleUserEmail") ?? ""
            self.customUserName = UserDefaults.standard.string(forKey: "customUserName") ?? ""
            self.userAvatarData = UserDefaults.standard.data(forKey: "userAvatarData")
            
            // 检查凭证状态
            let provider = ASAuthorizationAppleIDProvider()
            provider.getCredentialState(forUserID: userID) { [weak self] credentialState, error in
                DispatchQueue.main.async {
                    switch credentialState {
                    case .authorized:
                        self?.isSignedIn = true
                    case .revoked, .notFound:
                        self?.isSignedIn = false
                        self?.clearUserData()
                    default:
                        break
                    }
                }
            }
        } else {
            self.isSignedIn = false
        }
    }
    
    // 处理登录成功
    func handleSignInSuccess(authorization: ASAuthorization) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            let userID = appleIDCredential.user
            
            // 保存用户信息
            UserDefaults.standard.set(userID, forKey: "appleUserID")
            
            if let fullName = appleIDCredential.fullName {
                let firstName = fullName.givenName ?? ""
                let lastName = fullName.familyName ?? ""
                let userName = "\(lastName)\(firstName)".trimmingCharacters(in: .whitespacesAndNewlines)
                
                if !userName.isEmpty {
                    UserDefaults.standard.set(userName, forKey: "appleUserName")
                    self.userName = userName
                } else {
                    // 如果没有姓名信息，使用邮箱的前缀部分
                    let email = appleIDCredential.email ?? ""
                    let emailPrefix = email.components(separatedBy: "@").first ?? ""
                    let fallbackName = emailPrefix.isEmpty ? "Apple ID 用户" : emailPrefix
                    UserDefaults.standard.set(fallbackName, forKey: "appleUserName")
                    self.userName = fallbackName
                }
            } else {
                // 如果没有姓名信息，尝试使用邮箱前缀
                let email = appleIDCredential.email ?? ""
                let emailPrefix = email.components(separatedBy: "@").first ?? ""
                let fallbackName = emailPrefix.isEmpty ? "Apple ID 用户" : emailPrefix
                UserDefaults.standard.set(fallbackName, forKey: "appleUserName")
                self.userName = fallbackName
            }
            
            if let email = appleIDCredential.email {
                UserDefaults.standard.set(email, forKey: "appleUserEmail")
                self.userEmail = email
                print("🔍 获取到邮箱: \(email)")
            } else {
                // 如果是已登录用户，从 UserDefaults 获取
                self.userEmail = UserDefaults.standard.string(forKey: "appleUserEmail") ?? ""
                print("🔍 从缓存获取邮箱: \(self.userEmail)")
            }
            
            print("🔍 最终用户名: \(self.userName)")
            print("🔍 最终邮箱: \(self.userEmail)")
            
            self.userID = userID
            self.isSignedIn = true
        }
    }
    
    // 退出登录
    func signOut() {
        clearUserData()
        isSignedIn = false
    }
    
    // 设置自定义用户名
    func setCustomUserName(_ name: String) {
        customUserName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(customUserName, forKey: "customUserName")
    }
    
    // 设置用户头像
    func setUserAvatar(_ imageData: Data?) {
        userAvatarData = imageData
        if let data = imageData {
            UserDefaults.standard.set(data, forKey: "userAvatarData")
        } else {
            UserDefaults.standard.removeObject(forKey: "userAvatarData")
        }
    }
    
    // 获取用户头像图片
    var userAvatarImage: UIImage? {
        guard let data = userAvatarData else { return nil }
        return UIImage(data: data)
    }
    
    // 获取显示用户名（优先使用自定义用户名）
    var displayName: String {
        if !customUserName.isEmpty {
            return customUserName
        } else if !userName.isEmpty {
            return userName
        } else {
            return "Apple ID 用户"
        }
    }
    
    // 清除用户数据
    private func clearUserData() {
        UserDefaults.standard.removeObject(forKey: "appleUserID")
        UserDefaults.standard.removeObject(forKey: "appleUserName")
        UserDefaults.standard.removeObject(forKey: "appleUserEmail")
        UserDefaults.standard.removeObject(forKey: "customUserName")
        UserDefaults.standard.removeObject(forKey: "userAvatarData")
        userID = ""
        userName = ""
        userEmail = ""
        customUserName = ""
        userAvatarData = nil
    }
    
    // MARK: - ASAuthorizationControllerDelegate
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        handleSignInSuccess(authorization: authorization)
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        print("Apple Sign In 失败: \(error.localizedDescription)")
    }
}

// Apple Sign In 按钮视图
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