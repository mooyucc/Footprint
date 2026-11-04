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
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(userProfileManager.displayName)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack(spacing: 6) {
                                        if !userProfileManager.personaTag.isEmpty {
                                            Label(
                                                UserProfileOptions.personaLocalizedValue(for: userProfileManager.personaTag),
                                                systemImage: "person.crop.circle.badge.questionmark"
                                            )
                                            .font(.caption2)
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .footprintCapsuleChrome()
                                        }
                                        
                                        if !userProfileManager.mbtiType.isEmpty {
                                            Label(userProfileManager.mbtiType, systemImage: "brain.head.profile")
                                                .font(.caption2)
                                                .foregroundColor(.primary)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .footprintCapsuleChrome()
                                        }
                                    }
                                    
                                    if !userProfileManager.constellation.isEmpty {
                                        HStack(spacing: 6) {
                                            Label(
                                                UserProfileOptions.constellationLocalizedValue(for: userProfileManager.constellation),
                                                systemImage: "sparkles"
                                            )
                                            .font(.caption2)
                                            .foregroundColor(.primary)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .footprintCapsuleChrome()
                                        }
                                    }
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
                    currentMbti: userProfileManager.mbtiType,
                    currentGender: userProfileManager.gender,
                    currentAgeGroup: userProfileManager.ageGroup,
                    currentConstellation: userProfileManager.constellation,
                    onSave: { newName, imageData, persona, mbti, gender, ageGroup, constellation in
                        userProfileManager.setCustomUserName(newName)
                        userProfileManager.setUserAvatar(imageData)
                        userProfileManager.setPersonaTag(persona)
                        userProfileManager.setMbtiType(mbti)
                        userProfileManager.setGender(gender)
                        userProfileManager.setAgeGroup(ageGroup)
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
