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
        persona _: String,
        mbti _: String,
        gender _: String,
        ageGroup _: String,
        constellation _: String
    ) async throws -> String {
        print("🤖 [DeepSeek] 开始生成笔记，地点: \(location), 省份: \(province), 国家: \(country)")
        
        let language = currentLanguage
        let seasonString = getSeasonString(from: date, language: language)
        let trimmedExistingNotes = truncateForPrompt(
            existingNotes ?? "",
            maxLength: PromptBudget.existingNotesChars
        )
        
        var photoMood: String?
        if !images.isEmpty {
            print("📸 [Vision] 开始使用Apple Vision API识别\(images.count)张照片...")
            var imageDescriptions: [String] = []
            for (index, imageData) in images.prefix(3).enumerated() {
                if let description = await analyzeImageWithVision(imageData) {
                    imageDescriptions.append(description)
                    print("✅ [Vision] 照片\(index + 1)识别成功：\(description.prefix(50))...")
                } else {
                    print("⚠️ [Vision] 照片\(index + 1)识别失败，跳过")
                }
            }
            if imageDescriptions.isEmpty {
                print("⚠️ [Vision] 所有照片识别失败")
            } else {
                photoMood = imageDescriptions.joined(separator: isCJK(language) ? "；" : "; ")
                print("✅ [Vision] 图片识别完成，共识别\(imageDescriptions.count)张照片")
            }
        }
        
        let prompt = makeShortLinePrompt(
            kind: .placeNote,
            language: language,
            place: placeLine(location: location, province: province, country: country, language: language),
            season: seasonString,
            userText: trimmedExistingNotes.isEmpty ? nil : trimmedExistingNotes,
            photoMood: photoMood
        )
        let response = try await callChatAPI(messages: [.user([.text(prompt)])], model: chatModel)
        return finishShortLine(response, language: language)
    }
    
    func generateTripDescription(
        for destinations: [TravelDestination],
        existingDescription: String?,
        persona _: String,
        mbti _: String,
        gender _: String,
        ageGroup _: String,
        constellation _: String
    ) async throws -> String {
        print("🤖 [DeepSeek] 开始生成旅程描述，目的地数量: \(destinations.count)")
        
        guard !destinations.isEmpty else {
            throw AIError.invalidInput("目的地列表为空")
        }
        
        let language = currentLanguage
        let cappedDestinations = Array(destinations.prefix(PromptBudget.maxTripDestinations))
        let seasons = cappedDestinations.map { getSeasonString(from: $0.visitDate, language: language) }
        var orderedSeasons: [String] = []
        var seenSeasons = Set<String>()
        for season in seasons where seenSeasons.insert(season).inserted {
            orderedSeasons.append(season)
        }
        let seasonHint = orderedSeasons.joined(separator: isCJK(language) ? "、" : ", ")
        
        let place = cappedDestinations.map { dest in
            let name = dest.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let country = dest.country.trimmingCharacters(in: .whitespacesAndNewlines)
            if country.isEmpty { return name }
            return "\(name) (\(country))"
        }.joined(separator: isCJK(language) ? "、" : ", ")
        
        var noteSnippets: [String] = []
        for dest in cappedDestinations {
            let note = truncateForPrompt(dest.notes, maxLength: PromptBudget.noteSnippetChars)
            if !note.isEmpty {
                noteSnippets.append(note)
            }
        }
        
        let trimmedExisting = truncateForPrompt(
            existingDescription ?? "",
            maxLength: PromptBudget.existingNotesChars
        )
        
        var photoMoods: [String] = []
        var photoDestinations = 0
        for destination in cappedDestinations where photoDestinations < PromptBudget.maxTripPhotoDestinations {
            guard !destination.photoDatas.isEmpty else { continue }
            photoDestinations += 1
            for imageData in destination.photoDatas.prefix(2) {
                if let description = await analyzeImageWithVision(imageData) {
                    photoMoods.append(description)
                }
            }
        }
        if photoDestinations > 0 {
            print("📸 [Vision] 旅程照片识别完成，有照片的目的地 \(photoDestinations) 个，识别到 \(photoMoods.count) 条意境")
        }
        
        let prompt = makeShortLinePrompt(
            kind: .trip,
            language: language,
            place: place,
            season: seasonHint,
            userText: trimmedExisting.isEmpty ? nil : trimmedExisting,
            photoMood: photoMoods.isEmpty ? nil : photoMoods.joined(separator: isCJK(language) ? "；" : "; "),
            extraLines: noteSnippets.isEmpty ? [] : [
                isCJK(language)
                    ? "- 各地笔记：\(noteSnippets.joined(separator: "；"))"
                    : "- Notes from stops: \(noteSnippets.joined(separator: "; "))"
            ]
        )
        let response = try await callChatAPI(messages: [.user([.text(prompt)])], model: chatModel)
        return finishShortLine(response, language: language)
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
        
        let language = currentLanguage
        let season = getSeasonString(from: date, language: language)
        let note = truncateForPrompt(existingNotes ?? "", maxLength: PromptBudget.existingNotesChars)
        var photoHint: String?
        if let first = images.first {
            photoHint = await analyzeImageWithVision(first)
        }
        
        let prompt = makeShortLinePrompt(
            kind: .poster,
            language: language,
            place: placeLine(location: location, province: province, country: country, language: language),
            season: season,
            userText: note.isEmpty ? nil : note,
            photoMood: photoHint
        )
        let response = try await callChatAPI(messages: [.user([.text(prompt)])], model: chatModel)
        return finishShortLine(response, language: language, characterCap: maxLength)
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
    
    /// 笔记、旅程描述、海报短句共用的一句旁白。
    private enum ShortLineKind {
        case placeNote
        case trip
        case poster
    }
    
    private func isCJK(_ language: LanguageManager.Language) -> Bool {
        switch language {
        case .chinese, .chineseTraditional, .japanese, .korean:
            return true
        case .english, .french, .spanish, .german:
            return false
        }
    }
    
    private func outputLanguageInstruction(for language: LanguageManager.Language) -> String {
        switch language {
        case .chinese, .chineseTraditional:
            return "使用中文输出"
        case .english:
            return "Use English output"
        case .japanese:
            return "日本語で出力してください"
        case .french:
            return "Utilisez le français pour la sortie"
        case .spanish:
            return "Use español para la salida"
        case .korean:
            return "한국어로 출력하세요"
        case .german:
            return "Bitte auf Deutsch ausgeben"
        }
    }
    
    private func placeLine(location: String, province: String, country: String, language: LanguageManager.Language) -> String {
        [location, province, country]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: isCJK(language) ? "，" : ", ")
    }
    
    private func makeShortLinePrompt(
        kind: ShortLineKind,
        language: LanguageManager.Language,
        place: String,
        season: String,
        userText: String?,
        photoMood: String?,
        extraLines: [String] = []
    ) -> String {
        let cjk = isCJK(language)
        let task: String
        switch kind {
        case .placeNote:
            task = cjk ? "为这一处停留写一句" : "Write one line for this stop."
        case .trip:
            task = cjk ? "为整趟旅程写一句，不要罗列地点" : "Write one line for the whole trip. Do not list places."
        case .poster:
            task = cjk ? "为这张照片写一句" : "Write one line for this photo."
        }
        
        var lines: [String] = []
        if !place.isEmpty {
            lines.append(cjk ? "- 地点背景：\(place)" : "- Place: \(place)")
        }
        if !season.isEmpty {
            lines.append(cjk ? "- 季节：\(season)" : "- Season: \(season)")
        }
        if let userText, !userText.isEmpty {
            lines.append(cjk ? "- 用户原文：\(userText)" : "- User text: \(userText)")
        }
        if let photoMood, !photoMood.isEmpty {
            lines.append(cjk ? "- 照片意境：\(photoMood)" : "- Photo mood: \(photoMood)")
        }
        lines.append(contentsOf: extraLines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
        let context = lines.joined(separator: "\n")
        let languageLine = outputLanguageInstruction(for: language)
        
        if cjk {
            return """
            你在写旅行图上短句。只输出一句，像摄影明信片旁的旁白。
            
            任务：\(task)
            参考（不要把地点名、日期写进句子）：
            \(context)
            
            硬性要求：
            1. 只输出一句，不要引号、标题、标签、换行或解释
            2. 严格控制在 12～30 字以内（OVERLAY_MAX）
            3. 不要出现地点名、日期、emoji、hashtag
            4. 语气克制、留白
            5. 若有用户原文，把它收成这一句，不要扩写
            6. \(languageLine)
            """
        }
        return """
        Write one short line for a travel photo, like a postcard caption.
        
        Task: \(task)
        Context (do NOT put place names or dates into the sentence):
        \(context)
        
        Rules:
        1. Output ONLY one sentence — no quotes, titles, hashtags, line breaks, or explanation
        2. Keep it within 8–20 words (OVERLAY_MAX)
        3. No place names, dates, emoji, or hashtags
        4. Quiet, with room to breathe
        5. If the user already wrote text, compress it into this one line
        6. \(languageLine)
        """
    }
    
    private func finishShortLine(_ response: String, language: LanguageManager.Language, characterCap: Int? = nil) -> String {
        let cleaned = response
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"“”‘’「」『』"))
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let limited = isCJK(language)
            ? limitTextToLength(cleaned, maxLength: 30)
            : limitToWordCount(cleaned, maxWords: 20)
        guard let characterCap else { return limited }
        return limitTextToLength(limited, maxLength: characterCap)
    }
    
    /// 调用 DeepSeek Chat API
    private func callChatAPI(messages: [ChatMessage], model: String) async throws -> String {
        let url = URL(string: "\(baseURL)/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = requestTimeout
        
        // 笔记、旅程描述、海报短句的提示词都带 OVERLAY_MAX。
        // 30 个汉字大约 60–90 token，多留一点余量把句子写完。
        let promptText = messages.compactMap { msg -> String? in
            if case .user(let items) = msg, let first = items.first, case .text(let text) = first {
                return text
            }
            return nil
        }.joined()
        
        let maxTokens = promptText.contains("OVERLAY_MAX") ? 128 : 1000
        
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
    
    /// 限制文本长度。超长时只在末尾几个字内认句末标点，避免逗号把短句切碎。
    private func limitTextToLength(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxLength else { return trimmed }
        
        let truncated = String(trimmed.prefix(maxLength))
        let sentenceMarks = CharacterSet(charactersIn: "。！？.!?")
        let windowStart = max(maxLength - 8, 0)
        var bestIndex = truncated.count
        var offset = 0
        for character in truncated {
            offset += 1
            guard offset > windowStart else { continue }
            if String(character).rangeOfCharacter(from: sentenceMarks) != nil {
                bestIndex = offset
            }
        }
        return String(truncated.prefix(bestIndex)).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 拉丁语种按词截断，不切断单词。
    private func limitToWordCount(_ text: String, maxWords: Int) -> String {
        let words = text.split(whereSeparator: { $0.isWhitespace })
        guard words.count > maxWords else { return text }
        return words.prefix(maxWords).joined(separator: " ")
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

