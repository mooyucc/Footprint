//
//  MediaViewerPresentation.swift
//  Footprint
//
//  将全屏看图上提到地点 sheet 之外呈现，避免下拉关图时带动 sheet。
//

import SwiftUI

struct MediaViewerSession: Identifiable, Equatable {
    let id: UUID
    var items: [MediaFullscreenItem]
    var index: Int
    
    init(items: [MediaFullscreenItem], index: Int) {
        self.id = UUID()
        self.items = items
        self.index = min(max(index, 0), max(items.count - 1, 0))
    }
    
    static func == (lhs: MediaViewerSession, rhs: MediaViewerSession) -> Bool {
        lhs.id == rhs.id && lhs.index == rhs.index
    }
}

struct PresentMediaViewerAction {
    let handler: ([MediaFullscreenItem], Int) -> Void
    
    func callAsFunction(_ items: [MediaFullscreenItem], index: Int) {
        handler(items, index)
    }
}

private struct PresentMediaViewerKey: EnvironmentKey {
    static let defaultValue: PresentMediaViewerAction? = nil
}

extension EnvironmentValues {
    var presentMediaViewer: PresentMediaViewerAction? {
        get { self[PresentMediaViewerKey.self] }
        set { self[PresentMediaViewerKey.self] = newValue }
    }
}
