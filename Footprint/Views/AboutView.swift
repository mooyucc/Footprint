//
//  AboutView.swift
//  Footprint
//
//  Created on 2025/01/27.
//

import SwiftUI
import UIKit

struct AboutView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @Environment(\.dismiss) var dismiss
    
    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    var appDisplayName: String {
        Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String ?? "footprint".localized
    }
    
    var appIcon: UIImage? {
        if let icons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return UIImage(named: lastIcon)
        }
        return UIImage(named: "AppIcon")
    }
    
    var body: some View {
        NavigationStack {
            FootprintHubScaffold(
                accent: Color.footprintRed,
                secondaryAccent: FootprintTheme.Accent.secondary
            ) {
                // 应用图标和名称区域
                VStack(spacing: 16) {
                    Group {
                        if let icon = appIcon {
                            Image(uiImage: icon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        } else {
                            Image(systemName: "app.fill")
                                .font(.system(size: 60))
                                .foregroundStyle(.blue.gradient)
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    Text(appDisplayName)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.primary)
                    
                    Text("version".localized + " \(appVersion)")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 16)
                .padding(.bottom, 8)
                
                FootprintSectionCard {
                    NavigationLink {
                        FeatureIntroductionView()
                            .environmentObject(languageManager)
                    } label: {
                        FootprintNavRow(
                            title: "feature_introduction".localized,
                            systemImage: "sparkles.rectangle.stack",
                            tint: Color.footprintRed
                        )
                    }
                    .buttonStyle(.plain)
                    
                    FootprintRowDivider()
                    
                    Button {
                        AppReviewPromptManager.shared.openWriteReviewPage()
                    } label: {
                        FootprintNavRow(
                            title: "rate_this_app".localized,
                            systemImage: "star.fill",
                            tint: .orange
                        )
                    }
                    .buttonStyle(.plain)
                    
                    FootprintRowDivider()
                    
                    Button {
                        checkForUpdates()
                    } label: {
                        FootprintNavRow(
                            title: "version_update".localized,
                            systemImage: "arrow.down.app",
                            tint: .blue
                        )
                    }
                    .buttonStyle(.plain)
                }
                
                // 法律信息区域
                VStack(spacing: 12) {
                    Button(action: openSoftwareLicense) {
                        Text("software_license_agreement".localized)
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                    }
                    
                    Button(action: openPrivacyPolicy) {
                        Text("privacy_policy".localized)
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                    }
                    
                    Button(action: openWeatherAttribution) {
                        Text("\u{F8FF} Weather")
                            .font(.system(size: 13))
                            .foregroundStyle(.blue)
                    }
                    
                    if languageManager.currentLanguage == .chinese {
                        Button(action: openICPBeian) {
                            Text("ICP备案号：沪ICP备2025134738号-2A")
                                .font(.system(size: 12))
                                .foregroundStyle(.blue)
                        }
                    }
                    
                    VStack(spacing: 4) {
                        if languageManager.currentLanguage == .chinese {
                            Text("Mooyu " + "copyright".localized + " © 2025")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                            Text("all_rights_reserved".localized)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("copyright".localized + " © 2025 Mooyu. " + "all_rights_reserved".localized)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 8)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
            }
            .navigationTitle("about_app".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func checkForUpdates() {
        AppReviewPromptManager.shared.openAppStorePage()
    }
    
    private func openSoftwareLicense() {
        // 打开软件许可协议
        if let url = URL(string: "https://mooyu.cc/moofootprintlicense.html") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openPrivacyPolicy() {
        // 打开隐私保护指引
        if let url = URL(string: "https://mooyu.cc/myfootprintprivacy.html") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openICPBeian() {
        // 打开ICP备案查询
        if let url = URL(string: "https://beian.miit.gov.cn") {
            UIApplication.shared.open(url)
        }
    }
    
    private func openWeatherAttribution() {
        // 打开Apple Weather法律归属链接
        if let url = URL(string: "https://weatherkit.apple.com/legal-attribution.html") {
            UIApplication.shared.open(url)
        }
    }
}

// 功能介绍视图
struct FeatureIntroductionView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("feature_introduction".localized)
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.bottom, 8)
                
                VStack(alignment: .leading, spacing: 16) {
                    FeatureItem(
                        icon: "map.fill",
                        title: "footprint".localized,
                        description: "record_every_journey".localized
                    )
                    
                    FeatureItem(
                        icon: "photo.fill",
                        title: "photo".localized,
                        description: "add_photo".localized
                    )
                    
                    FeatureItem(
                        icon: "icloud.fill",
                        title: "icloud_sync".localized,
                        description: "sync_description_icloud".localized
                    )
                    
                    FeatureItem(
                        icon: "shareplay",
                        title: "share".localized,
                        description: "share_trip".localized
                    )
                }
            }
            .padding()
        }
        .navigationTitle("feature_introduction".localized)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureItem: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

#Preview {
    AboutView()
        .environmentObject(LanguageManager.shared)
}

