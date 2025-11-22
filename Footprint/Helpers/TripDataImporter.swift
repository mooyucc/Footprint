//
//  TripDataImporter.swift
//  Footprint
//
//  Created on 2025/10/20.
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct TripDataImporter {
    
    /// 从URL导入旅程数据
    static func importTrip(from url: URL, modelContext: ModelContext) -> ImportResult {
        // 获取文件访问权限
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let jsonData = try Data(contentsOf: url)
            let exportData = try JSONDecoder().decode(TripExportData.self, from: jsonData)
            return importTrip(from: exportData, modelContext: modelContext)
        } catch {
            print("导入旅程数据失败: \(error)")
            return .error(error.localizedDescription)
        }
    }
    
    /// 从Data导入旅程数据
    static func importTrip(from data: Data, modelContext: ModelContext) -> ImportResult {
        do {
            let exportData = try JSONDecoder().decode(TripExportData.self, from: data)
            return importTrip(from: exportData, modelContext: modelContext)
        } catch {
            print("导入旅程数据失败: \(error)")
            return .error(error.localizedDescription)
        }
    }
    
    /// 通过导出数据导入旅程
    static func importTrip(from exportData: TripExportData, modelContext: ModelContext) -> ImportResult {
        do {
            // 检查是否已存在相同名称的旅程
            let existingTrip = try modelContext.fetch(
                FetchDescriptor<TravelTrip>(
                    predicate: #Predicate { $0.name == exportData.trip.name }
                )
            ).first
            
            if let existingTrip = existingTrip {
                return .duplicate(existingTrip)
            }
            
            // 创建新旅程
            let newTrip = TravelTrip(
                name: exportData.trip.name,
                desc: exportData.trip.desc,
                startDate: exportData.trip.startDate,
                endDate: exportData.trip.endDate,
                coverPhotoData: exportData.trip.coverPhotoData
            )
            
            // 创建目的地，检查重复
            var destinations: [TravelDestination] = []
            for destInfo in exportData.destinations {
                // 检查是否已存在相同的目的地（名称、国家、坐标相同）
                let existingDestination = try modelContext.fetch(
                    FetchDescriptor<TravelDestination>(
                        predicate: #Predicate { destination in
                            destination.name == destInfo.name &&
                            destination.country == destInfo.country &&
                            destination.latitude >= destInfo.latitude - 0.001 &&
                            destination.latitude <= destInfo.latitude + 0.001 &&
                            destination.longitude >= destInfo.longitude - 0.001 &&
                            destination.longitude <= destInfo.longitude + 0.001
                        }
                    )
                ).first
                
                if let existingDestination = existingDestination {
                    // 如果目的地已存在，将其添加到新旅程中
                    existingDestination.trip = newTrip
                    destinations.append(existingDestination)
                } else {
                    // 创建新目的地
                    let destination = TravelDestination(
                        name: destInfo.name,
                        country: destInfo.country,
                        latitude: destInfo.latitude,
                        longitude: destInfo.longitude,
                        visitDate: destInfo.visitDate,
                        notes: destInfo.notes,
                        photoData: destInfo.photoData,
                        photoDatas: destInfo.photoDatas ?? [],
                        photoThumbnailData: destInfo.photoThumbnailData,
                        photoThumbnailDatas: destInfo.photoThumbnailDatas ?? [],
                        category: destInfo.category,
                        isFavorite: destInfo.isFavorite
                    )
                    destination.trip = newTrip
                    destinations.append(destination)
                }
            }
            
            // 设置关联关系
            newTrip.destinations = destinations
            
            // 保存到数据库
            modelContext.insert(newTrip)
            for destination in destinations {
                // 只插入新创建的目的地，已存在的目的地不需要重复插入
                if destination.modelContext == nil {
                    modelContext.insert(destination)
                }
            }
            
            try modelContext.save()
            
            return .success(newTrip)
        } catch {
            print("导入旅程数据失败: \(error)")
            return .error(error.localizedDescription)
        }
    }
    
    /// 验证文件是否为有效的旅程数据
    static func validateTripFile(at url: URL) -> Bool {
        // 获取文件访问权限
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let jsonData = try Data(contentsOf: url)
            _ = try JSONDecoder().decode(TripExportData.self, from: jsonData)
            return true
        } catch {
            return false
        }
    }
}

// MARK: - 导入结果枚举
enum ImportResult {
    case success(TravelTrip)
    case duplicate(TravelTrip)
    case error(String)
    
    var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    var isDuplicate: Bool {
        if case .duplicate = self {
            return true
        }
        return false
    }
    
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
    
    var trip: TravelTrip? {
        switch self {
        case .success(let trip), .duplicate(let trip):
            return trip
        case .error:
            return nil
        }
    }
    
    var errorMessage: String? {
        if case .error(let message) = self {
            return message
        }
        return nil
    }
}

// MARK: - 文件选择器
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.json])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // 开始访问文件（权限会在 importTrip 方法中管理）
            _ = url.startAccessingSecurityScopedResource()
            
            parent.selectedURL = url
            parent.dismiss()
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}
