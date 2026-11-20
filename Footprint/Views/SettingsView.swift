//
//  SettingsView.swift
//  Footprint
//
//  Created on 2025/10/19.
//

import SwiftUI
import SwiftData
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var userProfileManager: UserProfileManager
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var countryManager: CountryManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @EnvironmentObject private var entitlementManager: EntitlementManager
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showingEditProfile = false
    @State private var showingAboutView = false
    @State private var showingGeneralSettings = false
    @State private var showingDataSettings = false
    @State private var showPaywall = false
    @State private var showAICreditPaywall = false
    
    private var membershipStatusTitle: String {
        let entitlement = entitlementManager.entitlement()
        if entitlement.isPaid {
            return "membership_status_pro_active".localized
        }
        return "membership_status_free".localized
    }
    
    private var membershipStatusSubtitle: String {
        let entitlement = entitlementManager.entitlement()
        guard entitlement.isPaid else {
            return "membership_status_free_hint".localized
        }
        if entitlement == .pro, let expiry = entitlementManager.subscriptionExpiryDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return "membership_status_expiry".localized(with: formatter.string(from: expiry))
        }
        return "membership_status_lifetime_active".localized
    }

    /// 账户行副标题：身份与星座用间隔号连成一行。「不愿透露」不展示。
    private var accountSubtitle: String? {
        let parts = [accountPersonaText, accountConstellationText].compactMap { $0 }
        guard !parts.isEmpty else { return nil }
        return parts.joined(separator: " · ")
    }

    private var accountPersonaText: String? {
        let stored = userProfileManager.personaTag
        guard !stored.isEmpty, stored != "prefer_not_to_say", stored != "不愿透露" else { return nil }
        return UserProfileOptions.personaLocalizedValue(for: stored)
    }

    private var accountConstellationText: String? {
        let stored = userProfileManager.constellation
        guard !stored.isEmpty, stored != "prefer_not_to_say", stored != "不愿透露" else { return nil }
        return UserProfileOptions.constellationLocalizedValue(for: stored)
    }
    
    var body: some View {
        NavigationStack {
            FootprintFormScaffold(
                accent: brandColorManager.currentBrandColor,
                secondaryAccent: FootprintTheme.Accent.secondary
            ) {
            List {
                // 个人资料（本地，无需登录）
                Section {
                    Button {
                        showingEditProfile = true
                    } label: {
                        HStack(spacing: 12) {
                            Group {
                                if let avatarImage = userProfileManager.userAvatarImage {
                                    Image(uiImage: avatarImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .foregroundStyle(.blue.gradient)
                                }
                            }
                            .frame(width: 50, height: 50)
                            .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(userProfileManager.displayName)
                                    .font(.title3.weight(.semibold))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                if let accountSubtitle {
                                    Text(accountSubtitle)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                } header: {
                    Text("account".localized)
                }
                
                // 会员与订阅（从「我的」收敛至此）
                #if !BETA
                Section {
                    HStack {
                        SettingsRowLabel(
                            title: membershipStatusTitle,
                            systemImage: "checkmark.seal.fill",
                            iconColor: brandColorManager.currentBrandColor
                        )
                        Spacer()
                        Text(membershipStatusSubtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    Button {
                        showPaywall = true
                    } label: {
                        HStack {
                            SettingsRowLabel(
                                title: entitlementManager.entitlement().isPaid
                                    ? "membership_status_view_restore".localized
                                    : "paywall_button_upgrade".localized,
                                systemImage: entitlementManager.entitlement().isPaid
                                    ? "arrow.triangle.2.circlepath.circle.fill"
                                    : "sparkles.rectangle.stack",
                                iconColor: brandColorManager.currentBrandColor
                            )
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Button {
                        showAICreditPaywall = true
                    } label: {
                        HStack {
                            SettingsRowLabel(
                                title: "paywall_buy_credits_secondary".localized,
                                systemImage: "sparkles",
                                iconColor: brandColorManager.currentBrandColor
                            )
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("membership_section".localized)
                }
                #endif
                
                // 通用设置入口
                Section {
                    Button {
                        showingGeneralSettings = true
                    } label: {
                        HStack {
                            SettingsRowLabel(title: "general_settings".localized, systemImage: "gearshape", iconColor: brandColorManager.currentBrandColor)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("general_settings".localized)
                }

                // 数据设置入口
                Section {
                    Button {
                        showingDataSettings = true
                    } label: {
                        HStack {
                            SettingsRowLabel(title: "data_settings".localized, systemImage: "internaldrive", iconColor: brandColorManager.currentBrandColor)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("data_settings".localized)
                }

                // 关于应用
                Section {
                    Button {
                        AppReviewPromptManager.shared.openWriteReviewPage()
                    } label: {
                        HStack {
                            SettingsRowLabel(title: "rate_this_app".localized, systemImage: "star.fill", iconColor: brandColorManager.currentBrandColor)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }

                    Button(action: {
                        showingAboutView = true
                    }) {
                        HStack {
                            SettingsRowLabel(title: "about_app".localized, systemImage: "info.circle", iconColor: brandColorManager.currentBrandColor)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("about".localized)
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
            .sheet(isPresented: $showingEditProfile) {
                EditUserProfileView(
                    currentName: userProfileManager.customUserName,
                    currentAvatarData: userProfileManager.userAvatarData,
                    currentPersona: userProfileManager.personaTag,
                    currentConstellation: userProfileManager.constellation,
                    onSave: { newName, imageData, persona, constellation in
                        userProfileManager.setCustomUserName(newName)
                        userProfileManager.setUserAvatar(imageData)
                        userProfileManager.setPersonaTag(persona)
                        userProfileManager.setConstellation(constellation)
                        showingEditProfile = false
                    },
                    onCancel: {
                        showingEditProfile = false
                    }
                )
            }
            .sheet(isPresented: $showingAboutView) {
                AboutView()
                    .environmentObject(languageManager)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
                    .environmentObject(purchaseManager)
                    .environmentObject(entitlementManager)
            }
            .sheet(isPresented: $showAICreditPaywall) {
                AICreditPaywallView()
                    .environmentObject(purchaseManager)
                    .environmentObject(entitlementManager)
            }
            .sheet(isPresented: $showingGeneralSettings) {
                GeneralSettingsView(appearanceManager: AppearanceManager.shared)
                    .environmentObject(languageManager)
                    .environmentObject(countryManager)
                    .environmentObject(brandColorManager)
                    .environmentObject(userProfileManager)
            }
            .sheet(isPresented: $showingDataSettings) {
                DataSettingsView()
                    .environmentObject(userProfileManager)
                    .environmentObject(brandColorManager)
            }
            } // FootprintFormScaffold
        }
    }
}

// 数据设置视图
