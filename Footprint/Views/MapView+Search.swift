//
//  MapView+Search.swift
//  Footprint
//
//  从 MapView.swift 拆分（编译加速）
//

import SwiftUI
import MapKit
import SwiftData
import CoreLocation
import Combine
import AudioToolbox
import UIKit
import PhotosUI
import Photos
import ImageIO
import Contacts

extension MapView {
    // MARK: - 搜索功能
    
    // 执行搜索
    func performSearch() {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // 获取当前屏幕中心点坐标（用于距离排序）
        let centerCoordinate = visibleRegion?.center
        
        // 使用可复用的搜索辅助类
        LocationSearchHelper.search(
            query: searchText,
            region: visibleRegion,
            centerCoordinate: centerCoordinate
        ) { result in
            DispatchQueue.main.async {
                self.isSearching = false
                
                switch result {
                case .success(let items):
                    self.searchResults = items
                    print("✅ 搜索完成，找到 \(items.count) 个结果（已按距离排序）")
                case .failure(let error):
                    print("❌ 搜索失败: \(error.localizedDescription)")
                    self.searchResults = []
                }
            }
        }
    }
    
    // 选择搜索结果
    func selectSearchResult(_ mapItem: MKMapItem) {
        let coordinate = mapItem.placemark.coordinate
        
        // 移动地图到搜索结果位置
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        
        withAnimation(.easeInOut(duration: 0.8)) {
            mapCameraPosition = .region(region)
        }
        
        // 显示POI预览卡片（与点击地图POI的行为一致）
        // 延迟一点显示，等待地图移动动画开始
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.selectedPOI = mapItem
                self.showingPOIPreview = true
            }
        }
        
        // 关闭搜索栏，但保留搜索结果和搜索文本（用户关闭POI卡片后可以重新打开搜索栏查看其他结果）
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showSearchBar = false
            isSearchFocused = false
            // 注意：不清空 searchText 和 searchResults，这样用户重新打开搜索栏时还能看到结果
        }
        
        print("📍 移动到搜索结果并显示POI预览: \(mapItem.name ?? "未知地点")")
    }
}
