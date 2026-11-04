//
//  MapView+Actions.swift
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
    func handleLongPress(at coordinate: CLLocationCoordinate2D) {
        // 在线路卡片模式下禁用反向地理编码
        if autoShowRouteCards {
            print("⏭️ 线路卡片模式：已禁用长按反向地理编码")
            return
        }
        
        print("🗺️ 长按地图位置: (\(coordinate.latitude), \(coordinate.longitude))")
        
        // 先关闭之前可能显示的POI预览
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            showingPOIPreview = false
            selectedPOI = nil
        }
        
        // 长按时只做反向地理编码，显示地址信息（路名和门牌号），不搜索POI
        showAddressInfoForLongPress(coordinate: coordinate)
    }
    
    // 长按时显示地址信息（路名和门牌号）
    func showAddressInfoForLongPress(coordinate: CLLocationCoordinate2D) {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        // 使用独立的 geocoder，避免主 geocoder 忙碌时冲突
        let addressGeocoder = CLGeocoder()
        addressGeocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    let mkPlacemark = MKPlacemark(placemark: placemark)
                    let mapItem = MKMapItem(placemark: mkPlacemark)
                    
                    // 构建地址名称：优先使用路名+门牌号，不包含POI信息
                    let cityName = placemark.locality ?? placemark.administrativeArea ?? "unknown_city".localized
                    let streetName = placemark.thoroughfare ?? ""
                    let streetNumber = placemark.subThoroughfare ?? ""
                    
                    // 长按时只显示地址信息，不显示POI
                    var locationName = ""
                    if !streetName.isEmpty && !streetNumber.isEmpty {
                        locationName = "\(streetName)\(streetNumber)"
                    } else if !streetName.isEmpty {
                        locationName = streetName
                    } else if !streetNumber.isEmpty {
                        locationName = streetNumber
                    } else {
                        // 如果没有路名和门牌号，使用城市名
                        locationName = cityName
                    }
                    
                    mapItem.name = locationName
                    
                    print("✅ 长按反向地理编码成功: \(locationName)")
                    if !streetName.isEmpty {
                        print("   路名: \(streetName)")
                    }
                    if !streetNumber.isEmpty {
                        print("   门牌号: \(streetNumber)")
                    }
                    
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        self.selectedPOI = mapItem
                        self.showingPOIPreview = true
                    }
                } else {
                    // 失败时降级为坐标显示
                    self.fallbackToCoordinateForLongPress(coordinate: coordinate, error: error)
                }
            }
        }
    }
    
    // 长按失败时降级为坐标显示
    func fallbackToCoordinateForLongPress(coordinate: CLLocationCoordinate2D, error: Error?) {
        let mkPlacemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: mkPlacemark)
        
        // 使用本地化字符串，提供更友好的显示
        mapItem.name = "selected_location".localized
        
        // 记录错误信息（但不影响降级显示）
        if let error = error {
            let errorDescription = error.localizedDescription
            print("❌ 长按反向地理编码失败，使用坐标降级: \(errorDescription)")
            
            // 检查是否是节流错误
            if let nsError = error as NSError?,
               nsError.domain == "GEOErrorDomain" && nsError.code == -3 {
                print("⚠️ 地理编码服务被节流，已降级为坐标显示")
            }
        } else {
            print("⚠️ 长按反向地理编码返回空结果，使用坐标降级")
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            self.selectedPOI = mapItem
            self.showingPOIPreview = true
        }
    }
    
    // 处理POI添加目的地 - 打开快速打卡弹窗
    func handlePOIAddDestination(poi: MKMapItem) {
        // 关闭POI预览
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            showingPOIPreview = false
            selectedPOI = nil
        }
        
        // 提取POI信息
        let placemark = poi.placemark
        let cityName = placemark.locality ?? placemark.administrativeArea ?? "unknown_city".localized
        let streetName = placemark.thoroughfare ?? ""
        let streetNumber = placemark.subThoroughfare ?? ""
        let poiName = poi.name ?? placemark.areasOfInterest?.first ?? ""
        
        // 构建地点名称：优先使用POI名称
        let locationName = buildLocationName(
            poi: poiName,
            city: cityName,
            street: streetName,
            streetNumber: streetNumber
        )
        
        // 如果placemark没有国家信息，尝试根据坐标判断国家（使用本地化名称）
        var countryName = placemark.country ?? ""
        if countryName.isEmpty || countryName == "unknown_country".localized {
            countryName = getLocalizedCountryNameByCoordinate(placemark.coordinate)
            print("📍 使用坐标判断国家（本地化）: \(countryName)")
        }
        if countryName.isEmpty {
            countryName = "unknown_country".localized
        }
        
        // 根据国家名称判断分类（支持本地化名称）
        let isoCountryCode = placemark.isoCountryCode ?? ""
        let category: String
        if isoCountryCode == "CN" {
            category = "domestic"
        } else if CountryManager.shared.isDomestic(country: countryName) {
            category = "domestic"
        } else {
            category = "international"
        }
        
        // 设置预填充数据并显示快速打卡界面
        isWaitingForLocation = false
        pendingPhotoPrefill = nil
        updateAddDestinationPrefill(
            mapItem: poi,
            name: locationName,
            country: countryName,
            category: category
        )
        // 延迟到下一 run loop 再呈现 sheet，确保 addDestinationPrefill 已提交，避免弹窗内容为空（首次添加时）
        DispatchQueue.main.async {
            self.showingQuickCheckIn = true
        }
    }
    
    // 处理打卡功能：使用用户当前位置添加目的地
    func handleCheckIn() {
        print("📍 点击打卡按钮")
        checkInFeedbackGenerator.impactOccurred()
        
        // 检查是否有已知位置
        if let userLocation = locationManager.lastKnownLocation {
            print("✅ 使用已知位置进行打卡: (\(userLocation.latitude), \(userLocation.longitude))")
            
            isGeocodingLocation = true  // 先显示加载状态，避免首帧出现空表单
            // 在下一帧显示添加目的地界面，避免第一次呈现时使用旧的模式状态
            DispatchQueue.main.async {
                self.showingQuickCheckIn = true
            }
            
            // 执行反向地理编码
            reverseGeocodeLocation(coordinate: userLocation, forAddDestinationPrefill: true)
        } else {
            // 如果没有位置信息，先请求定位
            print("⏳ 没有已知位置，请求定位中...")
            
            // 在下一帧显示添加目的地界面，显示加载状态，确保使用快速打卡模式
            DispatchQueue.main.async {
                self.showingQuickCheckIn = true
            }
            isGeocodingLocation = true
            isWaitingForLocation = true
            
            // 打卡场景临时提升定位精度
            locationManager.startUpdatingLocation(mode: .checkIn)
            locationManager.requestLocation()
            
            // 使用定时器等待定位更新（等待最多2秒）
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                // 如果还在等待状态，说明定位超时
                if self.isWaitingForLocation {
                    print("⏰ 定位超时，使用备用方案")
                    self.fallbackCheckInWithoutLocation()
                }
            }
        }
    }
    
    /// 打卡流程结束后恢复地图浏览级定位精度
    func restoreMapBrowsingLocationModeIfNeeded() {
        guard locationManager.currentMode == .checkIn else { return }
        locationManager.applyMode(.mapBrowsing)
    }
    
    // 打卡备用方案：无法获取位置时的处理
    func fallbackCheckInWithoutLocation() {
        isGeocodingLocation = false
        isWaitingForLocation = false
        restoreMapBrowsingLocationModeIfNeeded()
        print("❌ 无法获取当前位置，显示快速打卡界面（用户可手动输入位置）")
        
        // 即使无法获取位置，也显示快速打卡界面，用户可以手动搜索位置
        // 不关闭弹窗，让用户可以在快速打卡界面中手动搜索位置
        // showingAddDestination 保持为 true，会显示 QuickCheckInView(prefill: nil)
    }
    
    func updateAddDestinationPrefill(
        mapItem: MKMapItem,
        name: String,
        country: String,
        category: String
    ) {
        // 提取省份信息（对于中国直辖市，会将其名称作为省份）
        let province = CountryManager.extractProvince(
            administrativeArea: mapItem.placemark.administrativeArea,
            locality: mapItem.placemark.locality,
            country: country,
            isoCountryCode: mapItem.placemark.isoCountryCode
        )
        
        var prefill = AddDestinationPrefill(
            location: mapItem,
            name: name,
            country: country,
            province: province,
            category: category
        )
        if let pending = pendingPhotoPrefill {
            prefill.visitDate = pending.visitDate
            prefill.photoDatas = pending.photoDatas
            prefill.photoThumbnailDatas = pending.photoThumbnailDatas
            pendingPhotoPrefill = nil
        }
        addDestinationPrefill = prefill
    }
    
    // 构建地点名称：优先使用 POI，否则使用"城市+街道+门牌号"
    func buildLocationName(poi: String, city: String, street: String, streetNumber: String) -> String {
        // 优先级1：使用 POI（如果存在）
        if !poi.isEmpty {
            return poi
        }
        
        // 优先级2：组合"城市+街道+门牌号"
        // 判断是否为中文环境（通过检查城市名是否包含中文字符）
        let isChinese = city.contains(where: { "\u{4E00}" <= $0 && $0 <= "\u{9FFF}" }) ||
                       street.contains(where: { "\u{4E00}" <= $0 && $0 <= "\u{9FFF}" })
        
        var addressParts: [String] = []
        
        if isChinese {
            // 中文格式：城市 + 街道 + 门牌号（如"北京市建国路88号"）
            addressParts.append(city)
            if !street.isEmpty {
                addressParts.append(street)
            }
            if !streetNumber.isEmpty {
                addressParts.append(streetNumber)
            }
            
            // 如果有多个部分，组合它们；否则只返回城市
            if addressParts.count > 1 {
                return addressParts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
            }
            return city
        } else {
            // 英文格式：门牌号 + 街道, 城市（如"123 Main Street, New York"）
            if !streetNumber.isEmpty {
                addressParts.append(streetNumber)
            }
            if !street.isEmpty {
                addressParts.append(street)
            }
            
            // 如果有街道信息，组合成"门牌号 街道, 城市"格式
            if !addressParts.isEmpty {
                let streetPart = addressParts.joined(separator: " ")
                return "\(streetPart), \(city)"
            }
            
            // 如果没有街道信息，只返回城市
            return city
        }
    }
    
    func tryUseCachedPlacemark(for coordinate: CLLocationCoordinate2D, updatePrefill: Bool = true) -> Bool {
        guard let cachedPlacemark = lastReverseGeocodePlacemark,
              let cachedCoordinate = lastReverseGeocodeCoordinate,
              let cachedTime = lastReverseGeocodeTimestamp else {
            return false
        }
        
        let currentLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let cachedLocation = CLLocation(latitude: cachedCoordinate.latitude, longitude: cachedCoordinate.longitude)
        let distance = currentLocation.distance(from: cachedLocation)
        let isFresh = Date().timeIntervalSince(cachedTime) < cachedPlacemarkTTL
        
        if distance < cachedPlacemarkReuseDistance && isFresh {
            applyGeocodeResult(cachedPlacemark, coordinate: coordinate, source: .cached, updatePrefill: updatePrefill)
            print("♻️ 直接复用缓存的地理编码结果，距离 \(Int(distance))m，缓存时间 \(Int(Date().timeIntervalSince(cachedTime)))s")
            return true
        }
        return false
    }
    
    func applyGeocodeResult(_ placemark: CLPlacemark, coordinate: CLLocationCoordinate2D, source: GeocodeResultSource = .live, updatePrefill: Bool = true) {
        geocodeTimeoutTimer?.invalidate()
        geocodeTimeoutTimer = nil
        pendingGeocodeCoordinate = nil
        isGeocodingLocation = false
        lastReverseGeocodePlacemark = placemark
        lastReverseGeocodeCoordinate = coordinate
        lastReverseGeocodeTimestamp = Date()
        if let accuracy = locationManager.lastLocationAccuracy {
            lastGeocodedAccuracy = accuracy
        }
        
        let cityName = placemark.locality ?? placemark.administrativeArea ?? "unknown_city".localized
        let streetName = placemark.thoroughfare ?? ""
        let streetNumber = placemark.subThoroughfare ?? ""
        let poi = placemark.areasOfInterest?.first ?? ""
        let locationName = buildLocationName(
            poi: poi,
            city: cityName,
            street: streetName,
            streetNumber: streetNumber
        )
        
        let countryName = resolvedCountryName(from: placemark)
        let isoCountryCode = placemark.isoCountryCode ?? ""
        let category = (isoCountryCode == "CN" || countryName == "中国" || countryName == "China") ? "domestic" : "international"
        
        print("✅ 反向地理编码成功(\(source == .cached ? "缓存" : "实时")):")
        print("   地点名称: \(locationName)")
        if !poi.isEmpty {
            print("   POI: \(poi)")
        }
        print("   城市: \(cityName)")
        if !streetName.isEmpty {
            print("   街道: \(streetName)")
        }
        if !streetNumber.isEmpty {
            print("   门牌号: \(streetNumber)")
        }
        print("   国家: \(countryName)")
        print("   ISO代码: \(isoCountryCode)")
        print("   分类: \(category)")
        
        // 仅当本次地理编码是为「添加目的地/打卡」发起的才更新预填充，避免启动时的自动定位覆盖用户即将添加的地点
        guard updatePrefill else { return }
        
        // 使用本次查询坐标作为锚点；CLPlacemark.location 常偏向路网/区块中心，与照片 EXIF 或选点不一致
        let mapItem = mkMapItemForPrefill(
            displayCoordinate: coordinate,
            placemark: placemark,
            locationName: locationName
        )
        updateAddDestinationPrefill(
            mapItem: mapItem,
            name: locationName,
            country: countryName,
            category: category
        )
    }
    
    /// 境外反向地理编码常见：`country` 为空但 `isoCountryCode` 有值（如 MY），需本地化展示。
    func resolvedCountryName(from placemark: CLPlacemark) -> String {
        if let c = placemark.country?.trimmingCharacters(in: .whitespacesAndNewlines), !c.isEmpty {
            return c
        }
        if let iso = placemark.isoCountryCode, !iso.isEmpty {
            return Locale.current.localizedString(forRegionCode: iso) ?? iso
        }
        return "unknown_country".localized
    }
    
    /// 预填/保存用的 `MKMapItem`：锚点用查询坐标；国家/州/市从 `CLPlacemark` 写入 `CNPostalAddress`。
    /// 境外常无 `postalAddress`，若仅用 `MKPlacemark(coordinate:)` 会导致国家、行政区空白（未知国家、省份为空）。
    func mkMapItemForPrefill(
        displayCoordinate: CLLocationCoordinate2D,
        placemark: CLPlacemark,
        locationName: String
    ) -> MKMapItem {
        let postal: CNPostalAddress = {
            let m: CNMutablePostalAddress
            if let existing = placemark.postalAddress {
                m = existing.mutableCopy() as! CNMutablePostalAddress
            } else {
                m = CNMutablePostalAddress()
            }
            if m.state.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let s = placemark.administrativeArea, !s.isEmpty {
                m.state = s
            }
            if m.city.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let s = placemark.locality, !s.isEmpty {
                m.city = s
            }
            if m.subLocality.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let s = placemark.subLocality, !s.isEmpty {
                m.subLocality = s
            }
            if m.street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let parts = [placemark.thoroughfare, placemark.subThoroughfare].compactMap { $0 }.filter { !$0.isEmpty }
                if !parts.isEmpty {
                    m.street = parts.joined(separator: " ")
                }
            }
            if m.country.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let iso = placemark.isoCountryCode, !iso.isEmpty {
                    m.isoCountryCode = iso
                    m.country = Locale.current.localizedString(forRegionCode: iso) ?? iso
                } else if let c = placemark.country, !c.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    m.country = c
                }
            }
            if m.isoCountryCode.isEmpty, let iso = placemark.isoCountryCode, !iso.isEmpty {
                m.isoCountryCode = iso
            }
            return m
        }()
        let mk = MKPlacemark(coordinate: displayCoordinate, postalAddress: postal)
        let item = MKMapItem(placemark: mk)
        item.name = locationName
        return item
    }
    
    // 反向地理编码：获取城市和国家信息（带多重回退和优化）
    // forAddDestinationPrefill：为 true 时才更新 addDestinationPrefill（打卡/照片导入等）；启动或定位更新触发的编码不更新预填，避免覆盖用户即将添加的地点
    func reverseGeocodeLocation(coordinate: CLLocationCoordinate2D, force: Bool = false, forAddDestinationPrefill: Bool = false) {
        // 0. 检查节流状态
        if isThrottled, let resetTime = throttleResetTime {
            let timeUntilReset = resetTime.timeIntervalSinceNow
            if timeUntilReset > 0 {
                print("⏸️ 反向地理编码被节流，\(Int(timeUntilReset)) 秒内不再发起新请求")
                return
            } else {
                // 节流时间已过，重置状态
                isThrottled = false
                throttleResetTime = nil
            }
        }
        
        if !force, tryUseCachedPlacemark(for: coordinate, updatePrefill: forAddDestinationPrefill) {
            return
        }
        
        // 1. 请求去重：如果正在处理相同或非常接近的坐标，忽略新请求
        if !force, let pendingCoord = pendingGeocodeCoordinate {
            let distance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                .distance(from: CLLocation(latitude: pendingCoord.latitude, longitude: pendingCoord.longitude))
            if distance < 10.0 { // 10米内的重复请求
                print("⚠️ 忽略重复的地理编码请求（距离: \(String(format: "%.1f", distance))米）")
                return
            }
        }
        
        // 2. 防抖：如果距离上次请求太近（启动阶段2秒，正常1秒），延迟执行
        let debounceInterval: TimeInterval = (viewAppearTime.map { Date().timeIntervalSince($0) < 30.0 } ?? false) ? 2.0 : 1.0
        if !force,
           let lastTime = lastGeocodeTime,
           Date().timeIntervalSince(lastTime) < debounceInterval {
            print("⏳ 地理编码请求过于频繁，延迟执行")
            DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval) {
                self.reverseGeocodeLocation(coordinate: coordinate, force: force, forAddDestinationPrefill: forAddDestinationPrefill)
            }
            return
        }
        
        // 3. 确保 geocoder 已初始化
        guard let geocoder = geocoder else {
            print("⏳ Geocoder 尚未初始化，延迟执行")
            // 如果 geocoder 还没初始化，先初始化它
            self.geocoder = CLGeocoder()
            // 延迟一小段时间后重试
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.reverseGeocodeLocation(coordinate: coordinate, force: force, forAddDestinationPrefill: forAddDestinationPrefill)
            }
            return
        }
        
        // 4. 检查 geocoder 是否正在处理请求
        if geocoder.isGeocoding {
            print("⚠️ Geocoder 正在处理其他请求，稍后重试")
            // 取消当前请求，使用新坐标
            geocoder.cancelGeocode()
            // 等待一小段时间后重试
            let delay: TimeInterval = force ? 0.1 : 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                self.reverseGeocodeLocation(coordinate: coordinate, force: force, forAddDestinationPrefill: forAddDestinationPrefill)
            }
            return
        }
        
        // 5. 记录待处理的坐标
        pendingGeocodeCoordinate = coordinate
        lastGeocodeTime = Date()
        isGeocodingLocation = true
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        // 6. 设置超时处理（10秒）
        geocodeTimeoutTimer?.invalidate()
        geocodeTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: false) { _ in
            print("⏰ 地理编码超时，尝试备用方案")
            self.isGeocodingLocation = false
            self.pendingGeocodeCoordinate = nil
            self.geocodeTimeoutTimer = nil
            // 使用备用搜索
            self.fallbackSearchAround(coordinate: coordinate, forAddDestinationPrefill: forAddDestinationPrefill)
        }

        func handleError(_ error: Error?) {
            // 取消超时定时器
            geocodeTimeoutTimer?.invalidate()
            geocodeTimeoutTimer = nil
            
            let errorDescription = error?.localizedDescription ?? "未知错误"
            print("❌ 反向地理编码失败: \(errorDescription)")
            
            // 检查是否是网络错误、服务不可用或节流错误
            if let nsError = error as NSError? {
                let errorCode = nsError.code
                let errorDomain = nsError.domain
                
                // 检查是否是节流错误（GEOErrorDomain Code=-3）
                if errorDomain == "GEOErrorDomain" && errorCode == -3 {
                    print("⚠️ 反向地理编码被节流（请求过于频繁）")
                    
                    // 从错误信息中提取重置时间
                    var resetTime: TimeInterval = 20.0 // 默认20秒
                    if let userInfo = nsError.userInfo as? [String: Any],
                       let timeUntilReset = userInfo["timeUntilReset"] as? TimeInterval {
                        resetTime = timeUntilReset
                    }
                    
                    // 设置节流状态
                    isThrottled = true
                    throttleResetTime = Date().addingTimeInterval(resetTime)
                    
                    print("⏸️ 节流将在 \(Int(resetTime)) 秒后重置，本次及冷静期内不再自动重试")
                    return
                }
                
                // CLError 错误码
                if errorCode == 2 { // kCLErrorNetwork
                    print("⚠️ 网络错误，稍后重试")
                    // 网络错误时，延迟重试
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        self.reverseGeocodeLocation(coordinate: coordinate, force: force, forAddDestinationPrefill: forAddDestinationPrefill)
                    }
                    return
                }
            }
            
            // 其他错误，尝试备用方案
            failoverToAlternateLocales()
        }

        func failoverToAlternateLocales() {
            // 优先尝试英文，再尝试中文，提升国外/国内识别成功率
            geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "en_US")) { placemarks, _ in
                if let placemark = placemarks?.first {
                    DispatchQueue.main.async {
                        self.applyGeocodeResult(placemark, coordinate: coordinate, updatePrefill: forAddDestinationPrefill)
                    }
                    return
                }
                geocoder.reverseGeocodeLocation(location, preferredLocale: Locale(identifier: "zh_CN")) { placemarks, _ in
                    if let placemark = placemarks?.first {
                        DispatchQueue.main.async {
                            self.applyGeocodeResult(placemark, coordinate: coordinate, updatePrefill: forAddDestinationPrefill)
                        }
                        return
                    }
                    // 继续回退到附近搜索
                    DispatchQueue.main.async {
                        self.pendingGeocodeCoordinate = nil
                        self.isGeocodingLocation = false
                        self.fallbackSearchAround(coordinate: coordinate, forAddDestinationPrefill: forAddDestinationPrefill)
                    }
                }
            }
        }

        // 7. 执行地理编码请求
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    self.applyGeocodeResult(placemark, coordinate: coordinate, updatePrefill: forAddDestinationPrefill)
                }
                return
            }
            DispatchQueue.main.async { handleError(error) }
        }
    }

    // 备用方案1：在坐标附近做一次本地搜索，尽量拿到国家/城市
    func fallbackSearchAround(coordinate: CLLocationCoordinate2D, forAddDestinationPrefill: Bool = false) {
        let request = MKLocalSearch.Request()
        // 不设置关键词，利用区域搜索附近的已知地标/城市
        request.naturalLanguageQuery = nil
        let span = MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8)
        request.region = MKCoordinateRegion(center: coordinate, span: span)
        if #available(iOS 13.0, *) {
            request.resultTypes = [.address, .pointOfInterest]
        }
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let item = response?.mapItems.first {
                // 提取详细地址信息
                let cityName = item.placemark.locality ?? item.placemark.administrativeArea ?? "unknown_city".localized
                let streetName = item.placemark.thoroughfare ?? ""
                let streetNumber = item.placemark.subThoroughfare ?? ""
                // 优先使用 mapItem.name（可能是 POI），否则使用 areasOfInterest
                let poi = item.name ?? item.placemark.areasOfInterest?.first ?? ""
                
                // 构建地点名称：优先使用 POI，否则使用"城市+街道+门牌号"
                let locationName = self.buildLocationName(
                    poi: poi,
                    city: cityName,
                    street: streetName,
                    streetNumber: streetNumber
                )
                
                let countryName = self.resolvedCountryName(from: item.placemark)
                let isoCountryCode = item.placemark.isoCountryCode ?? ""
                let category = (isoCountryCode == "CN" || countryName == "中国" || countryName == "China") ? "domestic" : "international"
                
                print("✅ 附近搜索成功:")
                print("   地点名称: \(locationName)")
                if !poi.isEmpty {
                    print("   POI: \(poi)")
                }
                print("   城市: \(cityName)")
                if !streetName.isEmpty {
                    print("   街道: \(streetName)")
                }
                if !streetNumber.isEmpty {
                    print("   门牌号: \(streetNumber)")
                }
                print("   国家: \(countryName)")
                
                let mapItem = self.mkMapItemForPrefill(
                    displayCoordinate: coordinate,
                    placemark: item.placemark,
                    locationName: locationName
                )
                DispatchQueue.main.async {
                    self.isGeocodingLocation = false
                    if forAddDestinationPrefill {
                        self.updateAddDestinationPrefill(
                            mapItem: mapItem,
                            name: locationName,
                            country: countryName,
                            category: category
                        )
                    }
                    // 不需要再次设置 showingAddDestination，界面已经显示
                }
            } else {
                print("⚠️ " + "nearby_search_failed".localized(with: error?.localizedDescription ?? "无结果"))
                DispatchQueue.main.async { self.fallbackWithCoordinateOnly(coordinate: coordinate, forAddDestinationPrefill: forAddDestinationPrefill) }
            }
        }
    }

    // 备用方案2：仅根据坐标进行国内/国外判断并提供占位名称
    func fallbackWithCoordinateOnly(coordinate: CLLocationCoordinate2D, forAddDestinationPrefill: Bool = false) {
        isGeocodingLocation = false
        let category = isInChinaBoundingBox(coordinate) ? "domestic" : "international"
        // 使用本地化的国家名称
        let countryName = category == "domestic"
            ? CountryManager.shared.getLocalizedCountryName(for: .china)
            : getLocalizedCountryNameByCoordinate(coordinate)
        let cityName = "selected_location".localized
        print("🛟 " + "coordinate_fallback".localized(with: cityName, countryName, category))
        guard forAddDestinationPrefill else { return }
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = cityName
        updateAddDestinationPrefill(
            mapItem: mapItem,
            name: cityName,
            country: countryName,
            category: category
        )
        // 不需要再次设置 showingAddDestination，界面已经显示
    }

    // 使用简化中国多边形进行判断（点在多边形内）
    func isInChinaBoundingBox(_ coordinate: CLLocationCoordinate2D) -> Bool {
        return isPoint(coordinate, inPolygon: Self.chinaMainlandPolygon)
    }

    // 射线法判断点是否在多边形内（支持闭合/未闭合输入）
    func isPoint(_ point: CLLocationCoordinate2D, inPolygon polygon: [CLLocationCoordinate2D]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let xi = polygon[i].latitude
            let yi = polygon[i].longitude
            let xj = polygon[j].latitude
            let yj = polygon[j].longitude
            let intersect = ((yi > point.longitude) != (yj > point.longitude)) &&
                (point.latitude < (xj - xi) * (point.longitude - yi) / (yj - yi + 1e-12) + xi)
            if intersect { inside.toggle() }
            j = i
        }
        return inside
    }
    
}
