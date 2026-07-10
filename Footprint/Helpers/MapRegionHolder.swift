//
//  MapRegionHolder.swift
//  Footprint
//
//  非 Observable 地图区域持有者：避免 onMapCameraChange(.continuous) 每帧写 @State 触发 MapView 重绘。
//

import MapKit

final class MapRegionHolder {
    var pending: MKCoordinateRegion?
}
