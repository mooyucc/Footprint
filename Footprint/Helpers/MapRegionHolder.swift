//
//  MapRegionHolder.swift
//  Footprint
//
//  非 Observable 地图区域持有者：避免 onMapCameraChange(.continuous) 每帧写 @State 触发 MapView 重绘。
//

import MapKit

final class MapRegionHolder {
    var pending: MKCoordinateRegion?
    private var debounceWorkItem: DispatchWorkItem?
    
    func scheduleDebouncedCommit(interval: TimeInterval = 0.3, _ action: @escaping () -> Void) {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem(block: action)
        debounceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: work)
    }
    
    func cancelDebounce() {
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
    }
}
