//
//  SettingsView.swift
//  Footprint
//
//  Created on 2025/10/19.
//

import SwiftUI
import AuthenticationServices

struct SettingsView: View {
    @EnvironmentObject var appleSignInManager: AppleSignInManager
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var countryManager: CountryManager
    @Environment(\.dismiss) var dismiss
    @State private var showingEditName = false
    @State private var editingName = ""
    @State private var showingLanguagePicker = false
    @State private var showingCountryPicker = false
    
    var body: some View {
        NavigationStack {
            List {
                // 账户信息
                Section {
                    if appleSignInManager.isSignedIn {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.blue.gradient)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(appleSignInManager.displayName)
                                            .font(.headline)
                                        
                                        Button(action: {
                                            editingName = appleSignInManager.customUserName
                                            showingEditName = true
                                        }) {
                                            Image(systemName: "pencil.circle")
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    
                                    if !appleSignInManager.userEmail.isEmpty {
                                        Text(appleSignInManager.userEmail)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Label("iCloud_synced".localized, systemImage: "checkmark.icloud.fill")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "person.circle")
                                    .font(.system(size: 50))
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("not_logged_in".localized)
                                        .font(.headline)
                                    
                                    Text("login_sync_description".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            
                            AppleSignInButton(signInManager: appleSignInManager)
                                .frame(height: 50)
                        }
                    }
                } header: {
                    Text("account".localized)
                }
                
                // iCloud 同步状态
                Section {
                    HStack {
                        Label("icloud_sync".localized, systemImage: "icloud")
                        Spacer()
                        if appleSignInManager.isSignedIn {
                            Text("enabled".localized)
                                .foregroundColor(.green)
                        } else {
                            Text("not_enabled".localized)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Label("data_storage".localized, systemImage: "externaldrive.fill.badge.icloud")
                        Spacer()
                        Text(appleSignInManager.isSignedIn ? "icloud".localized : "local".localized)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("data_sync".localized)
                } footer: {
                    if appleSignInManager.isSignedIn {
                        Text("sync_description_logged_in".localized)
                    } else {
                        Text("sync_description_not_logged_in".localized)
                    }
                }
                
                // 语言设置
                Section {
                    Button(action: {
                        showingLanguagePicker = true
                    }) {
                        HStack {
                            Label("language".localized, systemImage: "globe")
                            Spacer()
                            HStack {
                                Text(languageManager.currentLanguage.flag)
                                Text(languageManager.currentLanguage.displayName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("language".localized)
                }
                
                // 国家设置
                Section {
                    Button(action: {
                        showingCountryPicker = true
                    }) {
                        HStack {
                            Label("country".localized, systemImage: "flag")
                            Spacer()
                            HStack {
                                Text(countryManager.currentCountry.flag)
                                Text(countryManager.currentCountryLocalizedName)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("country".localized)
                } footer: {
                    Text("country_description".localized)
                }
                
                // 关于应用
                Section {
                    HStack {
                        Label("version".localized, systemImage: "info.circle")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("app_name".localized, systemImage: "app.badge")
                        Spacer()
                        Text("footprint".localized)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("about".localized)
                }
                
                // 退出登录
                if appleSignInManager.isSignedIn {
                    Section {
                        Button(role: .destructive) {
                            appleSignInManager.signOut()
                        } label: {
                            HStack {
                                Spacer()
                                Label("sign_out".localized, systemImage: "rectangle.portrait.and.arrow.right")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingEditName) {
                EditUserNameView(
                    currentName: $editingName,
                    onSave: { newName in
                        appleSignInManager.setCustomUserName(newName)
                        showingEditName = false
                    },
                    onCancel: {
                        showingEditName = false
                    }
                )
            }
            .sheet(isPresented: $showingLanguagePicker) {
                LanguageSelectionView()
            }
            .sheet(isPresented: $showingCountryPicker) {
                CountrySelectionView()
            }
        }
    }
}

// 编辑用户名视图
struct EditUserNameView: View {
    @Binding var currentName: String
    let onSave: (String) -> Void
    let onCancel: () -> Void
    
    @State private var editedName: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("custom_username".localized)
                        .font(.headline)
                    
                    Text("username_description".localized)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("enter_username".localized, text: $editedName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .onAppear {
                        editedName = currentName
                        isTextFieldFocused = true
                    }
                
                Spacer()
            }
            .padding()
            .navigationTitle("edit_username".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("cancel".localized) {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("save".localized) {
                        onSave(editedName)
                    }
                    .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppleSignInManager.shared)
        .environmentObject(LanguageManager.shared)
        .environmentObject(CountryManager.shared)
}