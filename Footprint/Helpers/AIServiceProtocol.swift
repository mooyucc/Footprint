//
//  AIServiceProtocol.swift
//  Footprint
//
//  Created on 2025/01/27.
//  AI服务协议定义
//

import Foundation

/// AI服务协议
/// 定义了AI功能的标准接口，支持不同的实现（DeepSeek、Apple Intelligence等）
protocol AIServiceProtocol {
    /// 生成旅行笔记
    /// - Parameters:
    ///   - images: 照片数据数组
    ///   - location: 地点名称
    ///   - province: 省份/州（可选）
    ///   - country: 国家/地区
    ///   - date: 访问日期
    ///   - persona: 用户身份标签（用于个性化文风）
    ///   - mbti: 用户 MBTI 标签（用于个性化文风）
    ///   - gender: 用户性别（用于个性化文风）
    ///   - ageGroup: 用户年龄段（用于个性化文风）
    ///   - constellation: 用户星座（用于个性化文风）
    /// - Returns: 生成的笔记文本
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
    ) async throws -> String
    
    /// 生成旅程描述
    /// - Parameters:
    ///   - destinations: 目的地列表
    ///   - persona: 用户身份标签（用于个性化文风）
    ///   - mbti: 用户 MBTI 标签（用于个性化文风）
    ///   - gender: 用户性别（用于个性化文风）
    ///   - ageGroup: 用户年龄段（用于个性化文风）
    ///   - constellation: 用户星座（用于个性化文风）
    /// - Returns: 生成的旅程描述
    func generateTripDescription(
        for destinations: [TravelDestination],
        persona: String,
        mbti: String,
        gender: String,
        ageGroup: String,
        constellation: String
    ) async throws -> String
    
    /// 分析照片内容
    /// - Parameter images: 照片数据数组
    /// - Returns: 照片分析结果
    func analyzeImages(_ images: [Data]) async throws -> ImageAnalysisResult
    
    /// 生成标签
    /// - Parameter destination: 目的地
    /// - Returns: 生成的标签数组
    func generateTags(
        for destination: TravelDestination
    ) async throws -> [String]
}

/// 照片分析结果
struct ImageAnalysisResult {
    /// 场景类型（如：自然、城市、建筑、美食等）
    let sceneType: String?
    /// 识别的主要物体或地标
    let mainSubjects: [String]
    /// 照片描述
    let description: String
    /// 建议的标签
    let suggestedTags: [String]
}

