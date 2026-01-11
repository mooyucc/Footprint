//
//  LocalDataBackupManager.swift
//  Footprint
//
//  Created on 2025/11/19.
//

import Foundation
import SwiftData

// MARK: - 数据包模型
struct LocalDataPackage: Codable {
    let exportedAt: Date
    let appVersion: String
    let totalTrips: Int
    let trips: [TripExportData]
    let totalStandaloneDestinations: Int?
    let standaloneDestinations: [TripExportData.DestinationInfo]?
    
    // 向后兼容：旧版本可能没有独立地点字段
    init(exportedAt: Date, appVersion: String, totalTrips: Int, trips: [TripExportData], totalStandaloneDestinations: Int? = nil, standaloneDestinations: [TripExportData.DestinationInfo]? = nil) {
        self.exportedAt = exportedAt
        self.appVersion = appVersion
        self.totalTrips = totalTrips
        self.trips = trips
        self.totalStandaloneDestinations = totalStandaloneDestinations
        self.standaloneDestinations = standaloneDestinations
    }
}

// MARK: - 导入摘要
struct LocalDataImportSummary {
    let importedCount: Int
    let duplicateCount: Int
    let standaloneDestinationsImported: Int
    let failedMessages: [String]
    
    var hasFailures: Bool {
        !failedMessages.isEmpty
    }
}

// MARK: - 错误
enum LocalDataBackupError: LocalizedError {
    case noData
    case emptyPackage
    case readFailed(String)
    case decodeFailed(String)
    case writeFailed(String)
    case unknown(String)
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .noData:
            return "local_backup_no_data".localized
        case .emptyPackage:
            return "local_backup_empty_package".localized
        case .readFailed(let message):
            return "local_backup_read_failed".localized(with: message)
        case .decodeFailed(let message):
            return "local_backup_decode_failed".localized(with: message)
        case .writeFailed(let message):
            return "local_backup_write_failed".localized(with: message)
        case .unknown(let message):
            return "local_backup_unknown_error".localized(with: message)
        case .accessDenied:
            return "local_backup_access_denied".localized
        }
    }
}

// MARK: - 备份管理
enum LocalDataBackupManager {
    
    @MainActor
    static func exportAllTrips(modelContext: ModelContext) -> Result<URL, LocalDataBackupError> {
        do {
            // 获取所有旅程
            let trips = try modelContext.fetch(FetchDescriptor<TravelTrip>())
            
            // 获取所有独立地点（没有关联到任何旅程的地点）
            let allDestinations = try modelContext.fetch(FetchDescriptor<TravelDestination>())
            let standaloneDestinations = allDestinations.filter { $0.trip == nil }
            
            // 如果既没有旅程也没有独立地点，返回错误
            guard !trips.isEmpty || !standaloneDestinations.isEmpty else {
                return .failure(.noData)
            }
            
            // 导出旅程数据
            let tripPayloads = trips.map { TripDataExporter.exportPayload(for: $0) }
            
            // 导出独立地点
            let standalonePayloads = standaloneDestinations.map { TripDataExporter.exportStandaloneDestination($0) }
            
            let package = LocalDataPackage(
                exportedAt: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                totalTrips: tripPayloads.count,
                trips: tripPayloads,
                totalStandaloneDestinations: standalonePayloads.count,
                standaloneDestinations: standalonePayloads
            )
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            let data = try encoder.encode(package)
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withYear, .withMonth, .withDay, .withDashSeparatorInDate, .withTime, .withColonSeparatorInTime]
            let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
            let fileName = "MooFootprint_Backup_\(timestamp).json"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            
            try data.write(to: url, options: .atomic)
            
            return .success(url)
        } catch {
            return .failure(.writeFailed(error.localizedDescription))
        }
    }
    
    @MainActor
    static func importAllTrips(from url: URL, modelContext: ModelContext) -> Result<LocalDataImportSummary, LocalDataBackupError> {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let data = try Data(contentsOf: url)
            return importAllTrips(from: data, modelContext: modelContext)
        } catch {
            let nsError = error as NSError
            if nsError.domain == NSCocoaErrorDomain && nsError.code == CocoaError.fileReadNoPermission.rawValue {
                return .failure(.accessDenied)
            }
            return .failure(.readFailed(error.localizedDescription))
        }
    }
    
    @MainActor
    static func importAllTrips(from data: Data, modelContext: ModelContext) -> Result<LocalDataImportSummary, LocalDataBackupError> {
        do {
            let package = try JSONDecoder().decode(LocalDataPackage.self, from: data)
            
            // 检查数据包是否为空
            guard !package.trips.isEmpty || !(package.standaloneDestinations?.isEmpty ?? true) else {
                return .failure(.emptyPackage)
            }
            
            var imported = 0
            var duplicates = 0
            var standaloneImported = 0
            var failures: [String] = []
            
            // 导入旅程
            for tripData in package.trips {
                let result = TripDataImporter.importTrip(from: tripData, modelContext: modelContext)
                switch result {
                case .success:
                    imported += 1
                case .duplicate:
                    duplicates += 1
                case .error(let message):
                    failures.append("旅程「\(tripData.trip.name)」: \(message)")
                }
            }
            
            // 导入独立地点
            for destInfo in package.standaloneDestinations ?? [] {
                let result = TripDataImporter.importStandaloneDestination(from: destInfo, modelContext: modelContext)
                switch result {
                case .success:
                    standaloneImported += 1
                case .duplicate:
                    // 独立地点重复不算错误，只是跳过
                    break
                case .error(let message):
                    failures.append("独立地点「\(destInfo.name)」: \(message)")
                }
            }
            
            return .success(
                LocalDataImportSummary(
                    importedCount: imported,
                    duplicateCount: duplicates,
                    standaloneDestinationsImported: standaloneImported,
                    failedMessages: failures
                )
            )
        } catch {
            return .failure(.decodeFailed(error.localizedDescription))
        }
    }
}

