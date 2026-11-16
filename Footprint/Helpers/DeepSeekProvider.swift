//
//  DeepSeekProvider.swift
//  Footprint
//
//  Created on 2025/01/27.
//  DeepSeek API 服务实现
//

import Foundation
import SwiftData
import Vision
import UIKit

/// DeepSeek API 服务实现
/// 使用 DeepSeek API（兼容 OpenAI 格式）提供 AI 功能
class DeepSeekProvider: AIServiceProtocol {
    static let shared = DeepSeekProvider()
    
    private let apiKey: String
    private let baseURL = "https://api.deepseek.com/v1"
    private let requestTimeout: TimeInterval = 30.0
    
    /// Prompt 体积上限，避免 Vision OCR / 长笔记把单次输入撑到数十万 token
    private enum PromptBudget {
        static let visionOCRChars = 200
        static let noteSnippetChars = 120
        static let existingNotesChars = 500
        static let maxTripDestinations = 30
        static let maxTripPhotoDestinations = 15
    }
    
    // DeepSeek 模型配置（deepseek-chat 已于 2026-07-24 退役，改用 v4-flash）
    private let chatModel = "deepseek-v4-flash"
    // 注意：DeepSeek API 当前可能不支持多模态（图片），使用文本模型
    // private let visionModel = "deepseek-v2"  // 多模态模型（暂不支持）
    
    private init() {
        // 从配置文件或环境变量读取API Key
        // 优先级：环境变量 > Info.plist
        if let key = ProcessInfo.processInfo.environment["DeepSeekAPIKey"],
           !key.isEmpty {
            self.apiKey = key
            print("✅ [DeepSeek] 从环境变量读取API Key")
        } else if let key = Bundle.main.object(forInfoDictionaryKey: "DeepSeekAPIKey") as? String,
                  !key.isEmpty {
            self.apiKey = key
            print("✅ [DeepSeek] 从Info.plist读取API Key")
        } else {
            fatalError("❌ [DeepSeek] API Key未配置，请在Info.plist中添加DeepSeekAPIKey或设置环境变量")
        }
        
        print("🤖 [DeepSeek] 服务已初始化，API Key: \(String(apiKey.prefix(8)))...")
    }
    
    // MARK: - AIServiceProtocol Implementation
    
    func generateNotes(
        from images: [Data],
        location: String,
        province: String,
        country: String,
        date: Date,
        existingNotes: String?,
        persona: String,
        mbti: String,
        gender: String,
        ageGroup: String,
        constellation: String
    ) async throws -> String {
        print("🤖 [DeepSeek] 开始生成笔记，地点: \(location), 省份: \(province), 国家: \(country)")
        
        // 获取当前语言配置
        let langConfig = LanguageConfig.forLanguage(currentLanguage)
        
        // 构建 Prompt
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = langConfig.dateFormat
        let localeId = currentLanguage == .chinese || currentLanguage == .chineseTraditional ? "zh_CN" : 
                       currentLanguage == .japanese ? "ja_JP" : 
                       currentLanguage == .korean ? "ko_KR" : 
                       currentLanguage == .french ? "fr_FR" : 
                       currentLanguage == .spanish ? "es_ES" :
                       currentLanguage == .german ? "de_DE" : "en_US"
        dateFormatter.locale = Locale(identifier: localeId)
        let dateString = dateFormatter.string(from: date)
        
        let trimmedPersona = persona.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMbti = mbti.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGender = gender.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAgeGroup = ageGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConstellation = constellation.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 根据身份标签动态设置身份，如果没有则使用默认身份（根据语言）
        let identity = !trimmedPersona.isEmpty ? trimmedPersona : langConfig.defaultIdentity
        
        // 构建完整的地点信息（根据语言）
        var locationInfo: String
        let separator = currentLanguage == .english ? ": " : "："
        let provinceSeparator = currentLanguage == .english ? " (" : "（"
        let provinceClose = currentLanguage == .english ? ")" : "）"
        locationInfo = "\(langConfig.locationLabel)\(separator)\(location)"
        if !province.isEmpty {
            locationInfo += "\(provinceSeparator)\(province)\(provinceClose)"
        }
        locationInfo += "\n- \(langConfig.countryLabel)\(separator)\(country)"
        
        // 获取季节信息（用于prompt中，但不写入生成的笔记）
        let seasonString = getSeasonString(from: date, language: currentLanguage)
        let seasonLabel = currentLanguage == .english ? "Season" : (currentLanguage == .japanese ? "季節" : (currentLanguage == .korean ? "계절" : (currentLanguage == .french ? "Saison" : (currentLanguage == .spanish ? "Estación" : (currentLanguage == .german ? "Jahreszeit" : "季节")))))
        
        // 构建prompt开头（根据语言，使用季节而非具体日期）
        var promptText: String
        if currentLanguage == .english {
            promptText = "You are a \(identity). Generate a travel note based on the following information:\n- \(locationInfo)\n- \(seasonLabel)\(separator)\(seasonString)"
        } else {
            promptText = "你是一位\(identity)。根据以下信息生成一段旅行笔记：\n- \(locationInfo)\n- \(seasonLabel)\(separator)\(seasonString)"
        }
        
        // 构建用户画像信息，用于指导文风（但不写入笔记内容）
        var styleGuidance = ""
        if !trimmedPersona.isEmpty {
            styleGuidance += "请以\(trimmedPersona)的身份和口吻来写作"
        }
        if !trimmedMbti.isEmpty {
            if !styleGuidance.isEmpty {
                styleGuidance += "，"
            }
            styleGuidance += "用词和情绪表达应符合\(trimmedMbti)的性格倾向"
        }
        if !trimmedGender.isEmpty && trimmedGender != "不愿透露" {
            if !styleGuidance.isEmpty {
                styleGuidance += "，"
            }
            styleGuidance += "考虑用户性别为\(trimmedGender)的视角和表达习惯"
        }
        if !trimmedAgeGroup.isEmpty && trimmedAgeGroup != "不愿透露" {
            if !styleGuidance.isEmpty {
                styleGuidance += "，"
            }
            styleGuidance += "结合\(trimmedAgeGroup)年龄段的生活经验和关注点"
        }
        if !trimmedConstellation.isEmpty && trimmedConstellation != "不愿透露" {
            if !styleGuidance.isEmpty {
                styleGuidance += "，"
            }
            styleGuidance += "参考\(trimmedConstellation)的性格特质来调整表达风格"
        }
        
        if !styleGuidance.isEmpty {
            let separator = currentLanguage == .english ? ": " : "："
            promptText += "\n\n\(langConfig.styleGuidanceLabel)\(separator)\(styleGuidance)。"
        }
        
        // 检查用户是否已输入笔记文字（截断后写入 prompt）
        let trimmedExistingNotes = truncateForPrompt(
            existingNotes ?? "",
            maxLength: PromptBudget.existingNotesChars
        )
        let hasExistingNotes = !trimmedExistingNotes.isEmpty
        
        if hasExistingNotes {
            // 如果用户已写文字，要求美化用户文字
            let separator = currentLanguage == .english ? ": " : "："
            if currentLanguage == .english {
                promptText += "\n\n**User's existing notes**\(separator)\n\(trimmedExistingNotes)\n\n**Important**: The user has already written some notes above. Your main task is to **polish and beautify** the user's existing text, making it more elegant, fluent, and expressive while preserving the original meaning and key information. Do not generate completely new content. Only enhance and refine what the user has written."
            } else {
                promptText += "\n\n**用户已写的笔记**\(separator)\n\(trimmedExistingNotes)\n\n**重要提示**：用户已经写了一段笔记文字（见上方）。你的主要任务是**美化用户已写的文字**，使其更加优美、流畅、有表现力，同时保留原文的意思和关键信息。不要生成全新的内容，只需要对用户已写的文字进行润色和美化。"
            }
            print("📝 [DeepSeek] 检测到用户已输入笔记，将进行美化处理")
        }
        
        // 如果有照片，使用 Apple Vision API 识别图片内容
        if !images.isEmpty {
            print("📸 [Vision] 开始使用Apple Vision API识别\(images.count)张照片...")
            
            var imageDescriptions: [String] = []
            let photoLabel = langConfig.photoLabel
            let separator = currentLanguage == .english ? ": " : "："
            for (index, imageData) in images.prefix(3).enumerated() {
                if let description = await analyzeImageWithVision(imageData) {
                    if currentLanguage == .english {
                        imageDescriptions.append("\(photoLabel) \(index + 1)\(separator)\(description)")
                    } else {
                        imageDescriptions.append("\(photoLabel)\(index + 1)\(separator)\(description)")
                    }
                    print("✅ [Vision] 照片\(index + 1)识别成功：\(description.prefix(50))...")
                } else {
                    print("⚠️ [Vision] 照片\(index + 1)识别失败，跳过")
                }
            }
            
            if !imageDescriptions.isEmpty {
                promptText += "\n- \(langConfig.photoDescriptionLabel)\(separator)\n\(imageDescriptions.joined(separator: "\n"))"
                print("✅ [Vision] 图片识别完成，共识别\(imageDescriptions.count)张照片")
            } else {
                if currentLanguage == .english {
                    promptText += "\n- User uploaded \(images.count) photos (image recognition was not successful)"
                } else {
                    promptText += "\n- 用户上传了\(images.count)张照片（图片识别未成功）"
                }
                print("⚠️ [Vision] 所有照片识别失败，使用通用描述")
            }
            
            // 构建本地化的prompt结尾（有照片的情况）
            if currentLanguage == .english {
                if hasExistingNotes {
                    promptText += "\n\n\(langConfig.importantNoteLabel): Please strictly follow the location information provided above (\(location)\(province.isEmpty ? "" : ", \(province)"), \(country)). Even if the photos may contain information or features of other locations, you must use the provided location information and not infer or guess the location from the photos.\n\nBased on the above information, especially the user's existing notes and photo content descriptions, **polish and beautify** the user's existing notes, \(langConfig.wordLimit144). \(langConfig.requirementsLabel):\n1. **Your main task is to polish the user's existing notes, not to generate new content**\n2. **Must use the provided location information (\(location)\(province.isEmpty ? "" : ", \(province)"), \(country)), do not use other location names that may appear in the photos**\n3. Combine the scenes and content actually seen in the photos (but the location must be \(location))\n4. Make the language more elegant, fluent, and expressive while preserving the original meaning\n5. Reflect local culture or natural features if relevant\n6. \(langConfig.outputLanguageInstruction)\n7. **Do not mention identity tags, MBTI, gender, age group, constellation and other user attribute information, only write pure travel note content**\n8. **Do NOT mention specific dates, times, or location names in the generated note. At most, you can mention the season (\(seasonString)) if it's relevant to the content**\n9. **Important: Word count must be strictly controlled within 144 words, do not exceed**"
                } else {
                    promptText += "\n\n\(langConfig.importantNoteLabel): Please strictly follow the location information provided above (\(location)\(province.isEmpty ? "" : ", \(province)"), \(country)) to generate the note. Even if the photos may contain information or features of other locations, you must use the provided location information and not infer or guess the location from the photos.\n\nBased on the above information, especially the photo content descriptions, generate a travel note, \(langConfig.wordLimit144). \(langConfig.requirementsLabel):\n1. **Must use the provided location information (\(location)\(province.isEmpty ? "" : ", \(province)"), \(country)), do not use other location names that may appear in the photos**\n2. Combine the scenes and content actually seen in the photos (but the location must be \(location))\n3. Combine the characteristics and cultural background of this location\n4. Reflect local culture or natural features\n5. Natural and fluent language with personal feelings\n6. \(langConfig.outputLanguageInstruction)\n7. **Do not mention identity tags, MBTI, gender, age group, constellation and other user attribute information, only write pure travel note content**\n8. **Do NOT mention specific dates, times, or location names in the generated note. At most, you can mention the season (\(seasonString)) if it's relevant to the content**\n9. **Important: Word count must be strictly controlled within 144 words, do not exceed**"
                }
            } else {
                let comma = currentLanguage == .chinese || currentLanguage == .chineseTraditional || currentLanguage == .japanese || currentLanguage == .korean ? "，" : ", "
                if hasExistingNotes {
                    promptText += "\n\n\(langConfig.importantNoteLabel)：请严格按照上面提供的地点信息（\(location)\(province.isEmpty ? "" : "\(comma)\(province)")，\(country)）。即使照片中可能包含其他地点的信息或特征，也必须使用提供的地点信息，不要从照片中推断或猜测地点。\n\n请根据以上信息，特别是用户已写的笔记和照片内容描述，**美化用户已写的笔记**，\(langConfig.wordLimit144)。\(langConfig.requirementsLabel)：\n1. **你的主要任务是美化用户已写的笔记，而不是生成新内容**\n2. **必须使用提供的地点信息（\(location)\(province.isEmpty ? "" : "\(comma)\(province)")，\(country)），不要使用照片中可能出现的其他地点名称**\n3. 结合照片中实际看到的场景和内容（但地点必须是\(location)）\n4. 使语言更加优美、流畅、有表现力，同时保留原文的意思\n5. 如果相关，体现当地文化或自然风貌\n6. \(langConfig.outputLanguageInstruction)\n7. **不要提及身份标签、MBTI、性别、年龄段、星座等用户属性信息，只写纯粹的旅行笔记内容**\n8. **不要在生成的笔记中提及具体的时间（日期）、地点名称等信息，最多只能提到季节（\(seasonString)）**\n9. **重要：字数必须严格控制在144字以内，不要超过**"
                } else {
                    promptText += "\n\n\(langConfig.importantNoteLabel)：请严格按照上面提供的地点信息（\(location)\(province.isEmpty ? "" : "\(comma)\(province)")，\(country)）生成笔记。即使照片中可能包含其他地点的信息或特征，也必须使用提供的地点信息，不要从照片中推断或猜测地点。\n\n请根据以上信息，特别是照片内容描述，生成一段旅行笔记，\(langConfig.wordLimit144)。\(langConfig.requirementsLabel)：\n1. **必须使用提供的地点信息（\(location)\(province.isEmpty ? "" : "\(comma)\(province)")，\(country)），不要使用照片中可能出现的其他地点名称**\n2. 结合照片中实际看到的场景和内容（但地点必须是\(location)）\n3. 结合这个地点的特色和文化背景\n4. 体现当地文化或自然风貌\n5. 语言自然流畅，带有个人感受\n6. \(langConfig.outputLanguageInstruction)\n7. **不要提及身份标签、MBTI、性别、年龄段、星座等用户属性信息，只写纯粹的旅行笔记内容**\n8. **不要在生成的笔记中提及具体的时间（日期）、地点名称等信息，最多只能提到季节（\(seasonString)）**\n9. **重要：字数必须严格控制在144字以内，不要超过**"
                }
            }
        } else {
            // 构建本地化的prompt结尾（无照片的情况）
            if currentLanguage == .english {
                let comma = province.isEmpty ? "" : ", \(province)"
                if hasExistingNotes {
                    promptText += "\n\nBased on the above information, especially the user's existing notes, **polish and beautify** the user's existing notes, \(langConfig.wordLimit144). \(langConfig.requirementsLabel):\n1. **Your main task is to polish the user's existing notes, not to generate new content**\n2. Describe the characteristics of this location (\(location)\(comma), \(country))\n3. Make the language more elegant, fluent, and expressive while preserving the original meaning\n4. Reflect local culture or natural features if relevant\n5. \(langConfig.outputLanguageInstruction)\n6. **Do not mention identity tags, MBTI, gender, age group, constellation and other user attribute information, only write pure travel note content**\n7. **Do NOT mention specific dates, times, or location names in the generated note. At most, you can mention the season (\(seasonString)) if it's relevant to the content**\n8. **Important: Word count must be strictly controlled within 144 words, do not exceed**"
                } else {
                    promptText += "\n\nGenerate a travel note, \(langConfig.wordLimit144). \(langConfig.requirementsLabel):\n1. Describe the characteristics of this location (\(location)\(comma), \(country))\n2. Reflect local culture or natural features\n3. Natural and fluent language with personal feelings\n4. \(langConfig.outputLanguageInstruction)\n5. **Do not mention identity tags, MBTI, gender, age group, constellation and other user attribute information, only write pure travel note content**\n6. **Do NOT mention specific dates, times, or location names in the generated note. At most, you can mention the season (\(seasonString)) if it's relevant to the content**\n7. **Important: Word count must be strictly controlled within 144 words, do not exceed**"
                }
            } else {
                let comma = currentLanguage == .chinese || currentLanguage == .chineseTraditional || currentLanguage == .japanese || currentLanguage == .korean ? "，" : ", "
                if hasExistingNotes {
                    promptText += "\n\n请根据以上信息，特别是用户已写的笔记，**美化用户已写的笔记**，\(langConfig.wordLimit144)。\(langConfig.requirementsLabel)：\n1. **你的主要任务是美化用户已写的笔记，而不是生成新内容**\n2. 描述这个地点（\(location)\(province.isEmpty ? "" : "\(comma)\(province)")，\(country)）的特色\n3. 使语言更加优美、流畅、有表现力，同时保留原文的意思\n4. 如果相关，体现当地文化或自然风貌\n5. \(langConfig.outputLanguageInstruction)\n6. **不要提及身份标签、MBTI、性别、年龄段、星座等用户属性信息，只写纯粹的旅行笔记内容**\n7. **不要在生成的笔记中提及具体的时间（日期）、地点名称等信息，最多只能提到季节（\(seasonString)）**\n8. **重要：字数必须严格控制在144字以内，不要超过**"
                } else {
                    promptText += "\n\n请生成一段旅行笔记，\(langConfig.wordLimit144)。\(langConfig.requirementsLabel)：\n1. 描述这个地点（\(location)\(province.isEmpty ? "" : "\(comma)\(province)")，\(country)）的特色\n2. 体现当地文化或自然风貌\n3. 语言自然流畅，带有个人感受\n4. \(langConfig.outputLanguageInstruction)\n5. **不要提及身份标签、MBTI、性别、年龄段、星座等用户属性信息，只写纯粹的旅行笔记内容**\n6. **不要在生成的笔记中提及具体的时间（日期）、地点名称等信息，最多只能提到季节（\(seasonString)）**\n7. **重要：字数必须严格控制在144字以内，不要超过**"
                }
            }
        }
        
        let messages: [ChatMessage] = [
            .user([.text(promptText)])
        ]
        
        let response = try await callChatAPI(messages: messages, model: chatModel)
        
        // 限制内容长度在144字以内
        return limitTo144Characters(response)
    }
    
    func generateTripDescription(
        for destinations: [TravelDestination],
        existingDescription: String?,
        persona: String,
        mbti: String,
        gender: String,
        ageGroup: String,
        constellation: String
    ) async throws -> String {
        print("🤖 [DeepSeek] 开始生成旅程描述，目的地数量: \(destinations.count)")
        
        guard !destinations.isEmpty else {
            throw AIError.invalidInput("目的地列表为空")
        }
        
        // 获取当前语言配置
        let langConfig = LanguageConfig.forLanguage(currentLanguage)
        
        let trimmedPersona = persona.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedMbti = mbti.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGender = gender.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAgeGroup = ageGroup.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConstellation = constellation.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 根据身份标签动态设置身份，如果没有则使用默认身份（根据语言）
        let identity = !trimmedPersona.isEmpty ? trimmedPersona : langConfig.defaultIdentity
        
        // 构建目的地信息（包含笔记）；限制数量与笔记长度，控制输入 token
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = currentLanguage == .english ? "MMMM d, yyyy" : "yyyy-MM-dd"
        let localeId = currentLanguage == .chinese || currentLanguage == .chineseTraditional ? "zh_CN" : 
                       currentLanguage == .japanese ? "ja_JP" : 
                       currentLanguage == .korean ? "ko_KR" : 
                       currentLanguage == .french ? "fr_FR" : 
                       currentLanguage == .spanish ? "es_ES" :
                       currentLanguage == .german ? "de_DE" : "en_US"
        dateFormatter.locale = Locale(identifier: localeId)
        
        let separator = currentLanguage == .english ? ": " : "："
        let cappedDestinations = Array(destinations.prefix(PromptBudget.maxTripDestinations))
        // 收集目的地的季节信息
        let seasons = cappedDestinations.map { getSeasonString(from: $0.visitDate, language: currentLanguage) }
        let uniqueSeasons = Set(seasons)
        
        var destinationsInfo = cappedDestinations.map { dest in
            // 只显示地点和国家，不显示具体日期
            var info = "- \(dest.name) (\(dest.country))"
            // 如果有笔记，添加到信息中（截断）
            let note = dest.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            if !note.isEmpty {
                info += "\n  \(langConfig.noteLabel)\(separator)\(truncateForPrompt(note, maxLength: PromptBudget.noteSnippetChars))"
            }
            return info
        }.joined(separator: "\n\n")
        
        // 收集目的地的照片（限制有照片的目的地数量）
        var allImages: [(destination: String, images: [Data])] = []
        for destination in cappedDestinations where allImages.count < PromptBudget.maxTripPhotoDestinations {
            if !destination.photoDatas.isEmpty {
                allImages.append((destination: destination.name, images: destination.photoDatas))
            }
        }
        
        // 构建prompt开头（根据语言）
        var promptText: String
        if currentLanguage == .english {
            promptText = "You are a \(identity). Analyze the following trip information and generate an overall trip description:\n\nDestination List:\n\(destinationsInfo)"
        } else {
            promptText = "你是一位\(identity)。分析以下旅程信息，生成一段旅程整体描述：\n\n目的地列表：\n\(destinationsInfo)"
        }
        
        // 构建用户画像信息，用于指导文风（但不写入描述内容）
        var styleGuidance = ""
        if !trimmedPersona.isEmpty {
            styleGuidance += "请以\(trimmedPersona)的身份和口吻来写作"
        }
        if !trimmedMbti.isEmpty {
            if !styleGuidance.isEmpty {
                styleGuidance += "，"
            }
            styleGuidance += "用词和情绪表达应符合\(trimmedMbti)的性格倾向"
        }
        if !trimmedGender.isEmpty && trimmedGender != "不愿透露" {
            if !styleGuidance.isEmpty {
                styleGuidance += "，"
            }
            styleGuidance += "考虑用户性别为\(trimmedGender)的视角和表达习惯"
        }
        if !trimmedAgeGroup.isEmpty && trimmedAgeGroup != "不愿透露" {
            if !styleGuidance.isEmpty {
                styleGuidance += "，"
            }
            styleGuidance += "结合\(trimmedAgeGroup)年龄段的生活经验和关注点"
        }
        if !trimmedConstellation.isEmpty && trimmedConstellation != "不愿透露" {
            if !styleGuidance.isEmpty {
                styleGuidance += "，"
            }
            styleGuidance += "参考\(trimmedConstellation)的性格特质来调整表达风格"
        }
        
        if !styleGuidance.isEmpty {
            promptText += "\n\n\(langConfig.styleGuidanceLabel)\(separator)\(styleGuidance)。"
        }
        
        // 检查用户是否已输入旅程描述（截断后写入 prompt）
        let trimmedExistingDescription = truncateForPrompt(
            existingDescription ?? "",
            maxLength: PromptBudget.existingNotesChars
        )
        let hasExistingDescription = !trimmedExistingDescription.isEmpty
        
        if hasExistingDescription {
            // 如果用户已写描述，要求美化用户文字
            if currentLanguage == .english {
                promptText += "\n\n**User's existing trip description**\(separator)\n\(trimmedExistingDescription)\n\n**Important**: The user has already written a trip description above. Your main task is to **polish and beautify** the user's existing text, making it more elegant, fluent, and expressive while preserving the original meaning and key information. Do not generate completely new content. Only enhance and refine what the user has written."
            } else {
                promptText += "\n\n**用户已写的旅程描述**\(separator)\n\(trimmedExistingDescription)\n\n**重要提示**：用户已经写了一段旅程描述（见上方）。你的主要任务是**美化用户已写的文字**，使其更加优美、流畅、有表现力，同时保留原文的意思和关键信息。不要生成全新的内容，只需要对用户已写的文字进行润色和美化。"
            }
            print("📝 [DeepSeek] 检测到用户已输入旅程描述，将进行美化处理")
        }
        
        // 构建季节信息提示（在照片处理之前，因为两个分支都需要使用）
        let seasonHint: String
        if uniqueSeasons.count == 1, let season = uniqueSeasons.first {
            seasonHint = season
        } else {
            seasonHint = uniqueSeasons.joined(separator: currentLanguage == .english ? ", " : "、")
        }
        
        // 如果有照片，使用 Apple Vision API 识别图片内容
        if !allImages.isEmpty {
            print("📸 [Vision] 开始使用Apple Vision API识别旅程中的照片，共\(allImages.count)个目的地有照片...")
            
            var imageDescriptions: [String] = []
            var totalProcessed = 0
            let maxImagesPerDestination = 2 // 每个目的地最多识别2张照片，避免太多
            
            for (destName, images) in allImages {
                var destImageDescriptions: [String] = []
                
                for (index, imageData) in images.prefix(maxImagesPerDestination).enumerated() {
                    if let description = await analyzeImageWithVision(imageData) {
                        if currentLanguage == .english {
                            destImageDescriptions.append("  - \(langConfig.photoLabel) \(index + 1)\(separator)\(description)")
                        } else {
                            destImageDescriptions.append("  - \(langConfig.photoLabel)\(index + 1)\(separator)\(description)")
                        }
                        totalProcessed += 1
                        print("✅ [Vision] \(destName) 照片\(index + 1)识别成功")
                    }
                }
                
                if !destImageDescriptions.isEmpty {
                    if currentLanguage == .english {
                        imageDescriptions.append("\(destName)'s \(langConfig.photoLabel.lowercased())s\(separator)\n\(destImageDescriptions.joined(separator: "\n"))")
                    } else {
                        imageDescriptions.append("\(destName)的\(langConfig.photoLabel)\(separator)\n\(destImageDescriptions.joined(separator: "\n"))")
                    }
                }
            }
            
            if !imageDescriptions.isEmpty {
                if currentLanguage == .english {
                    promptText += "\n\nPhoto content descriptions in the trip:\n\(imageDescriptions.joined(separator: "\n\n"))"
                } else {
                    promptText += "\n\n旅程中的照片内容描述：\n\(imageDescriptions.joined(separator: "\n\n"))"
                }
                print("✅ [Vision] 图片识别完成，共识别\(totalProcessed)张照片，来自\(imageDescriptions.count)个目的地")
            } else {
                if currentLanguage == .english {
                    promptText += "\n\nThe trip contains photos, but image recognition was not successful"
                } else {
                    promptText += "\n\n旅程中包含照片，但图片识别未成功"
                }
                print("⚠️ [Vision] 所有照片识别失败，使用通用描述")
            }
            
            // 构建本地化的prompt结尾（有照片的情况）
            if currentLanguage == .english {
                if hasExistingDescription {
                    promptText += "\n\nBased on the above information, especially the user's existing trip description, photo content descriptions and notes from various locations, **polish and beautify** the user's existing trip description, \(langConfig.wordLimit300). \(langConfig.requirementsLabel):\n1. **Your main task is to polish the user's existing trip description, not to generate new content**\n2. Combine the scenes and content actually seen in the photos\n3. Reference the notes from various locations to reflect the coherence and characteristics of the trip\n4. Make the language more elegant, fluent, and expressive while preserving the original meaning\n5. \(langConfig.outputLanguageInstruction)\n6. **Do not mention identity tags, MBTI, gender, age group, constellation and other user attribute information, only write pure trip description content**\n7. **Do NOT mention specific dates, times, or location names in the generated description. At most, you can mention the season(s) (\(seasonHint)) if it's relevant to the content**\n8. **Important: Word count must be strictly controlled within 300 words, do not exceed**"
                } else {
                    promptText += "\n\nBased on the above information, especially the photo content descriptions and notes from various locations, generate an overall trip description, \(langConfig.wordLimit300). \(langConfig.requirementsLabel):\n1. Combine the scenes and content actually seen in the photos\n2. Reference the notes from various locations to reflect the coherence and characteristics of the trip\n3. Natural and fluent language with personal feelings\n4. \(langConfig.outputLanguageInstruction)\n5. **Do not mention identity tags, MBTI, gender, age group, constellation and other user attribute information, only write pure trip description content**\n6. **Do NOT mention specific dates, times, or location names in the generated description. At most, you can mention the season(s) (\(seasonHint)) if it's relevant to the content**\n7. **Important: Word count must be strictly controlled within 300 words, do not exceed**"
                }
            } else {
                if hasExistingDescription {
                    promptText += "\n\n请根据以上信息，特别是用户已写的旅程描述、照片内容描述和各个地点的笔记，**美化用户已写的旅程描述**，\(langConfig.wordLimit300)。\(langConfig.requirementsLabel)：\n1. **你的主要任务是美化用户已写的旅程描述，而不是生成新内容**\n2. 结合照片中实际看到的场景和内容\n3. 参考各个地点的笔记内容，体现旅程的连贯性和特色\n4. 使语言更加优美、流畅、有表现力，同时保留原文的意思\n5. \(langConfig.outputLanguageInstruction)\n6. **不要提及身份标签、MBTI、性别、年龄段、星座等用户属性信息，只写纯粹的旅程描述内容**\n7. **不要在生成的描述中提及具体的时间（日期）、地点名称等信息，最多只能提到季节（\(seasonHint)）**\n8. **重要：字数必须严格控制在300字以内，不要超过**"
                } else {
                    promptText += "\n\n请根据以上信息，特别是照片内容描述和各个地点的笔记，生成一段旅程整体描述，\(langConfig.wordLimit300)。\(langConfig.requirementsLabel)：\n1. 结合照片中实际看到的场景和内容\n2. 参考各个地点的笔记内容，体现旅程的连贯性和特色\n3. 语言自然流畅，带有个人感受\n4. \(langConfig.outputLanguageInstruction)\n5. **不要提及身份标签、MBTI、性别、年龄段、星座等用户属性信息，只写纯粹的旅程描述内容**\n6. **不要在生成的描述中提及具体的时间（日期）、地点名称等信息，最多只能提到季节（\(seasonHint)）**\n7. **重要：字数必须严格控制在300字以内，不要超过**"
                }
            }
        } else {
            // 构建本地化的prompt结尾（无照片的情况）
            if currentLanguage == .english {
                if hasExistingDescription {
                    promptText += "\n\nBased on the above information, especially the user's existing trip description and notes from various locations, **polish and beautify** the user's existing trip description, \(langConfig.wordLimit300). \(langConfig.requirementsLabel):\n1. **Your main task is to polish the user's existing trip description, not to generate new content**\n2. Reference the notes from various locations to reflect the coherence and characteristics of the trip\n3. Make the language more elegant, fluent, and expressive while preserving the original meaning\n4. \(langConfig.outputLanguageInstruction)\n5. **Do not mention identity tags, MBTI, gender, age group, constellation and other user attribute information, only write pure trip description content**\n6. **Do NOT mention specific dates, times, or location names in the generated description. At most, you can mention the season(s) (\(seasonHint)) if it's relevant to the content**\n7. **Important: Word count must be strictly controlled within 300 words, do not exceed**"
                } else {
                    promptText += "\n\nBased on the above information, especially the notes from various locations, generate an overall trip description, \(langConfig.wordLimit300). \(langConfig.requirementsLabel):\n1. Reference the notes from various locations to reflect the coherence and characteristics of the trip\n2. Natural and fluent language with personal feelings\n3. \(langConfig.outputLanguageInstruction)\n4. **Do not mention identity tags, MBTI, gender, age group, constellation and other user attribute information, only write pure trip description content**\n5. **Do NOT mention specific dates, times, or location names in the generated description. At most, you can mention the season(s) (\(seasonHint)) if it's relevant to the content**\n6. **Important: Word count must be strictly controlled within 300 words, do not exceed**"
                }
            } else {
                if hasExistingDescription {
                    promptText += "\n\n请根据以上信息，特别是用户已写的旅程描述和各个地点的笔记，**美化用户已写的旅程描述**，\(langConfig.wordLimit300)。\(langConfig.requirementsLabel)：\n1. **你的主要任务是美化用户已写的旅程描述，而不是生成新内容**\n2. 参考各个地点的笔记内容，体现旅程的连贯性和特色\n3. 使语言更加优美、流畅、有表现力，同时保留原文的意思\n4. \(langConfig.outputLanguageInstruction)\n5. **不要提及身份标签、MBTI、性别、年龄段、星座等用户属性信息，只写纯粹的旅程描述内容**\n6. **不要在生成的描述中提及具体的时间（日期）、地点名称等信息，最多只能提到季节（\(seasonHint)）**\n7. **重要：字数必须严格控制在300字以内，不要超过**"
                } else {
                    promptText += "\n\n请根据以上信息，特别是各个地点的笔记，生成一段旅程整体描述，\(langConfig.wordLimit300)。\(langConfig.requirementsLabel)：\n1. 参考各个地点的笔记内容，体现旅程的连贯性和特色\n2. 语言自然流畅，带有个人感受\n3. \(langConfig.outputLanguageInstruction)\n4. **不要提及身份标签、MBTI、性别、年龄段、星座等用户属性信息，只写纯粹的旅程描述内容**\n5. **不要在生成的描述中提及具体的时间（日期）、地点名称等信息，最多只能提到季节（\(seasonHint)）**\n6. **重要：字数必须严格控制在300字以内，不要超过**"
                }
            }
        }
        
        let messages: [ChatMessage] = [
            .user([.text(promptText)])
        ]
        
        let response = try await callChatAPI(messages: messages, model: chatModel)
        
        // 限制内容长度在300字以内
        return limitTo300Characters(response)
    }
    
    func analyzeImages(_ images: [Data]) async throws -> ImageAnalysisResult {
        print("🤖 [DeepSeek] 开始分析照片，照片数量: \(images.count)")
        
        guard !images.isEmpty else {
            throw AIError.invalidInput("照片数组为空")
        }
        
        // 使用 Apple Vision API 识别图片内容
        print("📸 [Vision] 使用Apple Vision API识别照片...")
        
        var allDescriptions: [String] = []
        var allObservations: [String] = []
        
        for (index, imageData) in images.prefix(3).enumerated() {
            if let (description, observations) = await analyzeImageWithVisionForAnalysis(imageData) {
                allDescriptions.append("照片\(index + 1)：\(description)")
                allObservations.append(contentsOf: observations)
                print("✅ [Vision] 照片\(index + 1)识别成功")
            }
        }
        
        // 将识别结果发送给 DeepSeek 进行结构化分析
        var promptText = "你是一个照片分析助手。根据以下图片识别结果，生成结构化的分析：\n\n"
        
        if !allDescriptions.isEmpty {
            promptText += "图片描述：\n\(allDescriptions.joined(separator: "\n"))\n\n"
        }
        
        if !allObservations.isEmpty {
            promptText += "识别到的物体和场景：\(allObservations.joined(separator: "、"))\n\n"
        }
        
        promptText += "请生成分析结果，包括：\n1. 场景类型（自然、城市、建筑、美食、文化等）\n2. 主要物体或地标（从识别结果中提取）\n3. 照片的整体描述（基于识别结果）\n4. 建议的标签（3-5个）\n\n请以JSON格式返回，格式：{\"sceneType\": \"场景类型\", \"mainSubjects\": [\"物体1\", \"物体2\"], \"description\": \"描述\", \"suggestedTags\": [\"标签1\", \"标签2\"]}\n使用中文输出。"
        
        let messages: [ChatMessage] = [.user([.text(promptText)])]
        
        let response = try await callChatAPI(messages: messages, model: chatModel)
        
        // 解析 JSON 响应
        return try parseImageAnalysisResult(from: response)
    }
    
    func recommendNextDestinations(from destinations: [TravelDestination]) async throws -> String {
        print("🤖 [DeepSeek] 开始旅行目的地推荐，已记录地点数: \(destinations.count)")
        
        guard !destinations.isEmpty else {
            throw AIError.invalidInput("没有已记录的目的地")
        }
        
        let lang = currentLanguage
        let isChinese = (lang == .chinese || lang == .chineseTraditional)
        
        // 构建用户去过的地方摘要（最近最多 30 个，按日期倒序）
        let sorted = destinations.sorted { $0.visitDate > $1.visitDate }
        let recent = Array(sorted.prefix(30))
        
        var summaryLines: [String] = []
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM"
        for d in recent {
            let noteSnippet = d.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let notePart = noteSnippet.isEmpty ? "" : (isChinese ? "，笔记摘要：\(String(noteSnippet.prefix(80)))" : ", notes: \(String(noteSnippet.prefix(80)))")
            let typePart = d.type.isEmpty ? "" : (isChinese ? "，类型：\(d.type)" : ", type: \(d.type)")
            summaryLines.append("- \(d.name)（\(d.country)\(d.province.isEmpty ? "" : ", \(d.province)"))\(typePart)\(notePart))")
        }
        
        let summary = summaryLines.joined(separator: "\n")
        
        let prompt: String
        if isChinese {
            prompt = """
            根据用户已记录的旅行地点，分析其出行偏好（如喜欢的国家、类型、风格），并推荐 3～5 个适合作为「下一站」的旅行目的地。
            
            已记录的地点（最近部分）：
            \(summary)
            
            请直接输出推荐结果，必须严格按以下格式：
            1. 先简短总结用户的出行偏好（1～2 句）。
            2. 再列出 3～5 个推荐目的地，每条单独成段，用数字编号，且每条之间空一行。
            
            每条推荐的格式为：
            数字. **目的地名称，国家/地区** 推荐理由: 描述内容（1～2 句）
            
            示例：
            1. **皇后镇，新西兰** 推荐理由: 南阿尔卑斯与瓦卡蒂普湖，适合自然探索与徒步。
            
            2. **北海道，日本** 推荐理由: 自然景观与滑雪、温泉、花田，治愈感强。
            
            3. **温哥华，加拿大** 推荐理由: 城市与山海森林结合，可骑行斯坦利公园等。
            
            请按上述格式输出，使用中文，语气友好。每条之间必须空一行，不要连成一大段。
            """
        } else {
            prompt = """
            Based on the user's recorded travel places, analyze their travel preferences and recommend 3-5 destinations as their "next stop".
            
            Recorded places (recent):
            \(summary)
            
            Output in this format: 1) A short summary of preferences. 2) List 3-5 destinations, each on its own paragraph with a number, and a blank line between each.
            Each item: Number. **Destination, Country** Reason: Description (1-2 sentences). Use a friendly tone. Leave one blank line between each recommendation.
            """
        }
        
        let messages: [ChatMessage] = [.user([.text(prompt)])]
        let response = try await callChatAPI(messages: messages, model: chatModel)
        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func generateShareOverlayCaption(
        from images: [Data],
        location: String,
        province: String,
        country: String,
        date: Date,
        existingNotes: String?,
        maxLength: Int
    ) async throws -> String {
        print("🤖 [DeepSeek] 开始生成海报短句，地点: \(location)")
        
        let lang = currentLanguage
        let isChineseFamily = (lang == .chinese || lang == .chineseTraditional || lang == .japanese || lang == .korean)
        let season = getSeasonString(from: date, language: lang)
        let note = existingNotes?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let hasNote = !(note?.isEmpty ?? true)
        
        var photoHint: String?
        if let first = images.first {
            photoHint = await analyzeImageWithVision(first)
        }
        
        let locationLine = [location, province, country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: lang == .english ? ", " : "，")
        
        let prompt: String
        if isChineseFamily {
            let noteBlock = hasNote ? "\n用户备注：\(note!)" : ""
            let photoBlock = photoHint.map { "\n照片意境：\($0)" } ?? ""
            prompt = """
            你在为旅行海报写「图上短句」。只输出一句，像摄影明信片旁的诗意旁白。
            
            参考信息（不要把地点名、日期写进句子）：
            - 地点背景：\(locationLine)
            - 季节：\(season)\(noteBlock)\(photoBlock)
            
            硬性要求：
            1. 只输出一句，不要引号、标题、标签、换行或解释
            2. 中文/日文/韩文严格控制在 12～22 字以内（OVERLAY_MAX）
            3. 不要出现地点名、日期、emoji、hashtag
            4. 语气克制、留白，像附图旁那句短旁白
            5. \(LanguageConfig.forLanguage(lang).outputLanguageInstruction)
            """
        } else {
            let noteBlock = hasNote ? "\nUser notes: \(note!)" : ""
            let photoBlock = photoHint.map { "\nPhoto mood: \($0)" } ?? ""
            prompt = """
            Write one short poetic caption for a travel poster (text beside a photo).
            
            Context (do NOT put place names or dates into the sentence):
            - Place: \(locationLine)
            - Season: \(season)\(noteBlock)\(photoBlock)
            
            Rules:
            1. Output ONLY one sentence — no quotes, titles, hashtags, line breaks, or explanation
            2. Keep it within 8–12 words (OVERLAY_MAX), max \(maxLength) characters
            3. No place names, dates, emoji, or hashtags
            4. Quiet, evocative tone — like a postcard line
            5. \(LanguageConfig.forLanguage(lang).outputLanguageInstruction)
            """
        }
        
        let messages: [ChatMessage] = [.user([.text(prompt)])]
        let response = try await callChatAPI(messages: messages, model: chatModel)
        let cleaned = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”‘’"))
            .replacingOccurrences(of: "\n", with: " ")
        return limitTextToLength(cleaned, maxLength: maxLength)
    }
    
    // MARK: - Private Methods
    
    /// 获取当前应用语言
    private var currentLanguage: LanguageManager.Language {
        return LanguageManager.shared.currentLanguage
    }
    
    /// 根据日期获取季节字符串（多语言支持）
    private func getSeasonString(from date: Date, language: LanguageManager.Language) -> String {
        let calendar = Calendar.current
        let month = calendar.component(.month, from: date)
        
        switch month {
        case 3, 4, 5:
            switch language {
            case .chinese, .chineseTraditional:
                return "春天"
            case .english:
                return "spring"
            case .japanese:
                return "春"
            case .korean:
                return "봄"
            case .french:
                return "printemps"
            case .spanish:
                return "primavera"
            case .german:
                return "Frühling"
            }
        case 6, 7, 8:
            switch language {
            case .chinese, .chineseTraditional:
                return "夏天"
            case .english:
                return "summer"
            case .japanese:
                return "夏"
            case .korean:
                return "여름"
            case .french:
                return "été"
            case .spanish:
                return "verano"
            case .german:
                return "Sommer"
            }
        case 9, 10, 11:
            switch language {
            case .chinese, .chineseTraditional:
                return "秋天"
            case .english:
                return "autumn"
            case .japanese:
                return "秋"
            case .korean:
                return "가을"
            case .french:
                return "automne"
            case .spanish:
                return "otoño"
            case .german:
                return "Herbst"
            }
        default: // 12, 1, 2
            switch language {
            case .chinese, .chineseTraditional:
                return "冬天"
            case .english:
                return "winter"
            case .japanese:
                return "冬"
            case .korean:
                return "겨울"
            case .french:
                return "hiver"
            case .spanish:
                return "invierno"
            case .german:
                return "Winter"
            }
        }
    }
    
    /// 获取语言相关的配置信息
    private struct LanguageConfig {
        let languageCode: String
        let defaultIdentity: String
        let dateFormat: String
        let outputLanguageInstruction: String
        let locationLabel: String
        let countryLabel: String
        let visitDateLabel: String
        let photoDescriptionLabel: String
        let photoLabel: String
        let noteLabel: String
        let styleGuidanceLabel: String
        let importantNoteLabel: String
        let requirementsLabel: String
        let wordLimit144: String
        let wordLimit300: String
        
        static func forLanguage(_ language: LanguageManager.Language) -> LanguageConfig {
            switch language {
            case .chinese, .chineseTraditional:
                return LanguageConfig(
                    languageCode: "zh",
                    defaultIdentity: "旅行作家",
                    dateFormat: "yyyy年MM月dd日",
                    outputLanguageInstruction: "使用中文输出",
                    locationLabel: "地点",
                    countryLabel: "国家",
                    visitDateLabel: "访问日期",
                    photoDescriptionLabel: "照片内容描述",
                    photoLabel: "照片",
                    noteLabel: "笔记",
                    styleGuidanceLabel: "**文风指导**（仅用于调整写作风格，不要写入笔记内容）",
                    importantNoteLabel: "**重要提示**",
                    requirementsLabel: "要求",
                    wordLimit144: "**严格限制在144字以内**",
                    wordLimit300: "**严格限制在300字以内**"
                )
            case .english:
                return LanguageConfig(
                    languageCode: "en",
                    defaultIdentity: "travel writer",
                    dateFormat: "MMMM d, yyyy",
                    outputLanguageInstruction: "Use English output",
                    locationLabel: "Location",
                    countryLabel: "Country",
                    visitDateLabel: "Visit Date",
                    photoDescriptionLabel: "Photo Content Description",
                    photoLabel: "Photo",
                    noteLabel: "Notes",
                    styleGuidanceLabel: "**Style Guidance** (only for adjusting writing style, do not include in note content)",
                    importantNoteLabel: "**Important Note**",
                    requirementsLabel: "Requirements",
                    wordLimit144: "**strictly limit to 144 words or less**",
                    wordLimit300: "**strictly limit to 300 words or less**"
                )
            case .japanese:
                return LanguageConfig(
                    languageCode: "ja",
                    defaultIdentity: "旅行作家",
                    dateFormat: "yyyy年MM月dd日",
                    outputLanguageInstruction: "日本語で出力してください",
                    locationLabel: "場所",
                    countryLabel: "国",
                    visitDateLabel: "訪問日",
                    photoDescriptionLabel: "写真の内容説明",
                    photoLabel: "写真",
                    noteLabel: "ノート",
                    styleGuidanceLabel: "**文体指導**（執筆スタイルの調整のみに使用し、ノート内容には記載しないでください）",
                    importantNoteLabel: "**重要な注意**",
                    requirementsLabel: "要件",
                    wordLimit144: "**144文字以内に厳格に制限**",
                    wordLimit300: "**300文字以内に厳格に制限**"
                )
            case .french:
                return LanguageConfig(
                    languageCode: "fr",
                    defaultIdentity: "écrivain de voyage",
                    dateFormat: "d MMMM yyyy",
                    outputLanguageInstruction: "Utilisez le français pour la sortie",
                    locationLabel: "Lieu",
                    countryLabel: "Pays",
                    visitDateLabel: "Date de visite",
                    photoDescriptionLabel: "Description du contenu de la photo",
                    photoLabel: "Photo",
                    noteLabel: "Notes",
                    styleGuidanceLabel: "**Guide de style** (uniquement pour ajuster le style d'écriture, ne pas inclure dans le contenu de la note)",
                    importantNoteLabel: "**Note importante**",
                    requirementsLabel: "Exigences",
                    wordLimit144: "**limiter strictement à 144 mots ou moins**",
                    wordLimit300: "**limiter strictement à 300 mots ou moins**"
                )
            case .spanish:
                return LanguageConfig(
                    languageCode: "es",
                    defaultIdentity: "escritor de viajes",
                    dateFormat: "d 'de' MMMM 'de' yyyy",
                    outputLanguageInstruction: "Use español para la salida",
                    locationLabel: "Ubicación",
                    countryLabel: "País",
                    visitDateLabel: "Fecha de visita",
                    photoDescriptionLabel: "Descripción del contenido de la foto",
                    photoLabel: "Foto",
                    noteLabel: "Notas",
                    styleGuidanceLabel: "**Guía de estilo** (solo para ajustar el estilo de escritura, no incluir en el contenido de la nota)",
                    importantNoteLabel: "**Nota importante**",
                    requirementsLabel: "Requisitos",
                    wordLimit144: "**limitar estrictamente a 144 palabras o menos**",
                    wordLimit300: "**limitar estrictamente a 300 palabras o menos**"
                )
            case .korean:
                return LanguageConfig(
                    languageCode: "ko",
                    defaultIdentity: "여행 작가",
                    dateFormat: "yyyy년 MM월 dd일",
                    outputLanguageInstruction: "한국어로 출력하세요",
                    locationLabel: "장소",
                    countryLabel: "국가",
                    visitDateLabel: "방문 날짜",
                    photoDescriptionLabel: "사진 내용 설명",
                    photoLabel: "사진",
                    noteLabel: "노트",
                    styleGuidanceLabel: "**문체 가이드** (작문 스타일 조정에만 사용하며, 노트 내용에 포함하지 마세요)",
                    importantNoteLabel: "**중요 참고사항**",
                    requirementsLabel: "요구사항",
                    wordLimit144: "**144자 이내로 엄격히 제한**",
                    wordLimit300: "**300자 이내로 엄격히 제한**"
                )
            case .german:
                return LanguageConfig(
                    languageCode: "de",
                    defaultIdentity: "Reiseschriftsteller",
                    dateFormat: "d. MMMM yyyy",
                    outputLanguageInstruction: "Bitte auf Deutsch ausgeben",
                    locationLabel: "Ort",
                    countryLabel: "Land",
                    visitDateLabel: "Besuchsdatum",
                    photoDescriptionLabel: "Beschreibung des Fotoinhalts",
                    photoLabel: "Foto",
                    noteLabel: "Notizen",
                    styleGuidanceLabel: "**Stilhinweis** (nur zur Anpassung des Schreibstils, nicht in den Notizinhalt aufnehmen)",
                    importantNoteLabel: "**Wichtiger Hinweis**",
                    requirementsLabel: "Anforderungen",
                    wordLimit144: "**streng auf maximal 144 Wörter begrenzen**",
                    wordLimit300: "**streng auf maximal 300 Wörter begrenzen**"
                )
            }
        }
    }
    
    /// 调用 DeepSeek Chat API
    private func callChatAPI(messages: [ChatMessage], model: String) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = requestTimeout
        
        // 限制最大token数
        // 对于笔记生成：中文平均每个字约1-2个token，144字约需要200-300 tokens
        // 对于旅程描述：300字约需要400-600 tokens
        // 根据消息内容判断是笔记还是旅程描述
        let promptText = messages.compactMap { msg -> String? in
            if case .user(let items) = msg, let first = items.first, case .text(let text) = first {
                return text
            }
            return nil
        }.joined()
        
        let maxTokens: Int
        if promptText.contains("OVERLAY_MAX") {
            maxTokens = 80   // 海报短句
        } else if promptText.contains("300字") {
            maxTokens = 600  // 旅程描述：300字
        } else if promptText.contains("144字") {
            maxTokens = 300  // 笔记：144字
        } else {
            maxTokens = 1000  // 默认值
        }
        
        let requestBody = ChatCompletionRequest(
            model: model,
            messages: messages,
            temperature: 0.7,
            maxTokens: maxTokens,
            thinking: ThinkingConfig(type: "disabled") // 对齐原 deepseek-chat 非思考行为
        )
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("🤖 [DeepSeek] 发送请求，模型: \(model), 消息数: \(messages.count)")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIError.networkError("无效的HTTP响应")
        }
        
        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "未知错误"
            print("❌ [DeepSeek] API错误，状态码: \(httpResponse.statusCode), 错误: \(errorMessage)")
            throw AIError.apiError("\(httpResponse.statusCode)")
        }
        
        let chatResponse = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        
        guard let content = chatResponse.choices.first?.message.content else {
            throw AIError.invalidResponse("响应中没有内容")
        }
        
        print("✅ [DeepSeek] 请求成功，返回内容长度: \(content.count)")
        
        // 注意：字数限制在各自的生成方法中处理，这里返回原始内容
        return content
    }
    
    // MARK: - Vision API Methods
    
    /// 使用 Apple Vision API 识别图片内容（用于笔记生成）
    /// - Parameter imageData: 图片数据
    /// - Returns: 图片的文字描述
    private func analyzeImageWithVision(_ imageData: Data) async -> String? {
        guard let uiImage = UIImage(data: imageData) else {
            print("❌ [Vision] 无法从Data创建UIImage")
            return nil
        }
        
        guard let cgImage = uiImage.cgImage else {
            print("❌ [Vision] 无法获取CGImage")
            return nil
        }
        
        return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            var descriptions: [String] = []
            var hasResumed = false
            
            // 用于确保只 resume 一次
            let resumeOnce: (String?) -> Void = { result in
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: result)
            }
            
            // 使用 VNRecognizeTextRequest 识别文字
            let textRequest = VNRecognizeTextRequest { request, error in
                if let error = error {
                    print("⚠️ [Vision] 文字识别错误: \(error.localizedDescription)")
                }
                
                if let observations = request.results as? [VNRecognizedTextObservation] {
                    let recognizedStrings = observations.compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    
                    if !recognizedStrings.isEmpty {
                        let ocr = self.truncateForPrompt(
                            recognizedStrings.joined(separator: " "),
                            maxLength: PromptBudget.visionOCRChars
                        )
                        descriptions.append("文字：\(ocr)")
                    }
                }
            }
            textRequest.recognitionLanguages = ["zh-Hans", "en"] // 支持中文和英文
            textRequest.recognitionLevel = .accurate
            
            // 使用 VNClassifyImageRequest 分类图片场景
            let classifyRequest = VNClassifyImageRequest { request, error in
                if let error = error {
                    print("⚠️ [Vision] 图片分类错误: \(error.localizedDescription)")
                }
                
                if let observations = request.results as? [VNClassificationObservation] {
                    // 获取置信度最高的3个分类
                    let topClassifications = observations.prefix(3).compactMap { observation -> String? in
                        guard observation.confidence > 0.3 else { return nil }
                        return observation.identifier
                    }
                    
                    if !topClassifications.isEmpty {
                        descriptions.append("场景：\(topClassifications.joined(separator: "、"))")
                    }
                }
                
                // 在场景分类完成后 resume（这是最后一个请求的回调）
                let result = descriptions.isEmpty ? nil : descriptions.joined(separator: "；")
                resumeOnce(result)
            }
            
            // 执行所有请求（文字识别 + 场景分类）
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([textRequest, classifyRequest])
            } catch {
                print("❌ [Vision] 执行Vision请求失败: \(error.localizedDescription)")
                resumeOnce(nil)
            }
        }
    }
    
    /// 使用 Apple Vision API 识别图片内容（用于详细分析）
    /// - Parameter imageData: 图片数据
    /// - Returns: (描述, 识别的物体列表)
    private func analyzeImageWithVisionForAnalysis(_ imageData: Data) async -> (description: String, observations: [String])? {
        guard let uiImage = UIImage(data: imageData),
              let cgImage = uiImage.cgImage else {
            return nil
        }
        
        return await withCheckedContinuation { continuation in
            var descriptions: [String] = []
            var observations: [String] = []
            
            let textRequest = VNRecognizeTextRequest { request, error in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                let strings = observations.compactMap { $0.topCandidates(1).first?.string }
                if !strings.isEmpty {
                    let ocr = self.truncateForPrompt(
                        strings.joined(separator: " "),
                        maxLength: PromptBudget.visionOCRChars
                    )
                    descriptions.append("文字：\(ocr)")
                }
            }
            textRequest.recognitionLanguages = ["zh-Hans", "en"]
            textRequest.recognitionLevel = .accurate
            
            let classifyRequest = VNClassifyImageRequest { request, error in
                guard let classObservations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: descriptions.isEmpty ? nil : (descriptions.joined(separator: "；"), observations))
                    return
                }
                
                let topClasses = classObservations.prefix(5).compactMap { observation -> String? in
                    guard observation.confidence > 0.3 else { return nil }
                    observations.append(observation.identifier)
                    return observation.identifier
                }
                
                if !topClasses.isEmpty {
                    descriptions.append("场景分类：\(topClasses.joined(separator: "、"))")
                }
                
                continuation.resume(returning: descriptions.isEmpty ? nil : (descriptions.joined(separator: "；"), observations))
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([textRequest, classifyRequest])
            } catch {
                print("❌ [Vision] 执行Vision请求失败: \(error.localizedDescription)")
                continuation.resume(returning: nil)
            }
        }
    }
    
    /// 截断写入 prompt 的辅助文本（OCR / 笔记摘要），避免单次请求输入失控
    private func truncateForPrompt(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        return String(trimmed.prefix(maxLength)) + "…"
    }
    
    /// 限制文本长度在指定字符数以内
    private func limitTextToLength(_ text: String, maxLength: Int) -> String {
        // 中文字符按1个字符计算
        if text.count <= maxLength {
            return text
        }
        
        // 截断到指定长度，尽量在句号、感叹号、问号处截断
        let truncated = String(text.prefix(maxLength))
        
        // 尝试在最后一个标点符号处截断
        let punctuationMarks: [Character] = ["。", "！", "？", "，", ".", "!", "?", ","]
        var bestIndex = truncated.count
        
        for mark in punctuationMarks {
            if let range = truncated.range(of: String(mark), options: .backwards, range: truncated.startIndex..<truncated.endIndex) {
                let index = truncated.distance(from: truncated.startIndex, to: range.upperBound)
                if index <= maxLength && index > max(maxLength - 50, 0) { // 在最后50个字符内寻找
                    bestIndex = index
                    break
                }
            }
        }
        
        return String(truncated.prefix(bestIndex)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 限制文本长度在144个字符（中文）以内
    private func limitTo144Characters(_ text: String) -> String {
        return limitTextToLength(text, maxLength: 144)
    }
    
    /// 限制文本长度在300个字符（中文）以内
    private func limitTo300Characters(_ text: String) -> String {
        return limitTextToLength(text, maxLength: 300)
    }
    
    /// 解析照片分析结果
    private func parseImageAnalysisResult(from jsonString: String) throws -> ImageAnalysisResult {
        // 尝试提取 JSON（可能被 ```json 包裹）
        var jsonStr = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        if jsonStr.hasPrefix("```json") {
            jsonStr = String(jsonStr.dropFirst(7))
        }
        if jsonStr.hasPrefix("```") {
            jsonStr = String(jsonStr.dropFirst(3))
        }
        if jsonStr.hasSuffix("```") {
            jsonStr = String(jsonStr.dropLast(3))
        }
        jsonStr = jsonStr.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard let jsonData = jsonStr.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            // 如果解析失败，返回基础结果
            return ImageAnalysisResult(
                sceneType: nil,
                mainSubjects: [],
                description: jsonString,
                suggestedTags: []
            )
        }
        
        return ImageAnalysisResult(
            sceneType: dict["sceneType"] as? String,
            mainSubjects: dict["mainSubjects"] as? [String] ?? [],
            description: dict["description"] as? String ?? jsonString,
            suggestedTags: dict["suggestedTags"] as? [String] ?? []
        )
    }
}

// MARK: - Data Models

/// 聊天消息
/// 兼容 OpenAI/DeepSeek API 格式
enum ChatMessage: Codable {
    case system(String)
    case user([ContentItem])
    case assistant(String)
    
    var role: String {
        switch self {
        case .system: return "system"
        case .user: return "user"
        case .assistant: return "assistant"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case role, content
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        
        switch self {
        case .system(let text), .assistant(let text):
            // 系统和助手消息：content 是字符串
            try container.encode(text, forKey: .content)
        case .user(let items):
            // 用户消息：content 可以是字符串（纯文本）或数组（混合内容）
            if items.count == 1, case .text(let text) = items.first {
                // 如果只有一个文本项，直接编码为字符串（兼容性更好）
                try container.encode(text, forKey: .content)
            } else {
                // 多个项或包含图片：编码为数组
                try container.encode(items, forKey: .content)
            }
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let role = try container.decode(String.self, forKey: .role)
        
        switch role {
        case "system":
            let text = try container.decode(String.self, forKey: .content)
            self = .system(text)
        case "user":
            // 尝试解码为数组，如果失败则作为字符串
            if let items = try? container.decode([ContentItem].self, forKey: .content) {
                self = .user(items)
            } else if let text = try? container.decode(String.self, forKey: .content) {
                self = .user([.text(text)])
            } else {
                throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode user content"))
            }
        case "assistant":
            let text = try container.decode(String.self, forKey: .content)
            self = .assistant(text)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown role: \(role)"))
        }
    }
}

/// 内容项（支持文本和图片）
/// 兼容 OpenAI/DeepSeek API 格式
enum ContentItem: Codable {
    case text(String)
    case imageURL(String)
    
    var text: String? {
        if case .text(let text) = self {
            return text
        }
        return nil
    }
    
    enum CodingKeys: String, CodingKey {
        case type, text
        case imageURL = "image_url"
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageURL(let url):
            try container.encode("image_url", forKey: .type)
            // OpenAI/DeepSeek 格式：image_url 是一个包含 url 的对象
            let imageURLDict = ImageURLDict(url: url)
            try container.encode(imageURLDict, forKey: .imageURL)
        }
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "text":
            let text = try container.decode(String.self, forKey: .text)
            self = .text(text)
        case "image_url":
            let imageURLDict = try container.decode(ImageURLDict.self, forKey: .imageURL)
            self = .imageURL(imageURLDict.url)
        default:
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unknown type: \(type)"))
        }
    }
    
    /// 图片URL字典结构（符合 OpenAI/DeepSeek 格式）
    private struct ImageURLDict: Codable {
        let url: String
    }
}

/// Chat Completion 请求
struct ChatCompletionRequest: Codable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double
    let maxTokens: Int
    let thinking: ThinkingConfig
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, thinking
        case maxTokens = "max_tokens"
    }
}

/// V4 思考模式配置（disabled 对齐原 deepseek-chat）
struct ThinkingConfig: Codable {
    let type: String
}

/// Chat Completion 响应
struct ChatCompletionResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

/// AI 错误类型
enum AIError: Error, LocalizedError {
    case networkError(String)
    case apiError(String)
    case invalidResponse(String)
    case invalidInput(String)
    case encodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let msg): return "网络错误: \(msg)"
        case .apiError(let msg): return "API错误: \(msg)"
        case .invalidResponse(let msg): return "无效响应: \(msg)"
        case .invalidInput(let msg): return "无效输入: \(msg)"
        case .encodingError(let msg): return "编码错误: \(msg)"
        }
    }
}

