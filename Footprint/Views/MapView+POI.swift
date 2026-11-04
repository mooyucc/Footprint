//
//  MapView+POI.swift
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
    func searchPOIAtCoordinate(_ coordinate: CLLocationCoordinate2D, isUserInitiated: Bool = false) {
        // 优化：先尝试小范围精确搜索，找不到再扩大范围
        searchPOIAtCoordinate(coordinate, searchSpan: nil, isRetry: false, isUserInitiated: isUserInitiated)
    }
    
    // 统一显示POI结果：智能处理加载状态
    func showPOIResult(_ mapItem: MKMapItem, message: String? = nil) {
        // 取消延迟显示加载卡片的任务（如果结果返回得很快，就不显示加载状态）
        loadingTaskHolder.task?.cancel()
        loadingTaskHolder.task = nil
        
        if let message = message {
            print(message)
        }
        
        // 检查是否已经显示了加载状态
        if isSearchingPOI {
            // 如果已显示加载状态，先隐藏它，然后显示结果（平滑过渡）
            withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                self.isSearchingPOI = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    self.selectedPOI = mapItem
                    self.showingPOIPreview = true
                }
            }
        } else {
            // 如果没显示加载状态（快速返回），直接显示结果
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                self.selectedPOI = mapItem
                self.showingPOIPreview = true
            }
        }
    }
    
    // 优化的POI搜索方法：支持渐进式搜索策略和多种搜索方式
    func searchPOIAtCoordinate(_ coordinate: CLLocationCoordinate2D, searchSpan: MKCoordinateSpan?, isRetry: Bool, isUserInitiated: Bool = false) {
        // 只在首次搜索时设置延迟显示加载状态（重试时不重新设置）
        if !isRetry {
            // 记录搜索开始时间
            poiSearchStartTime = Date()
            
            // 取消之前的延迟显示任务
            loadingTaskHolder.task?.cancel()
            
            // 用户主动点击时，立即显示加载状态（不等待300ms），提供即时反馈
            if isUserInitiated {
                withAnimation(.easeIn(duration: 0.1)) {
                    isSearchingPOI = true
                }
            } else {
                // 延迟显示加载卡片：如果搜索很快完成（300ms内），就不显示加载状态
                let task = DispatchWorkItem {
                    // 检查是否已经显示了结果，如果没有才显示加载状态
                    if !showingPOIPreview && selectedPOI == nil {
                        withAnimation(.easeIn(duration: 0.2)) {
                            isSearchingPOI = true
                        }
                    }
                }
                loadingTaskHolder.task = task
                DispatchQueue.main.asyncAfter(deadline: .now() + showLoadingThreshold, execute: task)
            }
        }
        
        // 判断是否在中国境内
        let isInChina = CoordinateConverter.isInChina(coordinate)
        
        // 优化：在中国使用高德API，其他地区使用Apple MapKit
        if isInChina && !isRetry {
            // 在中国：使用高德API进行POI搜索（更可靠，识别率更高）
            searchPOIWithGeocodeService(coordinate: coordinate, isUserInitiated: isUserInitiated)
            return
        }
        
        let request = MKLocalSearch.Request()
        
        // 搜索范围策略：先小范围精确搜索，失败后再扩大范围
        let span: MKCoordinateSpan
        if let providedSpan = searchSpan {
            span = providedSpan
        } else {
            // 首次搜索：使用较小范围提高精度
            if isInChina {
                span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) // 中国使用稍大范围
            } else {
                span = MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003) // 约300米范围
            }
        }
        
        // 优化：设置region而不是只设置naturalLanguageQuery
        request.region = MKCoordinateRegion(center: coordinate, span: span)
        
        // 优化：在中国，不设置naturalLanguageQuery可能导致错误，尝试不设置region但设置查询词
        // 但这里我们通过反向地理编码先获取POI名称，然后再搜索
        if #available(iOS 13.0, *) {
            // 优先搜索POI
            request.resultTypes = [.pointOfInterest, .address]
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                // 取消延迟显示加载卡片的任务
                self.loadingTaskHolder.task?.cancel()
                self.loadingTaskHolder.task = nil
                
                if let error = error {
                    // 如果已经显示了加载状态，先隐藏它
                    if self.isSearchingPOI {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                            self.isSearchingPOI = false
                        }
                    }
                    
                    // 详细错误信息
                    let nsError = error as NSError
                    print("❌ POI搜索失败:")
                    print("   错误描述: \(error.localizedDescription)")
                    print("   错误代码: \(nsError.code)")
                    print("   错误域: \(nsError.domain)")
                    
                    // 如果不是重试且搜索范围较小，尝试扩大范围重试
                    if !isRetry {
                        let largerSpan = MKCoordinateSpan(
                            latitudeDelta: span.latitudeDelta * 4,
                            longitudeDelta: span.longitudeDelta * 4
                        )
                        print("   🔄 扩大搜索范围重试...")
                        self.searchPOIAtCoordinate(coordinate, searchSpan: largerSpan, isRetry: true, isUserInitiated: isUserInitiated)
                        return
                    }
                    
                    if isInChina {
                        print("   ⚠️ 在中国境内，MKLocalSearch可能不稳定，降级到反向地理编码")
                    }
                    // 搜索失败时，尝试反向地理编码获取地址信息
                    self.fallbackToAddressInfo(coordinate: coordinate)
                    return
                }
                
                // 检查响应是否为空
                guard let response = response, !response.mapItems.isEmpty else {
                    // 如果首次搜索无结果且范围较小，尝试扩大范围
                    if !isRetry {
                        let largerSpan = MKCoordinateSpan(
                            latitudeDelta: span.latitudeDelta * 4,
                            longitudeDelta: span.longitudeDelta * 4
                        )
                        print("⚠️ 小范围搜索无结果，扩大搜索范围重试...")
                        self.searchPOIAtCoordinate(coordinate, searchSpan: largerSpan, isRetry: true, isUserInitiated: isUserInitiated)
                        return
                    }
                    
                    print("⚠️ POI搜索返回空结果，尝试反向地理编码")
                    self.fallbackToAddressInfo(coordinate: coordinate)
                    return
                }
                
                // 处理搜索结果
                self.processPOISearchResults(response: response, clickCoordinate: coordinate)
            }
        }
    }
    
    // 使用统一的地理编码服务进行POI搜索（混合策略：中国使用高德，其他地区使用Apple）
    func searchPOIWithGeocodeService(coordinate: CLLocationCoordinate2D, isUserInitiated: Bool = false) {
        // 获取适合的服务（根据坐标自动选择高德或Apple）
        let service = GeocodeServiceFactory.createService(for: coordinate)
        
        print("📍 [统一服务] 开始POI搜索，服务: \(service is AMapGeocodeService ? "高德API" : "Apple MapKit")")
        
        // 1. 先进行反向地理编码获取地址和POI信息
        service.reverseGeocode(coordinate: coordinate) { result in
            switch result {
            case .success(let geocodeResult):
                // 处理成功结果
                self.handleGeocodeResult(geocodeResult, coordinate: coordinate)
                
                // 2. 如果在中国且没有找到POI，同时搜索周边POI（增强功能）
                if geocodeResult.source == .amap && geocodeResult.poi == nil {
                    // 搜索500米范围内的周边POI
                    service.searchNearbyPOIs(coordinate: coordinate, radius: 500) { nearbyResult in
                        switch nearbyResult {
                        case .success(let nearbyPOIResult):
                            if let nearestPOI = nearbyPOIResult.nearestPOI {
                                print("📍 [统一服务] 找到最近的周边POI: \(nearestPOI.name) (\(nearestPOI.formattedDistance))")
                                // 使用最近的POI创建结果
                                let poiResult = GeocodeResult(
                                    coordinate: coordinate,
                                    address: geocodeResult.address,
                                    poi: nearestPOI,
                                    source: .amap
                                )
                                self.handleGeocodeResult(poiResult, coordinate: coordinate)
                            }
                        case .failure(let error):
                            print("⚠️ [统一服务] 周边POI搜索失败: \(error.localizedDescription)")
                            // 忽略错误，使用反向地理编码的结果
                        }
                    }
                }
                
            case .failure(let error):
                // 处理错误：降级到Apple MapKit或显示错误
                print("❌ [统一服务] 反向地理编码失败: \(error.localizedDescription)")
                self.handleGeocodeError(error, coordinate: coordinate, isUserInitiated: isUserInitiated)
            }
        }
    }
    
    // 处理统一的地理编码结果
    func handleGeocodeResult(_ result: GeocodeResult, coordinate: CLLocationCoordinate2D) {
        // 转换为MKMapItem用于显示
        let mapItem = result.toMapItem()
        
        // 构建消息
        var message = "✅ 找到位置信息（来源：\(result.source.displayName)）"
        if let poi = result.poi {
            message += "\n   POI: \(poi.name)"
            if let distance = poi.distance {
                message += " (\(String(format: "%.0f", distance))米)"
            }
        } else {
            message += "\n   地址: \(result.address.buildFullAddress())"
        }
        
        // 显示结果
        showPOIResult(mapItem, message: message)
    }
    
    // 处理地理编码错误
    func handleGeocodeError(_ error: Error, coordinate: CLLocationCoordinate2D, isUserInitiated: Bool) {
        // 检查是否是节流错误 - 如果是，不继续尝试，避免触发更多节流
        if let nsError = error as NSError?,
           nsError.domain == "GEOErrorDomain" && nsError.code == -3 {
            print("⚠️ Apple地理编码已被节流，停止尝试降级，避免进一步触发节流")
            // 显示错误信息给用户
            showErrorFallback(coordinate: coordinate)
            return
        }
        
        // 检查当前是否处于节流状态
        if isThrottled {
            print("⚠️ 当前处于节流状态，不继续尝试降级服务")
            showErrorFallback(coordinate: coordinate)
            return
        }
        
        // 如果是高德API失败（网络错误或超时），且是用户主动点击，可以尝试降级
        if (error is AMapError || error.localizedDescription.contains("高德") || error.localizedDescription.contains("超时") || error.localizedDescription.contains("网络错误")) && isUserInitiated {
            print("⚠️ 高德API失败（用户主动点击），尝试降级到Apple MapKit")
            // 使用Apple服务重试（但只在用户主动点击时）
            let appleService = AppleGeocodeService.shared
            appleService.reverseGeocode(coordinate: coordinate) { result in
                switch result {
                case .success(let geocodeResult):
                    self.handleGeocodeResult(geocodeResult, coordinate: coordinate)
                case .failure:
                    // Apple也失败，显示错误信息
                    print("⚠️ Apple MapKit也失败，显示错误信息")
                    self.showErrorFallback(coordinate: coordinate)
                }
            }
        } else {
            // 其他错误或自动请求，直接显示错误信息，不再尝试降级
            print("⚠️ 地理编码服务失败，显示错误信息")
            showErrorFallback(coordinate: coordinate)
        }
    }
    
    // 显示错误回退信息（使用坐标兜底，显示POI预览卡片）
    func showErrorFallback(coordinate: CLLocationCoordinate2D) {
        // 使用坐标兜底方案，显示POI预览卡片
        fallbackToCoordinatePOI(coordinate: coordinate)
    }
    
    // 地图点击失败时降级为坐标显示（显示POI预览卡片）
    func fallbackToCoordinatePOI(coordinate: CLLocationCoordinate2D) {
        let mkPlacemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: mkPlacemark)
        
        // 尝试根据坐标判断国家
        let countryName = getCountryNameByCoordinate(coordinate)
        
        // 使用本地化字符串，提供更友好的显示
        mapItem.name = "selected_location".localized
        
        print("🛟 地图点击查询失败，使用坐标降级显示，判断国家: \(countryName)")
        
        // 使用统一函数显示结果（智能处理加载状态）
        showPOIResult(mapItem, message: "✅ 使用坐标信息")
    }
    
    // 根据坐标判断国家名称（使用边界框方法，覆盖主要国家）
    func getCountryNameByCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        // 首先检查是否在中国（使用现有的精确判断）
        if isInChinaBoundingBox(coordinate) {
            return "中国"
        }
        
        // 美国（包含阿拉斯加和夏威夷的粗略范围）
        if lat >= 18.9 && lat <= 71.5 && lon >= -179.8 && lon <= -66.9 {
            // 排除加拿大和墨西哥的部分重叠区域
            if !(lat >= 41.7 && lat <= 71.5 && lon >= -179.8 && lon <= -66.9 && lat > 49.0) {
                // 美国本土：25°N-49°N, 66°W-125°W
                if lat >= 25.0 && lat <= 49.0 && lon >= -125.0 && lon <= -66.9 {
                    return "美国"
                }
                // 阿拉斯加：51°N-71°N, 130°W-172°W
                if lat >= 51.0 && lat <= 71.5 && lon >= -179.8 && lon <= -130.0 {
                    return "美国"
                }
                // 夏威夷：18.9°N-22.3°N, 154.8°W-160.3°W
                if lat >= 18.9 && lat <= 22.3 && lon >= -160.3 && lon <= -154.8 {
                    return "美国"
                }
            }
        }
        
        // 加拿大
        if lat >= 41.7 && lat <= 83.1 && lon >= -141.0 && lon <= -52.6 {
            return "加拿大"
        }
        
        // 日本
        if lat >= 24.2 && lat <= 45.5 && lon >= 122.9 && lon <= 153.9 {
            return "日本"
        }
        
        // 韩国
        if lat >= 33.1 && lat <= 38.6 && lon >= 124.6 && lon <= 132.0 {
            return "韩国"
        }
        
        // 英国
        if lat >= 49.9 && lat <= 60.8 && lon >= -8.6 && lon <= 1.8 {
            return "英国"
        }
        
        // 法国
        if lat >= 41.3 && lat <= 51.1 && lon >= -5.1 && lon <= 9.6 {
            return "法国"
        }
        
        // 德国
        if lat >= 47.3 && lat <= 55.1 && lon >= 5.9 && lon <= 15.0 {
            return "德国"
        }
        
        // 意大利
        if lat >= 36.6 && lat <= 47.1 && lon >= 6.6 && lon <= 18.5 {
            return "意大利"
        }
        
        // 西班牙
        if lat >= 35.2 && lat <= 43.8 && lon >= -9.3 && lon <= 4.3 {
            return "西班牙"
        }
        
        // 澳大利亚
        if lat >= -43.6 && lat <= -10.7 && lon >= 113.3 && lon <= 153.6 {
            return "澳大利亚"
        }
        
        // 新西兰
        if lat >= -47.3 && lat <= -34.4 && lon >= 166.5 && lon <= 178.6 {
            return "新西兰"
        }
        
        // 巴西
        if lat >= -33.7 && lat <= 5.3 && lon >= -73.0 && lon <= -32.0 {
            return "巴西"
        }
        
        // 印度
        if lat >= 6.8 && lat <= 35.7 && lon >= 68.1 && lon <= 97.4 {
            return "印度"
        }
        
        // 俄罗斯（主要部分）
        if lat >= 41.2 && lat <= 81.2 && lon >= 19.6 && lon <= 180.0 {
            // 排除欧洲其他国家
            if !(lat >= 47.3 && lat <= 55.1 && lon >= 5.9 && lon <= 15.0) { // 德国
                if !(lat >= 41.3 && lat <= 51.1 && lon >= -5.1 && lon <= 9.6) { // 法国
                    if lon >= 19.6 {
                        return "俄罗斯"
                    }
                }
            }
        }
        
        // 如果无法判断，返回未知国家
        return "unknown_country".localized
    }
    
    // 根据坐标判断国家枚举（用于获取本地化名称）
    func getCountryByCoordinate(_ coordinate: CLLocationCoordinate2D) -> CountryManager.Country? {
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        // 首先检查是否在中国（使用现有的精确判断）
        if isInChinaBoundingBox(coordinate) {
            return .china
        }
        
        // 美国（包含阿拉斯加和夏威夷的粗略范围）
        if lat >= 18.9 && lat <= 71.5 && lon >= -179.8 && lon <= -66.9 {
            // 排除加拿大和墨西哥的部分重叠区域
            if !(lat >= 41.7 && lat <= 71.5 && lon >= -179.8 && lon <= -66.9 && lat > 49.0) {
                // 美国本土：25°N-49°N, 66°W-125°W
                if lat >= 25.0 && lat <= 49.0 && lon >= -125.0 && lon <= -66.9 {
                    return .unitedStates
                }
                // 阿拉斯加：51°N-71°N, 130°W-172°W
                if lat >= 51.0 && lat <= 71.5 && lon >= -179.8 && lon <= -130.0 {
                    return .unitedStates
                }
                // 夏威夷：18.9°N-22.3°N, 154.8°W-160.3°W
                if lat >= 18.9 && lat <= 22.3 && lon >= -160.3 && lon <= -154.8 {
                    return .unitedStates
                }
            }
        }
        
        // 加拿大
        if lat >= 41.7 && lat <= 83.1 && lon >= -141.0 && lon <= -52.6 {
            return .canada
        }
        
        // 日本
        if lat >= 24.2 && lat <= 45.5 && lon >= 122.9 && lon <= 153.9 {
            return .japan
        }
        
        // 韩国
        if lat >= 33.1 && lat <= 38.6 && lon >= 124.6 && lon <= 132.0 {
            return .southKorea
        }
        
        // 英国
        if lat >= 49.9 && lat <= 60.8 && lon >= -8.6 && lon <= 1.8 {
            return .unitedKingdom
        }
        
        // 法国
        if lat >= 41.3 && lat <= 51.1 && lon >= -5.1 && lon <= 9.6 {
            return .france
        }
        
        // 德国
        if lat >= 47.3 && lat <= 55.1 && lon >= 5.9 && lon <= 15.0 {
            return .germany
        }
        
        // 意大利
        if lat >= 36.6 && lat <= 47.1 && lon >= 6.6 && lon <= 18.5 {
            return .italy
        }
        
        // 西班牙
        if lat >= 35.2 && lat <= 43.8 && lon >= -9.3 && lon <= 4.3 {
            return .spain
        }
        
        // 澳大利亚
        if lat >= -43.6 && lat <= -10.7 && lon >= 113.3 && lon <= 153.6 {
            return .australia
        }
        
        // 新西兰
        if lat >= -47.3 && lat <= -34.4 && lon >= 166.5 && lon <= 178.6 {
            return .newZealand
        }
        
        // 巴西
        if lat >= -33.7 && lat <= 5.3 && lon >= -73.0 && lon <= -32.0 {
            return .brazil
        }
        
        // 印度
        if lat >= 6.8 && lat <= 35.7 && lon >= 68.1 && lon <= 97.4 {
            return .india
        }
        
        // 俄罗斯（主要部分）
        if lat >= 41.2 && lat <= 81.2 && lon >= 19.6 && lon <= 180.0 {
            // 排除欧洲其他国家
            if !(lat >= 47.3 && lat <= 55.1 && lon >= 5.9 && lon <= 15.0) { // 德国
                if !(lat >= 41.3 && lat <= 51.1 && lon >= -5.1 && lon <= 9.6) { // 法国
                    if lon >= 19.6 {
                        return .russia
                    }
                }
            }
        }
        
        // 如果无法判断，返回 nil
        return nil
    }
    
    // 根据坐标获取本地化的国家名称（根据app语言环境调整）
    func getLocalizedCountryNameByCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        if let country = getCountryByCoordinate(coordinate) {
            return CountryManager.shared.getLocalizedCountryName(for: country)
        }
        return "unknown_country".localized
    }
    
    // 优化的反向地理编码方法：在中国优先使用，可以获取areasOfInterest（POI名称）
    // 注意：此方法保留用于兼容性，但优先使用searchPOIWithGeocodeService
    func tryReverseGeocodeWithPOI(coordinate: CLLocationCoordinate2D, isUserInitiated: Bool = false) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        // 使用独立的 geocoder（不受主 geocoder 节流影响）
        let poiGeocoder = CLGeocoder()
        
        // 用户主动点击时，记录日志以便调试
        if isUserInitiated {
            print("👆 用户主动点击POI，立即执行反向地理编码（不受启动阶段节流影响）")
        }
        
        poiGeocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let error = error {
                    // 反向地理编码失败，尝试MKLocalSearch
                    print("⚠️ 反向地理编码失败，尝试MKLocalSearch: \(error.localizedDescription)")
                    self.searchPOIAtCoordinate(coordinate, searchSpan: nil, isRetry: true, isUserInitiated: isUserInitiated)
                    return
                }
                
                guard let placemark = placemarks?.first else {
                    print("⚠️ 反向地理编码返回空结果，尝试MKLocalSearch")
                    self.searchPOIAtCoordinate(coordinate, searchSpan: nil, isRetry: true, isUserInitiated: isUserInitiated)
                    return
                }
                
                // 从placemark中提取POI信息
                let poiName = placemark.areasOfInterest?.first ?? placemark.name
                let hasPOIInfo = placemark.areasOfInterest != nil && !placemark.areasOfInterest!.isEmpty
                
                // 如果有POI名称，使用MKLocalSearch搜索该POI获取详细信息
                if let poiName = poiName, hasPOIInfo {
                    print("✅ 反向地理编码找到POI: \(poiName)，使用MKLocalSearch获取详细信息...")
                    self.searchPOIByName(poiName: poiName, nearCoordinate: coordinate)
                } else {
                    // 没有POI信息，直接使用反向地理编码结果
                    print("✅ 反向地理编码成功，但没有POI信息，直接使用地址信息")
                    self.createMapItemFromPlacemark(placemark, coordinate: coordinate)
                }
            }
        }
    }
    
    // 通过POI名称搜索获取详细信息（在中国更可靠）
    func searchPOIByName(poiName: String, nearCoordinate: CLLocationCoordinate2D) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = poiName
        
        // 设置搜索区域为点击位置附近
        let span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        request.region = MKCoordinateRegion(center: nearCoordinate, span: span)
        
        if #available(iOS 13.0, *) {
            request.resultTypes = [.pointOfInterest, .address]
        }
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            DispatchQueue.main.async {
                // 取消延迟显示加载卡片的任务（如果需要显示错误结果，会由后续处理）
                
                if let error = error {
                    print("⚠️ 通过POI名称搜索失败: \(error.localizedDescription)，使用反向地理编码结果")
                    let location = CLLocation(latitude: nearCoordinate.latitude, longitude: nearCoordinate.longitude)
                    let geocoder = CLGeocoder()
                    geocoder.reverseGeocodeLocation(location) { placemarks, error in
                        DispatchQueue.main.async {
                            if let placemark = placemarks?.first {
                                self.createMapItemFromPlacemark(placemark, coordinate: nearCoordinate)
                            } else {
                                self.fallbackToAddressInfo(coordinate: nearCoordinate)
                            }
                        }
                    }
                    return
                }
                
                // 找到匹配的POI，选择最接近点击位置的
                if let response = response, !response.mapItems.isEmpty {
                    let clickLocation = CLLocation(latitude: nearCoordinate.latitude, longitude: nearCoordinate.longitude)
                    
                    // 找到最近的POI
                    let nearestPOI = response.mapItems.min { item1, item2 in
                        let loc1 = CLLocation(latitude: item1.placemark.coordinate.latitude,
                                             longitude: item1.placemark.coordinate.longitude)
                        let loc2 = CLLocation(latitude: item2.placemark.coordinate.latitude,
                                             longitude: item2.placemark.coordinate.longitude)
                        return clickLocation.distance(from: loc1) < clickLocation.distance(from: loc2)
                    }
                    
                    if let poi = nearestPOI {
                        // 使用统一函数显示结果（智能处理加载状态）
                        showPOIResult(poi, message: "✅ 通过POI名称找到匹配: \(poi.name ?? "未知")")
                        return
                    }
                }
                
                // 如果通过名称搜索失败，使用反向地理编码
                print("⚠️ POI名称搜索无结果，使用反向地理编码")
                self.fallbackToAddressInfo(coordinate: nearCoordinate)
            }
        }
    }
    
    // 从CLPlacemark创建MKMapItem
    func createMapItemFromPlacemark(_ placemark: CLPlacemark, coordinate: CLLocationCoordinate2D) {
        let mkPlacemark = MKPlacemark(placemark: placemark)
        let mapItem = MKMapItem(placemark: mkPlacemark)
        
        // 构建地点名称
        let poiName = placemark.areasOfInterest?.first
        let cityName = placemark.locality ?? placemark.administrativeArea ?? "unknown_city".localized
        let streetName = placemark.thoroughfare ?? ""
        let streetNumber = placemark.subThoroughfare ?? ""
        
        let locationName = self.buildLocationName(
            poi: poiName ?? "",
            city: cityName,
            street: streetName,
            streetNumber: streetNumber
        )
        
        mapItem.name = locationName
        
        var message = "✅ 使用反向地理编码结果: \(locationName)"
        if let poi = poiName {
            message += "\n   POI: \(poi)"
        }
        
        // 使用统一函数显示结果（智能处理加载状态）
        showPOIResult(mapItem, message: message)
    }
    
    // 处理POI搜索结果：优化匹配逻辑，优先选择最近的POI
    func processPOISearchResults(response: MKLocalSearch.Response, clickCoordinate: CLLocationCoordinate2D) {
        let clickLocation = CLLocation(latitude: clickCoordinate.latitude, longitude: clickCoordinate.longitude)
        
        // 优先选择POI结果，如果没有POI则选择地址结果
        let poiItems = response.mapItems.filter { item in
            item.pointOfInterestCategory != nil || item.name != nil
        }
        
        // 优化：计算所有POI的距离，并按距离排序，优先选择最近的
        let poiWithDistances = poiItems.map { item -> (item: MKMapItem, distance: CLLocationDistance) in
            let poiLocation = CLLocation(
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
            )
            let distance = clickLocation.distance(from: poiLocation)
            return (item, distance)
        }.sorted { $0.distance < $1.distance } // 按距离从近到远排序
        
        // 优化的检测范围：从50米缩小到20米，提高点击精度
        let preciseClickThreshold: CLLocationDistance = 20 // 20米内认为是精确点击了POI图标
        let nearbyClickThreshold: CLLocationDistance = 50  // 50米内认为是点击了附近POI
        
        // 优先查找精确点击的POI（20米内）
        if let precisePOI = poiWithDistances.first(where: { $0.distance <= preciseClickThreshold }) {
            showPOIResult(precisePOI.item, message: "✅ 精确点击了POI图标 (\(String(format: "%.1f", precisePOI.distance))米): \(precisePOI.item.name ?? "未知")")
            return
        }
        
        // 如果没有精确点击，检查是否有附近POI（20-50米）
        if let nearbyPOI = poiWithDistances.first(where: { $0.distance <= nearbyClickThreshold }) {
            showPOIResult(nearbyPOI.item, message: "✅ 点击了附近POI (\(String(format: "%.1f", nearbyPOI.distance))米): \(nearbyPOI.item.name ?? "未知")")
            return
        }
        
        // 如果有POI但距离较远，选择最近的POI
        if let nearestPOI = poiWithDistances.first {
            let distance = nearestPOI.distance
            if distance <= 100 { // 100米内仍然显示最近的POI
                showPOIResult(nearestPOI.item, message: "✅ 找到最近POI (\(String(format: "%.1f", distance))米): \(nearestPOI.item.name ?? "未知")")
                return
            }
        }
        
        // 没有找到合适的POI，尝试显示地址信息
        if let firstAddress = response.mapItems.first(where: { $0.pointOfInterestCategory == nil }) {
            showPOIResult(firstAddress, message: "✅ 找到地址信息: \(firstAddress.name ?? "未知")")
            return
        }
        
        // 完全没有找到任何信息，尝试反向地理编码
        print("⚠️ 未找到POI或地址，尝试反向地理编码")
        self.fallbackToAddressInfo(coordinate: clickCoordinate)
    }
    
    // 备用方案：使用反向地理编码获取地址信息
    func fallbackToAddressInfo(coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        // 使用独立的 geocoder，避免主 geocoder 忙碌时冲突
        let fallbackGeocoder = CLGeocoder()
        fallbackGeocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    let mkPlacemark = MKPlacemark(placemark: placemark)
                    let mapItem = MKMapItem(placemark: mkPlacemark)
                    
                    // 构建地点名称
                    let cityName = placemark.locality ?? placemark.administrativeArea ?? "unknown_city".localized
                    let streetName = placemark.thoroughfare ?? ""
                    let streetNumber = placemark.subThoroughfare ?? ""
                    let poi = placemark.areasOfInterest?.first ?? ""
                    
                    let locationName = self.buildLocationName(
                        poi: poi,
                        city: cityName,
                        street: streetName,
                        streetNumber: streetNumber
                    )
                    
                    mapItem.name = locationName
                    
                    // 使用统一函数显示结果（智能处理加载状态）
                    showPOIResult(mapItem, message: "✅ 反向地理编码成功: \(locationName)")
                } else {
                    let errorDescription = error?.localizedDescription ?? "未知错误"
                    print("❌ 反向地理编码失败: \(errorDescription)")
                    // 再次失败时降级为坐标显示（POI预览卡片）
                    self.fallbackToCoordinatePOI(coordinate: coordinate)
                }
            }
        }
    }
}
