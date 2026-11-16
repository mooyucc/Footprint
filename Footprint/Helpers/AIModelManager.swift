//
//  AIModelManager.swift
//  Footprint
//
//  Created on 2025/01/27.
//  AI服务统一管理器
//

import Foundation
import SwiftUI
import SwiftData
import Combine

/// AI模型管理器
/// 统一管理AI服务，支持不同的AI提供商（DeepSeek、Apple Intelligence等）
@MainActor
final class AIModelManager: ObservableObject {
    static let shared = AIModelManager()
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var service: AIServiceProtocol
    private let userProfileManager = UserProfileManager.shared
    
    /// 初始化AI管理器
    /// - Parameter service: 可选的AI服务实例，如果为nil则自动选择合适的服务
    init(service: AIServiceProtocol? = nil) {
        if let service = service {
            self.service = service
            print("🤖 [AIModelManager] 使用自定义AI服务")
        } else {
            // 默认使用DeepSeek（针对中国用户优化）
            self.service = DeepSeekProvider.shared
            print("🤖 [AIModelManager] 使用DeepSeek服务（默认）")
            
            // TODO: iOS 18+ 时可以检测并优先使用Apple Intelligence
            // if #available(iOS 18.0, *), isAppleIntelligenceAvailable() {
            //     self.service = AppleIntelligenceProvider()
            //     print("🤖 [AIModelManager] 使用Apple Intelligence服务")
            // }
        }
    }
    
    // MARK: - Public Methods
    
    /// 为目的地生成笔记
    func generateNotesFor(destination: TravelDestination) async -> String? {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // 获取照片数据
            let images = destination.photoDatas ?? []
            
            // 获取用户已输入的笔记（如果存在）
            let trimmedNotes = destination.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let existingNotes: String? = trimmedNotes.isEmpty ? nil : trimmedNotes
            let hasExistingNotes = !trimmedNotes.isEmpty
            
            if hasExistingNotes {
                print("📝 [AIModelManager] 检测到用户已输入笔记，将进行美化处理")
            }
            
            // 调用AI服务生成笔记
            let notes = try await service.generateNotes(
                from: images,
                location: destination.name,
                province: destination.province,
                country: destination.country,
                date: destination.visitDate,
                existingNotes: existingNotes,
                persona: userProfileManager.personaTag,
                mbti: userProfileManager.mbtiType,
                gender: userProfileManager.gender,
                ageGroup: userProfileManager.ageGroup,
                constellation: userProfileManager.constellation
            )
            
            print("✅ [AIModelManager] 笔记生成成功，长度: \(notes.count)")
            return notes
            
        } catch {
            let errorMsg = error.localizedDescription
            errorMessage = errorMsg
            print("❌ [AIModelManager] 笔记生成失败: \(errorMsg)")
            return nil
        }
    }
    
    /// 为旅程生成描述
    func generateDescriptionFor(trip: TravelTrip) async -> String? {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            // 获取旅程的所有目的地
            guard let destinations = trip.destinations?.sorted(by: { $0.visitDate < $1.visitDate }) else {
                throw AIError.invalidInput("旅程中没有目的地")
            }
            
            guard !destinations.isEmpty else {
                throw AIError.invalidInput("目的地列表为空")
            }
            
            // 获取用户已输入的旅程描述（如果存在）
            let trimmedDesc = trip.desc.trimmingCharacters(in: .whitespacesAndNewlines)
            let existingDescription: String? = trimmedDesc.isEmpty ? nil : trimmedDesc
            let hasExistingDescription = !trimmedDesc.isEmpty
            
            if hasExistingDescription {
                print("📝 [AIModelManager] 检测到用户已输入旅程描述，将进行美化处理")
            }
            
            // 调用AI服务生成描述
            let description = try await service.generateTripDescription(
                for: destinations,
                existingDescription: existingDescription,
                persona: userProfileManager.personaTag,
                mbti: userProfileManager.mbtiType,
                gender: userProfileManager.gender,
                ageGroup: userProfileManager.ageGroup,
                constellation: userProfileManager.constellation
            )
            
            print("✅ [AIModelManager] 旅程描述生成成功，长度: \(description.count)")
            return description
            
        } catch {
            let errorMsg = error.localizedDescription
            errorMessage = errorMsg
            print("❌ [AIModelManager] 旅程描述生成失败: \(errorMsg)")
            return nil
        }
    }
    
    /// 分析照片
    func analyzeImages(_ images: [Data]) async -> ImageAnalysisResult? {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let result = try await service.analyzeImages(images)
            print("✅ [AIModelManager] 照片分析成功")
            return result
        } catch {
            let errorMsg = error.localizedDescription
            errorMessage = errorMsg
            print("❌ [AIModelManager] 照片分析失败: \(errorMsg)")
            return nil
        }
    }
    
    /// 为目的地分享海报生成图上短句
    func generateShareOverlayCaption(for destination: TravelDestination, maxLength: Int = 40) async -> String? {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            let images = destination.photoDatas ?? []
            let trimmedNotes = destination.notes.trimmingCharacters(in: .whitespacesAndNewlines)
            let existingNotes: String? = trimmedNotes.isEmpty ? nil : trimmedNotes
            
            let caption = try await service.generateShareOverlayCaption(
                from: images,
                location: destination.name,
                province: destination.province,
                country: destination.country,
                date: destination.visitDate,
                existingNotes: existingNotes,
                maxLength: maxLength
            )
            print("✅ [AIModelManager] 海报短句生成成功，长度: \(caption.count)")
            return caption
        } catch {
            let errorMsg = error.localizedDescription
            errorMessage = errorMsg
            print("❌ [AIModelManager] 海报短句生成失败: \(errorMsg)")
            return nil
        }
    }
    
    /// 根据已记录的目的地推荐下一站旅行目的地
    func recommendNextDestinations(from destinations: [TravelDestination]) async -> String? {
        isLoading = true
        errorMessage = nil
        
        defer {
            isLoading = false
        }
        
        do {
            guard !destinations.isEmpty else {
                errorMessage = "没有已记录的目的地"
                return nil
            }
            let text = try await service.recommendNextDestinations(from: destinations)
            print("✅ [AIModelManager] 旅行目的地推荐成功，长度: \(text.count)")
            return text
        } catch {
            let errorMsg = error.localizedDescription
            errorMessage = errorMsg
            print("❌ [AIModelManager] 旅行目的地推荐失败: \(errorMsg)")
            return nil
        }
    }
}

