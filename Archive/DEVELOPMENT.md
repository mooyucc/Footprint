# 开发指南

## 快速开始

### 运行应用

1. 使用 Xcode 打开 `Footprint.xcodeproj`
2. 选择 iPhone 模拟器或真机
3. 点击运行按钮（⌘R）

### 使用示例数据

应用首次启动时是空的。如果你想快速查看应用的效果，可以添加示例数据：

在 `FootprintApp.swift` 中添加以下代码：

```swift
import SwiftUI
import SwiftData

@main
struct FootprintApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TravelDestination.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // 添加示例数据（仅用于开发测试）
            Task { @MainActor in
                SampleData.createSampleDestinations(in: container.mainContext)
            }
            
            return container
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
```

**注意**: 示例数据只会在数据库为空时添加，不会重复添加。

### 清除数据

如果需要清除所有数据重新开始，可以：

1. 删除应用并重新安装
2. 或者在代码中调用：
   ```swift
   SampleData.clearAllData(in: modelContext)
   ```

## 项目架构

### MVVM 模式

- **Models**: 数据模型（TravelDestination）
- **Views**: 视图层
  - MapView: 地图展示
  - DestinationListView: 列表展示
  - AddDestinationView: 添加目的地
  - DestinationDetailView: 详情展示
  - ProfileView: 个人中心
- **ViewModels**: 使用 SwiftData 的 @Query 宏自动管理

### 数据流

```
User Action → View → SwiftData ModelContext → Update → View Refresh
```

## 权限说明

应用需要以下权限：

1. **位置服务**: 用于搜索地点（不存储用户位置）
2. **照片库**: 用于选择和保存照片

在 `Info.plist` 中需要添加：

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>我们需要访问你的位置来搜索旅行目的地</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>我们需要访问你的照片库以添加旅行照片</string>
```

## 调试技巧

### 查看 SwiftData 数据

在 Xcode 中打开 Debug View Hierarchy 可以查看数据库内容。

### 常见问题

1. **地图不显示**: 检查模拟器是否有网络连接
2. **照片选择器不工作**: 检查照片权限
3. **数据不保存**: 检查 ModelContext 是否正确注入

## 代码规范

- 使用 Swift 官方代码风格
- 视图文件使用 `View` 后缀
- 模型文件使用清晰的名称
- 添加必要的注释
- 使用 `// MARK:` 分隔代码块

## 性能优化

1. 图片压缩存储
2. 使用 LazyVStack/LazyHStack
3. 合理使用 @Query 的过滤条件
4. 避免在主线程执行耗时操作

## 测试

### 单元测试

在 `FootprintTests` 目录中添加测试：

```swift
import XCTest
@testable import Footprint

final class TravelDestinationTests: XCTestCase {
    func testCoordinate() {
        let destination = TravelDestination(
            name: "Test",
            country: "Test Country",
            latitude: 10.0,
            longitude: 20.0
        )
        
        XCTAssertEqual(destination.coordinate.latitude, 10.0)
        XCTAssertEqual(destination.coordinate.longitude, 20.0)
    }
}
```

## 发布准备

### App Store 提交清单

- [ ] 更新版本号
- [ ] 添加应用图标
- [ ] 准备截图（至少 5 张）
- [ ] 编写 App Store 描述
- [ ] 测试所有功能
- [ ] 检查权限说明
- [ ] 代码签名配置

### 应用图标建议

在 `Assets.xcassets/AppIcon.appiconset` 中添加以下尺寸的图标：
- 1024x1024 (App Store)
- 180x180 (iPhone)
- 120x120 (iPhone)
- 87x87 (iPhone)
- 80x80 (iPhone)
- 58x58 (iPhone)
- 60x60 (iPhone)
- 40x40 (iPhone)

建议使用地图或足迹相关的图标设计。

## 扩展功能建议

1. **Widget 小组件**: 显示旅行统计
2. **Apple Watch 扩展**: 快速查看足迹
3. **iCloud 同步**: 多设备数据同步
4. **导出功能**: PDF、CSV 格式导出
5. **社交功能**: 分享到微信、微博等
6. **AR 功能**: AR 地球仪查看足迹

---

Happy Coding! 🚀

