//
//  SystemShareSheet.swift
//  Footprint
//
//  Created on 2026/01/26.
//  系统分享表单组件，从 TripImageGenerator.swift 提取
//

import SwiftUI
import UIKit

/// 系统分享表单组件
struct SystemShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
