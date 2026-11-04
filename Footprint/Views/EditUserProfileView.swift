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
    let currentMbti: String
    let currentGender: String
    let currentAgeGroup: String
    let currentConstellation: String
    let onSave: (String, Data?, String, String, String, String, String) -> Void
    let onCancel: () -> Void
    
    @State private var editedName: String
    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImageData: Data?
    @State private var shouldRemoveAvatar = false
    @State private var showingDeleteConfirm = false
    @State private var selectedPersonaOption: String
    @State private var customPersona: String
    @State private var selectedMbti: String
    @State private var selectedGender: String
    @State private var selectedAgeGroup: String
    @State private var selectedConstellation: String
    @FocusState private var isTextFieldFocused: Bool
    
    // 使用本地化选项
    private var personaOptions: [String] {
        UserProfileOptions.localizedPersonaOptions()
    }
    
    private let mbtiOptions: [String] = [
        "INTJ","INTP","ENTJ","ENTP",
        "INFJ","INFP","ENFJ","ENFP",
        "ISTJ","ISFJ","ESTJ","ESFJ",
        "ISTP","ISFP","ESTP","ESFP"
    ]
    
    private var genderOptions: [String] {
        UserProfileOptions.localizedGenderOptions()
    }
    
    private var ageGroupOptions: [String] {
        UserProfileOptions.localizedAgeGroupOptions()
    }
    
    private var constellationOptions: [String] {
        UserProfileOptions.localizedConstellationOptions()
    }
    
    // 存储实际键值的状态变量
    @State private var storedPersonaKey: String = ""
    @State private var storedGenderKey: String = ""
    @State private var storedAgeGroupKey: String = ""
    @State private var storedConstellationKey: String = ""
    
    init(
        currentName: String,
        currentAvatarData: Data?,
        currentPersona: String,
        currentMbti: String,
        currentGender: String,
        currentAgeGroup: String,
        currentConstellation: String,
        onSave: @escaping (String, Data?, String, String, String, String, String) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.currentName = currentName
        self.currentAvatarData = currentAvatarData
        self.currentPersona = currentPersona
        self.currentMbti = currentMbti
        self.currentGender = currentGender
        self.currentAgeGroup = currentAgeGroup
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
        
        _selectedMbti = State(initialValue: currentMbti.isEmpty ? "INTJ" : currentMbti)
        
        // 处理性别
        let genderLocalized = UserProfileOptions.genderLocalizedValue(for: currentGender)
        let genderKeyToStore: String = {
            if UserProfileOptions.genderKeys.contains(currentGender) {
                return currentGender
            } else if !currentGender.isEmpty {
                let oldToNewMap: [String: String] = ["男": "male", "女": "female", "其他": "other", "不愿透露": "prefer_not_to_say"]
                return oldToNewMap[currentGender] ?? "prefer_not_to_say"
            }
            return "prefer_not_to_say"
        }()
        _selectedGender = State(initialValue: currentGender.isEmpty ? UserProfileOptions.localizedGender(for: "prefer_not_to_say") : genderLocalized)
        _storedGenderKey = State(initialValue: genderKeyToStore)
        
        // 处理年龄段
        let ageGroupLocalized = UserProfileOptions.ageGroupLocalizedValue(for: currentAgeGroup)
        let ageGroupKeyToStore: String = {
            if UserProfileOptions.ageGroupKeys.contains(currentAgeGroup) {
                return currentAgeGroup
            } else if !currentAgeGroup.isEmpty {
                let oldToNewMap: [String: String] = [
                    "18岁以下": "under_18", "18-25岁": "18_25", "26-35岁": "26_35",
                    "36-45岁": "36_45", "46-55岁": "46_55", "56岁以上": "over_56",
                    "不愿透露": "prefer_not_to_say"
                ]
                return oldToNewMap[currentAgeGroup] ?? "prefer_not_to_say"
            }
            return "prefer_not_to_say"
        }()
        _selectedAgeGroup = State(initialValue: currentAgeGroup.isEmpty ? UserProfileOptions.localizedAgeGroup(for: "prefer_not_to_say") : ageGroupLocalized)
        _storedAgeGroupKey = State(initialValue: ageGroupKeyToStore)
        
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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 头像
                    VStack(alignment: .leading, spacing: 12) {
                        Text("edit_avatar".localized)
                            .font(.headline)
                        
                        Text("avatar_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        VStack(spacing: 16) {
                            Group {
                                if shouldRemoveAvatar {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 120))
                                        .foregroundStyle(.blue.gradient)
                                } else if let imageData = selectedImageData, let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else if let currentData = currentAvatarData, let uiImage = UIImage(data: currentData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    Image(systemName: "person.circle.fill")
                                        .font(.system(size: 120))
                                        .foregroundStyle(.blue.gradient)
                                }
                            }
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                            )
                            
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                Label("select_photo".localized, systemImage: "photo")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(12)
                            }
                            
                            if currentAvatarData != nil || selectedImageData != nil {
                                Button(role: .destructive) {
                                    showingDeleteConfirm = true
                                } label: {
                                    Label(shouldRemoveAvatar ? "restore_avatar".localized : "remove_avatar".localized, systemImage: shouldRemoveAvatar ? "arrow.uturn.backward" : "trash")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.red.opacity(0.1))
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 用户名
                    VStack(alignment: .leading, spacing: 12) {
                        Text("custom_username".localized)
                            .font(.headline)
                        
                        Text("username_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("enter_username".localized, text: $editedName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .focused($isTextFieldFocused)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 身份标签
                    VStack(alignment: .leading, spacing: 12) {
                        Text("identity_tag".localized)
                            .font(.headline)
                        
                        Text("identity_tag_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("identity_tag".localized, selection: $selectedPersonaOption) {
                            ForEach(personaOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedPersonaOption) { newValue in
                            storedPersonaKey = UserProfileOptions.personaKey(for: newValue)
                        }
                        
                        let customOptionLocalized = UserProfileOptions.localizedPersona(for: "custom")
                        if selectedPersonaOption == customOptionLocalized {
                            TextField("identity_tag_placeholder".localized, text: $customPersona)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // MBTI
                    VStack(alignment: .leading, spacing: 12) {
                        Text("mbti_title".localized)
                            .font(.headline)
                        
                        Text("mbti_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("mbti_title".localized, selection: $selectedMbti) {
                            ForEach(mbtiOptions, id: \.self) { type in
                                Text(type).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 性别
                    VStack(alignment: .leading, spacing: 12) {
                        Text("gender_title".localized)
                            .font(.headline)
                        
                        Text("gender_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("gender_title".localized, selection: $selectedGender) {
                            ForEach(genderOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedGender) { newValue in
                            storedGenderKey = UserProfileOptions.genderKey(for: newValue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 年龄段
                    VStack(alignment: .leading, spacing: 12) {
                        Text("age_group_title".localized)
                            .font(.headline)
                        
                        Text("age_group_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("age_group_title".localized, selection: $selectedAgeGroup) {
                            ForEach(ageGroupOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedAgeGroup) { newValue in
                            storedAgeGroupKey = UserProfileOptions.ageGroupKey(for: newValue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 星座
                    VStack(alignment: .leading, spacing: 12) {
                        Text("constellation_title".localized)
                            .font(.headline)
                        
                        Text("constellation_description".localized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("constellation_title".localized, selection: $selectedConstellation) {
                            ForEach(constellationOptions, id: \.self) { option in
                                Text(option).tag(option)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: selectedConstellation) { newValue in
                            storedConstellationKey = UserProfileOptions.constellationKey(for: newValue)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
            }
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
                        let trimmedName = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalAvatar = shouldRemoveAvatar ? nil : (selectedImageData ?? currentAvatarData)
                        let personaValue: String = {
                            let customOptionLocalized = UserProfileOptions.localizedPersona(for: "custom")
                            if selectedPersonaOption == customOptionLocalized {
                                return customPersona.trimmingCharacters(in: .whitespacesAndNewlines)
                            } else {
                                return storedPersonaKey
                            }
                        }()
                        let preferNotToSayGender = UserProfileOptions.localizedGender(for: "prefer_not_to_say")
                        let preferNotToSayAge = UserProfileOptions.localizedAgeGroup(for: "prefer_not_to_say")
                        let preferNotToSayConstellation = UserProfileOptions.localizedConstellation(for: "prefer_not_to_say")
                        let genderValue = selectedGender == preferNotToSayGender ? "" : storedGenderKey
                        let ageGroupValue = selectedAgeGroup == preferNotToSayAge ? "" : storedAgeGroupKey
                        let constellationValue = selectedConstellation == preferNotToSayConstellation ? "" : storedConstellationKey
                        onSave(trimmedName, finalAvatar, personaValue, selectedMbti, genderValue, ageGroupValue, constellationValue)
                    }
                    .disabled(editedName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
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
        }
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
