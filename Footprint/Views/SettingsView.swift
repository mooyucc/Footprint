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
    @Environment(\.dismiss) var dismiss
    @State private var showingEditName = false
    @State private var editingName = ""
    
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
                                    
                                    Label("iCloud 已同步", systemImage: "checkmark.icloud.fill")
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
                                    Text("未登录")
                                        .font(.headline)
                                    
                                    Text("登录后数据自动同步到 iCloud")
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
                    Text("账户")
                }
                
                // iCloud 同步状态
                Section {
                    HStack {
                        Label("iCloud 同步", systemImage: "icloud")
                        Spacer()
                        if appleSignInManager.isSignedIn {
                            Text("已启用")
                                .foregroundColor(.green)
                        } else {
                            Text("未启用")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Label("数据存储", systemImage: "externaldrive.fill.badge.icloud")
                        Spacer()
                        Text(appleSignInManager.isSignedIn ? "iCloud" : "本地")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("数据同步")
                } footer: {
                    if appleSignInManager.isSignedIn {
                        Text("你的旅行数据正在自动同步到 iCloud，可以在所有设备上访问。")
                    } else {
                        Text("登录 Apple ID 后，数据将自动同步到 iCloud，并在你的所有设备间保持同步。")
                    }
                }
                
                // 关于应用
                Section {
                    HStack {
                        Label("版本", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("应用名称", systemImage: "app.badge")
                        Spacer()
                        Text("Footprint")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("关于")
                }
                
                // 退出登录
                if appleSignInManager.isSignedIn {
                    Section {
                        Button(role: .destructive) {
                            appleSignInManager.signOut()
                        } label: {
                            HStack {
                                Spacer()
                                Label("退出登录", systemImage: "rectangle.portrait.and.arrow.right")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
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
                    Text("自定义用户名")
                        .font(.headline)
                    
                    Text("设置一个你喜欢的显示名称")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                TextField("请输入用户名", text: $editedName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isTextFieldFocused)
                    .onAppear {
                        editedName = currentName
                        isTextFieldFocused = true
                    }
                
                Spacer()
            }
            .padding()
            .navigationTitle("编辑用户名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
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
}