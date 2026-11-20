//
//  GeneralSettingsView.swift
//  Footprint
//
//  从 SettingsView.swift 提取（编译拆分）
//

import SwiftUI
import SwiftData
import StoreKit
import UniformTypeIdentifiers

struct GeneralSettingsView: View {
    @EnvironmentObject var languageManager: LanguageManager
    @EnvironmentObject var countryManager: CountryManager
    @EnvironmentObject var brandColorManager: BrandColorManager
    @EnvironmentObject var userProfileManager: UserProfileManager
    @ObservedObject var appearanceManager: AppearanceManager
    @AppStorage("mapStyle") private var mapStyleRawValue: String = MapStyle.muted.rawValue
    @AppStorage("mapWeatherEnabled") private var mapWeatherEnabled = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showingLanguagePicker = false
    @State private var showingCountryPicker = false
    @State private var themeApplyCount = 0
    
    var body: some View {
        NavigationStack {
            FootprintFormScaffold(
                accent: brandColorManager.currentBrandColor,
                secondaryAccent: FootprintTheme.Accent.secondary
            ) {
            List {
                // 语言设置
                Section {
                    Button {
                        showingLanguagePicker = true
                    } label: {
                        HStack {
                            SettingsRowLabel(title: "language".localized, systemImage: "globe", iconColor: brandColorManager.currentBrandColor)
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
                    Button {
                        showingCountryPicker = true
                    } label: {
                        HStack {
                            SettingsRowLabel(title: "country".localized, systemImage: "flag", iconColor: brandColorManager.currentBrandColor)
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
                
                // 外观模式设置
                Section {
                    Picker("appearance_mode".localized, selection: Binding(
                        get: { appearanceManager.currentMode },
                        set: { newMode in
                            appearanceManager.setAppearanceMode(newMode)
                        }
                    )) {
                        ForEach(AppearanceManager.AppearanceMode.allCases, id: \.self) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("appearance_mode".localized)
                } footer: {
                    Text("appearance_mode_description".localized)
                }
                
                // 品牌颜色设置（外观）
                Section {
                    appearanceColorSection
                } header: {
                    Text("appearance".localized)
                } footer: {
                    Text("brand_color_description".localized)
                }
                
                // 地图样式
                Section {
                    Toggle(isOn: $mapWeatherEnabled) {
                        SettingsRowLabel(
                            title: "map_weather_display".localized,
                            systemImage: "cloud.sun.fill",
                            iconColor: brandColorManager.currentBrandColor
                        )
                    }
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                        ForEach(MapStyle.allCases, id: \.self) { style in
                            MapStyleCard(
                                style: style,
                                isSelected: currentMapStyle == style
                            ) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    mapStyleRawValue = style.rawValue
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("map_style_title".localized)
                } footer: {
                    Text("map_weather_display_description".localized)
                }
            }
            .navigationTitle("general_settings".localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done".localized) {
                        dismiss()
                    }
                }
            }
            } // FootprintFormScaffold
        }
        .sheet(isPresented: $showingLanguagePicker) {
            LanguageSelectionView()
        }
        .sheet(isPresented: $showingCountryPicker) {
            CountrySelectionView()
        }
    }
    
    private var currentMapStyle: MapStyle {
        MapStyle(rawValue: mapStyleRawValue) ?? .muted
    }

    private var themeSuggestions: [ProfileThemeSuggestion] {
        ProfileThemePalette.suggestions(
            personaKey: userProfileManager.personaTag,
            constellationKey: userProfileManager.constellation
        )
        .filter { suggestion in
            !ProfileThemePalette.matches(suggestion.color, brand: brandColorManager.defaultBrandColor)
        }
    }

    private var isDefaultTheme: Bool {
        ProfileThemePalette.matches(
            brandColorManager.defaultBrandColor,
            brand: brandColorManager.currentBrandColor
        )
    }

    private var isCustomTheme: Bool {
        guard !isDefaultTheme else { return false }
        return !themeSuggestions.contains { suggestion in
            ProfileThemePalette.matches(suggestion.color, brand: brandColorManager.currentBrandColor)
        }
    }

    private var appearanceColorSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            themeChoiceRow(
                color: brandColorManager.defaultBrandColor,
                source: "theme_source_default".localized,
                name: "theme_default_name".localized,
                isCurrent: isDefaultTheme
            ) {
                brandColorManager.resetBrandColorToDefault()
            }

            ForEach(themeSuggestions) { suggestion in
                themeChoiceRow(
                    color: suggestion.color,
                    source: suggestion.sourceTitle,
                    name: suggestion.attributeName,
                    isCurrent: ProfileThemePalette.matches(
                        suggestion.color,
                        brand: brandColorManager.currentBrandColor
                    )
                ) {
                    brandColorManager.setCustomBrandColor(suggestion.color)
                }
            }

            customColorRow
        }
        .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: themeApplyCount)
    }

    private func themeChoiceRow(
        color: Color,
        source: String,
        name: String,
        isCurrent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            themeApplyCount += 1
        } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(color)
                    .frame(width: 44, height: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(source)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(name)
                        .font(.body.weight(.semibold))
                        .foregroundColor(.primary)
                }
                Spacer(minLength: 8)
                Text(isCurrent ? "theme_color_in_use".localized : "onboarding_theme_color_use".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(isCurrent ? .secondary : .white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(isCurrent ? Color.primary.opacity(0.08) : color))
            }
            .frame(minHeight: 44)
        }
        .buttonStyle(.borderless)
        .disabled(isCurrent)
        .accessibilityLabel("\(source) \(name)")
    }

    private var customColorRow: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isCustomTheme ? brandColorManager.currentBrandColor : Color.primary.opacity(0.06))
                .overlay {
                    if !isCustomTheme {
                        Image(systemName: "paintpalette")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text("theme_source_custom".localized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("onboarding_theme_color_pick".localized)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.primary)
            }

            Spacer(minLength: 8)

            if isCustomTheme {
                Text("theme_color_in_use".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
            }

            ColorPicker(
                "select_brand_color".localized,
                selection: Binding(
                    get: { brandColorManager.currentBrandColor },
                    set: { newColor in
                        brandColorManager.setCustomBrandColor(newColor)
                    }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
        }
        .frame(minHeight: 44)
    }
}

// 通用设置行标签，确保文本使用系统主色而图标保留品牌色

struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    let iconColor: Color
    
    var body: some View {
        Label {
            Text(title)
                .foregroundColor(.primary)
        } icon: {
            Image(systemName: systemImage)
                .symbolRenderingMode(.monochrome)
                .foregroundColor(iconColor)
        }
    }
}


// 编辑用户档案视图（头像 + 用户名 + 人设标签）
