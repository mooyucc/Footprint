//
//  UserProfileManager.swift
//  Footprint
//
//  Local user profile (name, avatar, persona tags). No Sign in with Apple.
//

import Foundation
import SwiftUI
import Combine

final class UserProfileManager: ObservableObject {
    @Published var customUserName: String = ""
    @Published var userAvatarData: Data? = nil
    @Published var personaTag: String = ""
    @Published var mbtiType: String = ""
    @Published var gender: String = ""
    @Published var ageGroup: String = ""
    @Published var constellation: String = ""
    
    static let shared = UserProfileManager()
    
    /// Device iCloud account available for CloudKit / ubiquity.
    var isICloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }
    
    private init() {
        loadProfile()
    }
    
    private func loadProfile() {
        var savedName = UserDefaults.standard.string(forKey: "customUserName") ?? ""
        
        // Migrate legacy Apple Sign In display name if custom name was never set
        if savedName.isEmpty {
            let legacyAppleName = UserDefaults.standard.string(forKey: "appleUserName") ?? ""
            if !legacyAppleName.isEmpty && legacyAppleName != "Apple ID 用户" {
                savedName = legacyAppleName
                UserDefaults.standard.set(savedName, forKey: "customUserName")
            }
        }
        
        customUserName = savedName
        userAvatarData = UserDefaults.standard.data(forKey: "userAvatarData")
        personaTag = UserDefaults.standard.string(forKey: "personaTag") ?? ""
        mbtiType = UserDefaults.standard.string(forKey: "mbtiType") ?? ""
        gender = UserDefaults.standard.string(forKey: "gender") ?? ""
        ageGroup = UserDefaults.standard.string(forKey: "ageGroup") ?? ""
        constellation = UserDefaults.standard.string(forKey: "constellation") ?? ""
    }
    
    func setCustomUserName(_ name: String) {
        customUserName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(customUserName, forKey: "customUserName")
    }
    
    func setUserAvatar(_ imageData: Data?) {
        userAvatarData = imageData
        if let data = imageData {
            UserDefaults.standard.set(data, forKey: "userAvatarData")
        } else {
            UserDefaults.standard.removeObject(forKey: "userAvatarData")
        }
    }
    
    func setPersonaTag(_ tag: String) {
        personaTag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        if personaTag.isEmpty {
            UserDefaults.standard.removeObject(forKey: "personaTag")
        } else {
            UserDefaults.standard.set(personaTag, forKey: "personaTag")
        }
    }
    
    func setMbtiType(_ type: String) {
        mbtiType = type.trimmingCharacters(in: .whitespacesAndNewlines)
        if mbtiType.isEmpty {
            UserDefaults.standard.removeObject(forKey: "mbtiType")
        } else {
            UserDefaults.standard.set(mbtiType, forKey: "mbtiType")
        }
    }
    
    func setGender(_ genderValue: String) {
        gender = genderValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if gender.isEmpty {
            UserDefaults.standard.removeObject(forKey: "gender")
        } else {
            UserDefaults.standard.set(gender, forKey: "gender")
        }
    }
    
    func setAgeGroup(_ age: String) {
        ageGroup = age.trimmingCharacters(in: .whitespacesAndNewlines)
        if ageGroup.isEmpty {
            UserDefaults.standard.removeObject(forKey: "ageGroup")
        } else {
            UserDefaults.standard.set(ageGroup, forKey: "ageGroup")
        }
    }
    
    func setConstellation(_ constellationValue: String) {
        constellation = constellationValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if constellation.isEmpty {
            UserDefaults.standard.removeObject(forKey: "constellation")
        } else {
            UserDefaults.standard.set(constellation, forKey: "constellation")
        }
    }
    
    var userAvatarImage: UIImage? {
        guard let data = userAvatarData else { return nil }
        return UIImage(data: data)
    }
    
    var displayName: String {
        if !customUserName.isEmpty {
            return customUserName
        }
        return "default_traveler_name".localized
    }
    
    /// Clears local profile fields (e.g. after delete-all-data).
    func resetProfile() {
        UserDefaults.standard.removeObject(forKey: "appleUserID")
        UserDefaults.standard.removeObject(forKey: "appleUserName")
        UserDefaults.standard.removeObject(forKey: "appleUserEmail")
        UserDefaults.standard.removeObject(forKey: "customUserName")
        UserDefaults.standard.removeObject(forKey: "userAvatarData")
        UserDefaults.standard.removeObject(forKey: "personaTag")
        UserDefaults.standard.removeObject(forKey: "mbtiType")
        UserDefaults.standard.removeObject(forKey: "gender")
        UserDefaults.standard.removeObject(forKey: "ageGroup")
        UserDefaults.standard.removeObject(forKey: "constellation")
        customUserName = ""
        userAvatarData = nil
        personaTag = ""
        mbtiType = ""
        gender = ""
        ageGroup = ""
        constellation = ""
    }
}
