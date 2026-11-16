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
    @ObservedObject var appearanceManager: AppearanceManager
    @AppStorage("mapStyle") private var mapStyleRawValue: String = MapStyle.muted.rawValue
    @AppStorage("mapWeatherEnabled") private var mapWeatherEnabled = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var systemColorScheme
    @State private var showingLanguagePicker = false
    @State private var showingCountryPicker = false
    
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
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(brandColorManager.currentBrandColor)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("brand_color".localized)
                                    .font(.headline)
                                
                                if brandColorManager.isUsingCustomColor {
                                    Text("custom_color_active".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text("default_color_active".localized)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            ColorPicker("select_brand_color".localized, selection: Binding(
                                get: {
                                    brandColorManager.currentBrandColor
                                },
                                set: { newColor in
                                    brandColorManager.setCustomBrandColor(newColor)
                                }
                            ), supportsOpacity: false)
                            .labelsHidden()
                        }
                        .padding(.vertical, 8)
                        
                        Button {
                            brandColorManager.resetBrandColorToDefault()
                        } label: {
                            HStack {
                                Image(systemName: "arrow.uturn.backward")
                                Text("reset_to_default_color".localized)
                            }
                            .font(.subheadline)
                            .foregroundColor(brandColorManager.isUsingCustomColor ? .blue : .secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(brandColorManager.isUsingCustomColor ? Color.blue.opacity(0.1) : Color.secondary.opacity(0.05))
                            .cornerRadius(10)
                        }
                        .disabled(!brandColorManager.isUsingCustomColor)
                    }
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
