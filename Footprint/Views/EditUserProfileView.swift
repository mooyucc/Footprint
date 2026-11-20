//
//  EditUserProfileView.swift
//  Footprint
//
//  从 SettingsView.swift 提取（编译拆分）
//

import SwiftUI
import SwiftData
import StoreKit
import UniformTypeIdentifiers
import PhotosUI
import UIKit

struct EditUserProfileView: View {
    let currentName: String
    let currentAvatarData: Data?
    let currentPersona: String
    let currentConstellation: String
    let onSave: (String, Data?, String, String) -> Void
    let onCancel: () -> Void
    
    @EnvironmentObject private var brandColorManager: BrandColorManager
    
    @State private var editedName: String
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var shouldRemoveAvatar = false
    @State private var showingDeleteConfirm = false
    @State private var showingPhotoPicker = false
    @State private var selectedPersonaOption: String
    @State private var customPersona: String
    @State private var selectedConstellation: String
    @State private var themeApplyCount = 0
    @FocusState private var isTextFieldFocused: Bool
    
    private var personaOptions: [String] {
        UserProfileOptions.localizedPersonaOptions()
    }
    
    private var constellationOptions: [String] {
        UserProfileOptions.localizedConstellationOptions()
    }
    
    @State private var storedPersonaKey: String = ""
    @State private var storedConstellationKey: String = ""
    
    private var personaKeyForTheme: String {
        let customOptionLocalized = UserProfileOptions.localizedPersona(for: "custom")
        if selectedPersonaOption == customOptionLocalized {
            return ""
        }
        return storedPersonaKey
    }
    
    private var constellationKeyForTheme: String {
        let preferNotToSay = UserProfileOptions.localizedConstellation(for: "prefer_not_to_say")
        if selectedConstellation == preferNotToSay {
            return ""
        }
        return storedConstellationKey
    }
    
    private var themeSuggestions: [ProfileThemeSuggestion] {
        ProfileThemePalette.suggestions(
            personaKey: personaKeyForTheme,
            constellationKey: constellationKeyForTheme
        )
    }
    
    init(
        currentName: String,
        currentAvatarData: Data?,
        currentPersona: String,
        currentConstellation: String,
        onSave: @escaping (String, Data?, String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.currentName = currentName
        self.currentAvatarData = currentAvatarData
        self.currentPersona = currentPersona
        self.currentConstellation = currentConstellation
        self.onSave = onSave
        self.onCancel = onCancel
        _editedName = State(initialValue: currentName)
        
        // 转换存储值为本地化显示值
        // 处理身份标签
        let personaLocalized = UserProfileOptions.personaLocalizedValue(for: currentPersona)
        var personaKeyToStore = currentPersona
        // 检查是否是预定义选项（键值）
        if UserProfileOptions.personaKeys.contains(currentPersona) {
            personaKeyToStore = currentPersona
        } else if !currentPersona.isEmpty {
            // 可能是旧的中文值或自定义值，尝试转换
            let oldToNewMap: [String: String] = [
                "旅行家": "traveler",
                "徒步爱好者": "hiker",
                "摄影师": "photographer",
                "设计师": "designer",
                "美食家": "foodie",
                "数码玩家": "techie",
                "不愿透露": "prefer_not_to_say"
            ]
            personaKeyToStore = oldToNewMap[currentPersona] ?? currentPersona // 如果是自定义值，保持不变
        }
        let personaInOptions = UserProfileOptions.personaKeys.contains(personaKeyToStore)
        let customOptionLocalized = UserProfileOptions.localizedPersona(for: "custom")
        _selectedPersonaOption = State(initialValue: personaInOptions && !currentPersona.isEmpty ? personaLocalized : customOptionLocalized)
        _customPersona = State(initialValue: personaInOptions || currentPersona.isEmpty ? "" : currentPersona)
        _storedPersonaKey = State(initialValue: currentPersona.isEmpty ? "traveler" : personaKeyToStore)
        
        // 处理星座
        let constellationLocalized = UserProfileOptions.constellationLocalizedValue(for: currentConstellation)
        let constellationKeyToStore: String = {
            if UserProfileOptions.constellationKeys.contains(currentConstellation) {
                return currentConstellation
            } else if !currentConstellation.isEmpty {
                let oldToNewMap: [String: String] = [
                    "白羊座": "aries", "金牛座": "taurus", "双子座": "gemini", "巨蟹座": "cancer",
                    "狮子座": "leo", "处女座": "virgo", "天秤座": "libra", "天蝎座": "scorpio",
                    "射手座": "sagittarius", "摩羯座": "capricorn", "水瓶座": "aquarius", "双鱼座": "pisces",
                    "不愿透露": "prefer_not_to_say"
                ]
                return oldToNewMap[currentConstellation] ?? "prefer_not_to_say"
            }
            return "prefer_not_to_say"
        }()
        _selectedConstellation = State(initialValue: currentConstellation.isEmpty ? UserProfileOptions.localizedConstellation(for: "prefer_not_to_say") : constellationLocalized)
        _storedConstellationKey = State(initialValue: constellationKeyToStore)
    }
    
    private var customPersonaOption: String {
        UserProfileOptions.localizedPersona(for: "custom")
    }

    private var hasSelectedAvatar: Bool {
        if shouldRemoveAvatar { return false }
        return selectedImageData != nil || currentAvatarData != nil
    }

    private var canRestoreAvatar: Bool {
        shouldRemoveAvatar && currentAvatarData != nil
    }

    var body: some View {
        NavigationStack {
            FootprintFormScaffold(
                accent: brandColorManager.currentBrandColor,
                secondaryAccent: FootprintTheme.Accent.secondary
            ) {
                List {
                    avatarSection
                    nameSection
                    profileSection
                    themeColorSection
                }
                .tint(brandColorManager.currentBrandColor)
                .navigationTitle("account".localized)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("cancel".localized) {
                            onCancel()
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("save".localized) {
                            saveProfile()
                        }
                        .fontWeight(.semibold)
                        .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedItem, matching: .images)
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        if let newItem = newItem {
                            if let data = try? await newItem.loadTransferable(type: Data.self) {
                                await MainActor.run {
                                    selectedImageData = data
                                    shouldRemoveAvatar = false
                                }
                            }
                        }
                    }
                }
                .alert("remove_avatar_confirm_title".localized, isPresented: $showingDeleteConfirm) {
                    Button("cancel".localized, role: .cancel) { }
                    Button("remove".localized, role: .destructive) {
                        shouldRemoveAvatar = true
                        selectedImageData = nil
                    }
                } message: {
                    Text("remove_avatar_confirm_message".localized)
                }
                .sensoryFeedback(.impact(weight: .medium, intensity: 0.8), trigger: themeApplyCount)
            }
        }
    }

    private var avatarSection: some View {
        Section {
            VStack(spacing: 12) {
                accountAvatar
                    .frame(width: 88, height: 88)
                    .clipShape(Circle())
                    .accessibilityLabel("edit_avatar".localized)

                avatarEditControl
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    @ViewBuilder
    private var accountAvatar: some View {
        if shouldRemoveAvatar {
            avatarPlaceholder
        } else if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else if let currentData = currentAvatarData, let uiImage = UIImage(data: currentData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Image(systemName: "person.crop.circle.fill")
            .resizable()
            .scaledToFit()
            .foregroundStyle(brandColorManager.currentBrandColor.gradient)
    }

    @ViewBuilder
    private var avatarEditControl: some View {
        if hasSelectedAvatar || canRestoreAvatar {
            Menu {
                Button {
                    showingPhotoPicker = true
                } label: {
                    Label("select_photo".localized, systemImage: "photo")
                }
                if canRestoreAvatar {
                    Button {
                        shouldRemoveAvatar = false
                    } label: {
                        Label("restore_avatar".localized, systemImage: "arrow.uturn.backward")
                    }
                } else if hasSelectedAvatar {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("remove_avatar".localized, systemImage: "trash")
                    }
                }
            } label: {
                Text("edit".localized)
                    .frame(minHeight: 44)
            }
            .buttonStyle(.borderless)
        } else {
            Button("edit".localized) {
                showingPhotoPicker = true
            }
            .buttonStyle(.borderless)
            .frame(minHeight: 44)
        }
    }

    private var nameSection: some View {
        Section {
            TextField("enter_username".localized, text: $editedName)
                .focused($isTextFieldFocused)
        } header: {
            Text("custom_username".localized)
        } footer: {
            Text("username_description".localized)
        }
    }

    private var profileSection: some View {
        Section {
            Picker("identity_tag".localized, selection: $selectedPersonaOption) {
                ForEach(personaOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.navigationLink)
            .onChange(of: selectedPersonaOption) { _, newValue in
                storedPersonaKey = UserProfileOptions.personaKey(for: newValue)
            }

            if selectedPersonaOption == customPersonaOption {
                TextField("identity_tag_placeholder".localized, text: $customPersona)
            }

            Picker("constellation_title".localized, selection: $selectedConstellation) {
                ForEach(constellationOptions, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.navigationLink)
            .onChange(of: selectedConstellation) { _, newValue in
                storedConstellationKey = UserProfileOptions.constellationKey(for: newValue)
            }
        } header: {
            Text("account_profile_section".localized)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                Text("identity_tag_description".localized)
                Text("constellation_description".localized)
            }
        }
    }

    private var themeColorSection: some View {
        Section {
            if themeSuggestions.isEmpty {
                Text("onboarding_theme_color_empty".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(themeSuggestions) { suggestion in
                    let isCurrent = ProfileThemePalette.matches(
                        suggestion.color,
                        brand: brandColorManager.currentBrandColor
                    )
                    Button {
                        guard !isCurrent else { return }
                        brandColorManager.setCustomBrandColor(suggestion.color)
                        themeApplyCount += 1
                    } label: {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(suggestion.color)
                                .frame(width: 28, height: 28)
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.sourceTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(suggestion.attributeName)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                            Spacer(minLength: 8)
                            if isCurrent {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(brandColorManager.currentBrandColor)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityLabel("\(suggestion.sourceTitle) \(suggestion.attributeName)")
                    .accessibilityAddTraits(isCurrent ? .isSelected : AccessibilityTraits())
                }
            }
        } header: {
            Text("onboarding_theme_color_title".localized)
        } footer: {
            VStack(alignment: .leading, spacing: 4) {
                if !themeSuggestions.isEmpty {
                    Text("profile_theme_color_description".localized)
                }
                Text("theme_color_reset_hint".localized)
            }
        }
    }

    private func saveProfile() {
        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalAvatar = shouldRemoveAvatar ? nil : (selectedImageData ?? currentAvatarData)
        let personaValue: String = {
            if selectedPersonaOption == customPersonaOption {
                return customPersona.trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                return storedPersonaKey
            }
        }()
        let preferNotToSayConstellation = UserProfileOptions.localizedConstellation(for: "prefer_not_to_say")
        let constellationValue = selectedConstellation == preferNotToSayConstellation ? "" : storedConstellationKey
        onSave(trimmedName, finalAvatar, personaValue, constellationValue)
    }
}


#Preview {
    SettingsView()
        .modelContainer(for: TravelTrip.self, inMemory: true)
        .environmentObject(UserProfileManager.shared)
        .environmentObject(LanguageManager.shared)
        .environmentObject(CountryManager.shared)
        .environmentObject(BrandColorManager.shared)
}
