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
    ///   - existingNotes: 用户已写的笔记（如果有，收成一句短句，不扩写）
    ///   - persona: 保留给调用方，短句提示词不使用
    ///   - mbti: 保留给调用方，短句提示词不使用
    ///   - gender: 保留给调用方，短句提示词不使用
    ///   - ageGroup: 保留给调用方，短句提示词不使用
    ///   - constellation: 保留给调用方，短句提示词不使用
    /// - Returns: 一句旅行短句
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
    ) async throws -> String
    
    /// 生成旅程描述
    /// - Parameters:
    ///   - destinations: 目的地列表
    ///   - existingDescription: 用户已写的旅程描述（如果有，收成一句短句，不扩写）
    ///   - persona: 保留给调用方，短句提示词不使用
    ///   - mbti: 保留给调用方，短句提示词不使用
    ///   - gender: 保留给调用方，短句提示词不使用
    ///   - ageGroup: 保留给调用方，短句提示词不使用
    ///   - constellation: 保留给调用方，短句提示词不使用
    /// - Returns: 一句旅程短句
    func generateTripDescription(
        for destinations: [TravelDestination],
        existingDescription: String?,
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
    
    /// 根据已记录的目的地推荐下一站旅行目的地
    /// - Parameter destinations: 用户已记录的目的地列表
    /// - Returns: 推荐结果文本（包含推荐目的地及理由）
    func recommendNextDestinations(from destinations: [TravelDestination]) async throws -> String
    
    /// 生成分享海报图上短句（一句，偏诗意，不写进地点/日期）
    /// - Parameters:
    ///   - images: 照片数据（可空；有图时用首张辅助意境）
    ///   - location: 地点名称
    ///   - province: 省份/州（可选）
    ///   - country: 国家/地区
    ///   - date: 访问日期
    ///   - existingNotes: 用户备注（可空；有则优先提炼）
    ///   - maxLength: 版式上的字符硬上限，会再与短句字数预算取较严的一边
    /// - Returns: 单句短文案
    func generateShareOverlayCaption(
        from images: [Data],
        location: String,
        province: String,
        country: String,
        date: Date,
        existingNotes: String?,
        maxLength: Int
    ) async throws -> String
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

