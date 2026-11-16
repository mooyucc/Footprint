//
//  MapView+Camera.swift
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
    func zoomToCluster(_ cluster: ClusterAnnotation) {
        let coordinates = cluster.destinations.map { $0.coordinate }
        
        var minLat = coordinates[0].latitude
        var maxLat = coordinates[0].latitude
        var minLon = coordinates[0].longitude
        var maxLon = coordinates[0].longitude
        
        for coord in coordinates {
            minLat = min(minLat, coord.latitude)
            maxLat = max(maxLat, coord.latitude)
            minLon = min(minLon, coord.longitude)
            maxLon = max(maxLon, coord.longitude)
        }
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        let span = MKCoordinateSpan(
            latitudeDelta: max(0.01, (maxLat - minLat) * 1.5),
            longitudeDelta: max(0.01, (maxLon - minLon) * 1.5)
        )
        
        withAnimation {
            mapCameraPosition = .region(MKCoordinateRegion(center: center, span: span))
        }
    }
    
    // 缩放到旅程的所有地点范围
    func zoomToTripDestinations(_ destinations: [TravelDestination], animationDuration: TimeInterval = 0.8) {
        guard !destinations.isEmpty else { return }
        
        func applyCameraPosition(_ region: MKCoordinateRegion) {
            if animationDuration <= 0 {
                mapCameraPosition = .region(region)
            } else {
                withAnimation(.easeInOut(duration: animationDuration)) {
                    mapCameraPosition = .region(region)
                }
            }
        }
        
        let coordinates = destinations.map { $0.coordinate }
        
        // 计算边界
        let latitudes = coordinates.map { $0.latitude }
        let longitudes = coordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 0
        let maxLat = latitudes.max() ?? 0
        let minLon = longitudes.min() ?? 0
        let maxLon = longitudes.max() ?? 0
        
        // 步骤1：计算路线纬度的跨度和中心点
        let routeCenterLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let routeLatSpan = max(maxLat - minLat, 0.01) // 路线的实际纬度跨度（至少0.01度）
        
        // 计算经度跨度（用于正常情况）
        let lonSpan = max((maxLon - minLon) * 1.5, 0.01)
        
        // 使用路线中心点和标准跨度（添加1.5倍边距）
        let normalLatSpan = max(routeLatSpan * 1.5, 0.01)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: routeCenterLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: normalLatSpan, longitudeDelta: lonSpan)
        )
        
        applyCameraPosition(region)
        
        print("🗺️ 地图已缩放到旅程范围，包含 \(destinations.count) 个地点")
    }
    
    
    // 根据国家代码获取地图区域
    func getRegionForCountry(countryCode: String, userLocation: CLLocationCoordinate2D) -> MKCoordinateRegion {
        switch countryCode {
        case "CN":
            // 中国
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 35.0, longitude: 105.0),
                span: MKCoordinateSpan(latitudeDelta: 30.0, longitudeDelta: 40.0)
            )
        case "US":
            // 美国
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.8283, longitude: -98.5795),
                span: MKCoordinateSpan(latitudeDelta: 40.0, longitudeDelta: 60.0)
            )
        case "JP":
            // 日本
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.2048, longitude: 138.2529),
                span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 15.0)
            )
        case "KR":
            // 韩国
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 36.5, longitude: 127.5),
                span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
            )
        case "SG":
            // 新加坡
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 1.3521, longitude: 103.8198),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        case "TH":
            // 泰国
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 15.8700, longitude: 100.9925),
                span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 15.0)
            )
        case "MY":
            // 马来西亚
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 4.2105, longitude: 101.9758),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            )
        case "ID":
            // 印度尼西亚
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -0.7893, longitude: 113.9213),
                span: MKCoordinateSpan(latitudeDelta: 20.0, longitudeDelta: 20.0)
            )
        case "PH":
            // 菲律宾
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 12.8797, longitude: 121.7740),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            )
        case "VN":
            // 越南
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 14.0583, longitude: 108.2772),
                span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 10.0)
            )
        case "IN":
            // 印度
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 20.5937, longitude: 78.9629),
                span: MKCoordinateSpan(latitudeDelta: 30.0, longitudeDelta: 30.0)
            )
        case "AU":
            // 澳大利亚
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -25.2744, longitude: 133.7751),
                span: MKCoordinateSpan(latitudeDelta: 40.0, longitudeDelta: 50.0)
            )
        case "NZ":
            // 新西兰
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -41.2865, longitude: 174.7762),
                span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 15.0)
            )
        case "CA":
            // 加拿大
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 56.1304, longitude: -106.3468),
                span: MKCoordinateSpan(latitudeDelta: 50.0, longitudeDelta: 80.0)
            )
        case "MX":
            // 墨西哥
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 23.6345, longitude: -102.5528),
                span: MKCoordinateSpan(latitudeDelta: 20.0, longitudeDelta: 20.0)
            )
        case "GB":
            // 英国
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 54.0, longitude: -2.0),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            )
        case "FR":
            // 法国
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 46.2276, longitude: 2.2137),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            )
        case "DE":
            // 德国
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 51.1657, longitude: 10.4515),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 10.0)
            )
        case "IT":
            // 意大利
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 41.8719, longitude: 12.5674),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            )
        case "ES":
            // 西班牙
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 40.4637, longitude: -3.7492),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            )
        case "NL":
            // 荷兰
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 52.1326, longitude: 5.2913),
                span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 3.0)
            )
        case "CH":
            // 瑞士
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 46.8182, longitude: 8.2275),
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            )
        case "AT":
            // 奥地利
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 47.5162, longitude: 14.5501),
                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 5.0)
            )
        case "BE":
            // 比利时
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 50.5039, longitude: 4.4699),
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            )
        case "DK":
            // 丹麦
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 56.2639, longitude: 9.5018),
                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
            )
        case "FI":
            // 芬兰
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 61.9241, longitude: 25.7482),
                span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 10.0)
            )
        case "NO":
            // 挪威
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 60.4720, longitude: 8.4689),
                span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 8.0)
            )
        case "SE":
            // 瑞典
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 60.1282, longitude: 18.6435),
                span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 8.0)
            )
        case "PL":
            // 波兰
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 51.9194, longitude: 19.1451),
                span: MKCoordinateSpan(latitudeDelta: 6.0, longitudeDelta: 8.0)
            )
        case "CZ":
            // 捷克
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 49.8175, longitude: 15.4730),
                span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 4.0)
            )
        case "HU":
            // 匈牙利
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 47.1625, longitude: 19.5033),
                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
            )
        case "GR":
            // 希腊
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.0742, longitude: 21.8243),
                span: MKCoordinateSpan(latitudeDelta: 7.0, longitudeDelta: 8.0)
            )
        case "PT":
            // 葡萄牙
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.3999, longitude: -8.2245),
                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 4.0)
            )
        case "IE":
            // 爱尔兰
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 53.4129, longitude: -8.2439),
                span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 4.0)
            )
        case "LU":
            // 卢森堡
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 49.8153, longitude: 6.1296),
                span: MKCoordinateSpan(latitudeDelta: 0.8, longitudeDelta: 0.8)
            )
        case "RU":
            // 俄罗斯
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 61.5240, longitude: 105.3188),
                span: MKCoordinateSpan(latitudeDelta: 50.0, longitudeDelta: 80.0)
            )
        case "UA":
            // 乌克兰
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 48.3794, longitude: 31.1656),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 12.0)
            )
        case "TR":
            // 土耳其
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 38.9637, longitude: 35.2433),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 12.0)
            )
        case "IL":
            // 以色列
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 31.0461, longitude: 34.8516),
                span: MKCoordinateSpan(latitudeDelta: 2.0, longitudeDelta: 2.0)
            )
        case "AE":
            // 阿联酋
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 23.4241, longitude: 53.8478),
                span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
            )
        case "SA":
            // 沙特阿拉伯
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 23.8859, longitude: 45.0792),
                span: MKCoordinateSpan(latitudeDelta: 15.0, longitudeDelta: 20.0)
            )
        case "QA":
            // 卡塔尔
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 25.3548, longitude: 51.1839),
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            )
        case "KW":
            // 科威特
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 29.3759, longitude: 47.9774),
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            )
        case "BH":
            // 巴林
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 26.0667, longitude: 50.5577),
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            )
        case "OM":
            // 阿曼
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 21.4735, longitude: 55.9754),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            )
        case "JO":
            // 约旦
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 30.5852, longitude: 36.2384),
                span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 4.0)
            )
        case "LB":
            // 黎巴嫩
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 33.8547, longitude: 35.8623),
                span: MKCoordinateSpan(latitudeDelta: 1.5, longitudeDelta: 1.5)
            )
        case "EG":
            // 埃及
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 26.0975, longitude: 31.2357),
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 12.0)
            )
        case "ZA":
            // 南非
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -30.5595, longitude: 22.9375),
                span: MKCoordinateSpan(latitudeDelta: 20.0, longitudeDelta: 20.0)
            )
        case "BR":
            // 巴西
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -14.2350, longitude: -51.9253),
                span: MKCoordinateSpan(latitudeDelta: 35.0, longitudeDelta: 45.0)
            )
        case "AR":
            // 阿根廷
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -38.4161, longitude: -63.6167),
                span: MKCoordinateSpan(latitudeDelta: 30.0, longitudeDelta: 20.0)
            )
        case "CL":
            // 智利
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -35.6751, longitude: -71.5430),
                span: MKCoordinateSpan(latitudeDelta: 30.0, longitudeDelta: 5.0)
            )
        case "CO":
            // 哥伦比亚
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 4.5709, longitude: -74.2973),
                span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 12.0)
            )
        case "PE":
            // 秘鲁
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: -9.1900, longitude: -75.0152),
                span: MKCoordinateSpan(latitudeDelta: 20.0, longitudeDelta: 15.0)
            )
        case "IS":
            // 冰岛
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 64.9631, longitude: -19.0208),
                span: MKCoordinateSpan(latitudeDelta: 4.0, longitudeDelta: 6.0)
            )
        default:
            // 其他国家 - 使用一个合理的世界地图视野作为默认值
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 30.0, longitude: 0.0),
                span: MKCoordinateSpan(latitudeDelta: 60.0, longitudeDelta: 120.0)
            )
        }
    }
    
    // 将地图定位到用户选择的国家
    func centerMapOnSelectedCountry() {
        let countryCode = countryManager.currentCountry.rawValue
        let region = getRegionForCountry(countryCode: countryCode, userLocation: CLLocationCoordinate2D(latitude: 0, longitude: 0))
        
        withAnimation(.easeInOut(duration: 0.5)) {
            mapCameraPosition = .region(region)
        }
        print("📍 地图定位到用户选择的国家: \(countryManager.currentCountry.displayName) (\(countryCode))")
    }
    
    // 移动地图到指定地点，以国家视野范围定位到目的地为中心
    func moveMapToDestination(_ destination: TravelDestination) {
        // 获取地点的国家名称
        let countryName = destination.country
        
        // 根据国家名称获取国家代码
        let countryCode = getCountryCodeFromName(countryName)
        
        // 获取预设的国家视野范围
        let countryRegion = getRegionForCountry(countryCode: countryCode, userLocation: destination.coordinate)
        
        // 创建以目的地为中心，使用国家视野范围的新区域
        let region = MKCoordinateRegion(
            center: destination.coordinate, // 以目的地为中心
            span: countryRegion.span // 使用国家的视野范围
        )
        
        // 直接跳到目标位置，不使用动画
        mapCameraPosition = .region(region)
        
        print("🫧 地图移动到地点: \(destination.name) (\(countryName) - \(countryCode))")
    }
    
    // 根据国家名称获取国家代码
    func getCountryCodeFromName(_ countryName: String) -> String {
        switch countryName.lowercased() {
        case "中国", "china", "cn":
            return "CN"
        case "美国", "united states", "usa", "us":
            return "US"
        case "日本", "japan", "jp":
            return "JP"
        case "韩国", "south korea", "korea", "kr":
            return "KR"
        case "新加坡", "singapore", "sg":
            return "SG"
        case "泰国", "thailand", "th":
            return "TH"
        case "马来西亚", "malaysia", "my":
            return "MY"
        case "印度尼西亚", "indonesia", "id":
            return "ID"
        case "菲律宾", "philippines", "ph":
            return "PH"
        case "越南", "vietnam", "vn":
            return "VN"
        case "印度", "india", "in":
            return "IN"
        case "澳大利亚", "australia", "au":
            return "AU"
        case "新西兰", "new zealand", "nz":
            return "NZ"
        case "加拿大", "canada", "ca":
            return "CA"
        case "墨西哥", "mexico", "mx":
            return "MX"
        case "英国", "united kingdom", "uk", "gb":
            return "GB"
        case "法国", "france", "fr":
            return "FR"
        case "德国", "germany", "de":
            return "DE"
        case "意大利", "italy", "it":
            return "IT"
        case "西班牙", "spain", "es":
            return "ES"
        case "荷兰", "netherlands", "nl":
            return "NL"
        case "瑞士", "switzerland", "ch":
            return "CH"
        case "奥地利", "austria", "at":
            return "AT"
        case "比利时", "belgium", "be":
            return "BE"
        case "丹麦", "denmark", "dk":
            return "DK"
        case "瑞典", "sweden", "se":
            return "SE"
        case "挪威", "norway", "no":
            return "NO"
        case "芬兰", "finland", "fi":
            return "FI"
        case "俄罗斯", "russia", "ru":
            return "RU"
        case "巴西", "brazil", "br":
            return "BR"
        case "阿根廷", "argentina", "ar":
            return "AR"
        case "智利", "chile", "cl":
            return "CL"
        case "哥伦比亚", "colombia", "co":
            return "CO"
        case "秘鲁", "peru", "pe":
            return "PE"
        case "冰岛", "iceland", "is":
            return "IS"
        default:
            // 如果找不到匹配的国家，使用默认的世界视野
            return "DEFAULT"
        }
    }
    
    // 将地图定位到当前位置
    func centerMapOnCurrentLocation() {
        // 冷启动尚未锁定时并入初始 settle，避免与 withAnimation 抢相机后又被拉回 fallback
        if !MapView.hasCompletedInitialCameraSettlement, !autoShowRouteCards {
            locationManager.startUpdatingLocation(mode: .mapBrowsing)
            locationManager.requestLocation()
            if let userLocation = locationManager.lastKnownLocation {
                applyInitialCamera(to: userLocation, animated: false)
                print("📍 定位按钮：并入初始相机锁定")
            } else {
                waitingForLocationToSetCamera = true
                print("⏳ 定位按钮：等待初始定位…")
            }
            return
        }
        
        if let userLocation = locationManager.lastKnownLocation {
            locationManager.startUpdatingLocation(mode: .mapBrowsing)
            setCameraToUserLocation(userLocation)
            print("📍 定位到当前位置")
            return
        }
        
        isWaitingForUserLocate = true
        locationManager.startUpdatingLocation(mode: .checkIn)
        locationManager.requestLocation()
        print("⏳ 定位按钮：正在获取当前位置...")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            guard self.isWaitingForUserLocate else { return }
            self.isWaitingForUserLocate = false
            self.restoreMapBrowsingLocationModeIfNeeded()
            print("⏰ 定位按钮：获取位置超时")
        }
    }
}
