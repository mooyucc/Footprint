//
//  DestinationDataRevision.swift
//  Footprint
//
//  O(1) change tracking for destination-derived stats (profile, badges, year views).
//

import Foundation
import Combine

/// 地点数据变更版本号：写入时 post 通知即可自动 bump，各 Tab 按需刷新缓存。
@MainActor
final class DestinationDataRevision: ObservableObject {
    static let shared = DestinationDataRevision()

    @Published private(set) var revision = 0

    private var cancellables = Set<AnyCancellable>()

    private init() {
        let names: [Notification.Name] = [
            .destinationUpdated,
            .destinationDeleted,
            .countryChanged,
            .tripUpdated
        ]
        for name in names {
            NotificationCenter.default.publisher(for: name)
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.revision &+= 1
                }
                .store(in: &cancellables)
        }
    }
}

enum DestinationChangeNotifier {
    static func postUpdated() {
        NotificationCenter.default.post(name: .destinationUpdated, object: nil)
    }
}
