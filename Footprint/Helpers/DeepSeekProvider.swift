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
    
    // DeepSeek 模型配置
    private let chatModel = "deepseek-chat"  // 文本生成模型
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
                       currentLanguage == .spanish ? "es_ES" : "en_US"
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
        
        // 构建prompt开头（根据语言）
        var promptText: String
        if currentLanguage == .english {
            promptText = "You are a \(identity). Generate a travel note based on the following information:\n- \(locationInfo)\n- \(langConfig.visitDateLabel)\(separator)\(dateString)"
        } else {
            promptText = "你是一位\(identity)。根据以下信息生成一段旅行笔记：\n- \(locationInfo)\n- \(langConfig.visitDateLabel)\(separator)\(dateString)"
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
                promptText += "\n\n\(langConfig.importantNoteLabel): Please strictly follow the location information provided above (\(location)\(province.isEmpty ? "" : ", \(province)"), \(country)) to generate the note. Even if the photos may contain information or features of other locations, you must use the provided location information and not infer or guess the location from the photos.\n\nBased on the above information, especially the photo content descriptions, generate a travel note, \(langConfig.wordLimit144). \(langConfig.requirementsLabel):\n1. **Must use the provided location information (\(location)\(province.isEmpty ? "" : ", \(province)"), \(country)), do not use other location names that may appear in the photos**\n2. Combine the scenes and content actually seen in the photos (but the location must be \(location))\n3. Combine the characteristics and cultural background of this location\n4. Reflect local culture or natural features\n5. Natural and fluent language with personal feelings\n6. \(langConfig.outputLanguageInstruction)\n7. **Do not mention identity tags, MBTI, gender, age group, constellation and other user attribute information, only write pure travel note content**\n8. **Important: Word count must be strictly controlled within 144 words, do not exceed**"
            } else {
                let comma = currentLanguage == .chinese || currentLanguage == .chineseTraditional || currentLanguage == .japanese || currentLanguage == .korean ? "，" : ", "
                promptText += "\n\n\(langConfig.importantNoteLabel)：请严格按照上面提供的地点信息（\(location)\(province.isEmpty ? "" : "\(comma)\(province)")，\(country)）生成笔记。即使照片中可能包含其他地点的信息或特征，也必须使用提供的地点信息，不要从照片中推断或猜测地点。\n\n请根据以上信息，特别是照片内容描述，生成一段旅行笔记，\(langConfig.wordLimit144)。\(langConfig.requirementsLabel)：\n1. **必须使用提供的地点信息（\(location)\(province.isEmpty ? "" : "\(comma)\(province)")，\(country)），不要使用照片中可能出现的其他地点名称**\n2. 结合照片中实际看到的场景和内容（但地点必须是\(location)）\n3. 结合这个地点的特色和文化背景\n4. 体现当地文化或自然风貌\n5. 语言自然流畅，带有个人感受\n6. \(langConfig.outputLanguageInstruction)\n7. **不要提及身份标签、MBTI、性别、年龄段、星座等用户属性信息，只写纯粹的旅行笔记内容**\n8. **重要：字数必须严格控制在144字以内，不要超过**"
            }
        } else {
            // 构建本地化的prompt结尾（无照片的情况）
            if currentLanguage == .english {
                let comma = province.isEmpty ? "" : ", \(province)"
                promptText += "\n\nGenerate a travel note, \(langConfig.wordLimit144). \(langConfig.requirementsLabel):\n1. Describe the characteristics of this location (\(location)\(comma), \(country))\n2. Reflect local culture or natural features\n3. Natural and fluent language with personal feelings\n4. \(langConfig.outputLanguageInstruction)\n5. **Do not mention identity tags, MBTI, gender, age group, constellation and other user attribute information, only write pure travel note content**\n6. **Important: Word count must be strictly controlled within 144 words, do not exceed**"
            } else {
                let comma = currentLanguage == .chinese || currentLanguage == .chineseTraditional || currentLanguage == .japanese || currentLanguage == .korean ? "，" : ", "
                promptText += "\n\n请生成一段旅行笔记，\(langConfig.wordLimit144)。\(langConfig.requirementsLabel)：\n1. 描述这个地点（\(location)\(province.isEmpty ? "" : "\(comma)\(province)")，\(country)）的特色\n2. 体现当地文化或自然风貌\n3. 语言自然流畅，带有个人感受\n4. \(langConfig.outputLanguageInstruction)\n5. **不要提及身份标签、MBTI、性别、年龄段、星座等用户属性信息，只写纯粹的旅行笔记内容**\n6. **重要：字数必须严格控制在144字以内，不要超过**"
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
        
        // 构建目的地信息（包含笔记）
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = currentLanguage == .english ? "MMMM d, yyyy" : "yyyy-MM-dd"
        let localeId = currentLanguage == .chinese || currentLanguage == .chineseTraditional ? "zh_CN" : 
                       currentLanguage == .japanese ? "ja_JP" : 
                       currentLanguage == .korean ? "ko_KR" : 
                       currentLanguage == .french ? "fr_FR" : 
                       currentLanguage == .spanish ? "es_ES" : "en_US"
        dateFormatter.locale = Locale(identifier: localeId)
        
        let separator = currentLanguage == .english ? ": " : "："
        var destinationsInfo = destinations.map { dest in
            let dateStr = dateFormatter.string(from: dest.visitDate)
            var info = "- \(dest.name) (\(dest.country)) - \(dateStr)"
            // 如果有笔记，添加到信息中
            if !dest.notes.isEmpty {
                info += "\n  \(langConfig.noteLabel)\(separator)\(dest.notes)"
            }
            return info
        }.joined(separator: "\n\n")
        
        // 收集所有目的地的照片
        var allImages: [(destination: String, images: [Data])] = []
        for destination in destinations {
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
                promptText += "\n\nBased on the above information, especially the photo content descriptions and notes from various locations, generate an overall trip description, \(langConfig.wordLimit300). \(langConfig.requirementsLabel):\n1. Combine the scenes and content actually seen in the photos\n2. Reference the notes from various locations to reflect the coherence and characteristics of the trip\n3. Natural and fluent language with personal feelings\n4. \(langConfig.outputLanguageInstruction)\n5. **Do not mention identity tags, MBTI, gender, age group, constellation and other user attribute information, only write pure trip description content**\n6. **Important: Word count must be strictly controlled within 300 words, do not exceed**"
            } else {
                promptText += "\n\n请根据以上信息，特别是照片内容描述和各个地点的笔记，生成一段旅程整体描述，\(langConfig.wordLimit300)。\(langConfig.requirementsLabel)：\n1. 结合照片中实际看到的场景和内容\n2. 参考各个地点的笔记内容，体现旅程的连贯性和特色\n3. 语言自然流畅，带有个人感受\n4. \(langConfig.outputLanguageInstruction)\n5. **不要提及身份标签、MBTI、性别、年龄段、星座等用户属性信息，只写纯粹的旅程描述内容**\n6. **重要：字数必须严格控制在300字以内，不要超过**"
            }
        } else {
            // 构建本地化的prompt结尾（无照片的情况）
            if currentLanguage == .english {
                promptText += "\n\nBased on the above information, especially the notes from various locations, generate an overall trip description, \(langConfig.wordLimit300). \(langConfig.requirementsLabel):\n1. Reference the notes from various locations to reflect the coherence and characteristics of the trip\n2. Natural and fluent language with personal feelings\n3. \(langConfig.outputLanguageInstruction)\n4. **Do not mention identity tags, MBTI, gender, age group, constellation and other user attribute information, only write pure trip description content**\n5. **Important: Word count must be strictly controlled within 300 words, do not exceed**"
            } else {
                promptText += "\n\n请根据以上信息，特别是各个地点的笔记，生成一段旅程整体描述，\(langConfig.wordLimit300)。\(langConfig.requirementsLabel)：\n1. 参考各个地点的笔记内容，体现旅程的连贯性和特色\n2. 语言自然流畅，带有个人感受\n3. \(langConfig.outputLanguageInstruction)\n4. **不要提及身份标签、MBTI、性别、年龄段、星座等用户属性信息，只写纯粹的旅程描述内容**\n5. **重要：字数必须严格控制在300字以内，不要超过**"
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
    
    func generateTags(
        for destination: TravelDestination
    ) async throws -> [String] {
        print("🤖 [DeepSeek] 开始生成标签，地点: \(destination.name)")
        
        let messages: [ChatMessage] = [
            .user([.text("根据以下目的地信息，生成3-5个标签：\n- 地点：\(destination.name)\n- 国家：\(destination.country)\n- 笔记：\(destination.notes ?? "无")\n\n请生成标签，每个标签2-4个字，使用中文，以逗号分隔。例如：文化, 历史, 建筑, 推荐")])
        ]
        
        let response = try await callChatAPI(messages: messages, model: chatModel)
        
        // 解析标签（逗号分隔）
        let tags = response
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        return Array(tags.prefix(5)) // 最多5个标签
    }
    
    // MARK: - Private Methods
    
    /// 获取当前应用语言
    private var currentLanguage: LanguageManager.Language {
        return LanguageManager.shared.currentLanguage
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
        if promptText.contains("300字") {
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
            maxTokens: maxTokens
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
            throw AIError.apiError("API错误: \(httpResponse.statusCode)")
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
                        descriptions.append("文字：\(recognizedStrings.joined(separator: " "))")
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
                    descriptions.append("文字：\(strings.joined(separator: " "))")
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

