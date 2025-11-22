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
}

// MARK: - 导入摘要
struct LocalDataImportSummary {
    let importedCount: Int
    let duplicateCount: Int
    let failedMessages: [String]
    
    var hasFailures: Bool {
        !failedMessages.isEmpty
    }
}

// MARK: - 错误
enum LocalDataBackupError: LocalizedError {
    case noTrips
    case emptyPackage
    case readFailed(String)
    case decodeFailed(String)
    case writeFailed(String)
    case unknown(String)
    case accessDenied
    
    var errorDescription: String? {
        switch self {
        case .noTrips:
            return "local_backup_no_trips".localized
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
            let trips = try modelContext.fetch(FetchDescriptor<TravelTrip>())
            guard !trips.isEmpty else {
                return .failure(.noTrips)
            }
            
            let payloads = trips.map { TripDataExporter.exportPayload(for: $0) }
            let package = LocalDataPackage(
                exportedAt: Date(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
                totalTrips: payloads.count,
                trips: payloads
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
            guard !package.trips.isEmpty else {
                return .failure(.emptyPackage)
            }
            
            var imported = 0
            var duplicates = 0
            var failures: [String] = []
            
            for tripData in package.trips {
                let result = TripDataImporter.importTrip(from: tripData, modelContext: modelContext)
                switch result {
                case .success:
                    imported += 1
                case .duplicate:
                    duplicates += 1
                case .error(let message):
                    failures.append(message)
                }
            }
            
            return .success(
                LocalDataImportSummary(
                    importedCount: imported,
                    duplicateCount: duplicates,
                    failedMessages: failures
                )
            )
        } catch {
            return .failure(.decodeFailed(error.localizedDescription))
        }
    }
}

