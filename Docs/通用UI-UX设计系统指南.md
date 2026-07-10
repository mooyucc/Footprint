# 通用 UI/UX 设计系统指南

本文档从 Footprint 项目中提炼**可复用到其他 iOS App** 的 UI/UX 做法，不含地图、旅程、徽章等业务专属内容。与工程内 `AppColorScheme.swift`、`SettingsView.swift`、`ContentView.swift`（`ProfileStatCard`）等实现保持一致。

---

## 1. 设计理念

### 1.1 四条核心原则

| 原则 | 做法 |
|------|------|
| **内容优先** | 信息直接铺在页面渐变背景上，减少「大白卡 + 重阴影」的包裹感 |
| **数字主视觉** | 关键指标用大号、粗体、等宽、略紧字距的数字；说明文字退到次要层级 |
| **品牌色点睛** | 品牌色只用于图标、进度、选中态等小面积；正文数字用 `.primary` |
| **系统原生** | 圆角优先 **continuous**、颜色用语义色、组件优先 SwiftUI 标准控件 |

### 1.2 平台兼容策略

- **目标平台**：iOS 26+；**最低兼容**：iOS 18
- 新 API（如 `glassEffect`、`contentTransition`）必须带 `if #available` 降级
- **降级路径**：Glass → Material；新动画 → `.easeOut` + `.spring()`

---

## 2. 视觉语言

### 2.1 页面背景（全局基调）

**推荐做法**：全 App 页面统一用渐变背景，而不是单色或纯白。

| 模式 | 配色 |
|------|------|
| 浅色模式 | `Color.blue.opacity(0.12)` → `Color.pink.opacity(0.08)` → `Color(.systemBackground)`，纵向渐变 |
| 深色模式 | `Color(.systemGroupedBackground)` |

封装为 View 修饰符，所有 `ScrollView` / `List` 根视图统一调用：

```swift
@Environment(\.colorScheme) var colorScheme

ScrollView {
    // 内容
}
.appPageBackgroundGradient(for: colorScheme)
```

**可复用价值**：低成本建立品牌感，又不会像大面积纯色那样厚重。

---

### 2.2 品牌色系统

| 层级 | 用法 |
|------|------|
| **品牌主色** | 图标、进度条、Tab 选中、强调元素 |
| **正文/数字** | `.primary` |
| **辅助文字** | `.secondary` / `.tertiary` |
| **按钮图标** | `.primary`（配合玻璃/材质背景） |

**关键模式**：品牌色做成全局可观察对象（`ObservableObject`），通过 `@EnvironmentObject` 注入，用户修改后全 App 实时刷新。

```swift
// App 入口
@StateObject private var brandColorManager = BrandColorManager.shared

ContentView()
    .environmentObject(brandColorManager)
    .tint(brandColorManager.currentBrandColor)
```

> **工程默认值**：`#00A1D8`（RGB: 0, 161, 216）。以 `AppColorScheme.swift` 中 `BrandColorManager.defaultBrandColor` 为准。

---

### 2.3 卡片体系（五类）

| 类型 | 适用场景 | 关键样式 |
|------|----------|----------|
| **无底色内容区** | 统计、指标展示 | 直接铺在页面渐变上，不加外层白卡 |
| **图片内容卡** | 列表行、封面展示 | 圆角 18 continuous、照片背景 + 底部渐变遮罩、白字标题 |
| **白卡片** | 常规信息块 | 白底/系统次要背景、圆角 15、轻阴影 |
| **浅米色卡片** | 提示、气泡、说明 | 暖色底 `#FAF8F5` + 细边框 `#EAE6DF` |
| **玻璃卡片** | 浮层、弹出面板 | Material / `glassEffect` + 语义色文字 |

**现代风格趋势**（Footprint 已在做的）：

- 能不用外层白卡就不用
- 能不用图标浅色背板（`color.opacity(0.15)` 方框）就不用
- 用细描边（`primary.opacity(0.08~0.12)`）代替粗边框

#### 统一工具方法

```swift
.whiteCardStyle(for: colorScheme, cornerRadius: 15)
.beigeCardStyle(for: colorScheme, cornerRadius: 15)
.glassCardStyle(material: .ultraThinMaterial, for: colorScheme)
```

---

### 2.4 数字样式（高复用签名）

统计、进度、计数类界面统一：

```swift
Text("\(Int(animatedValue.rounded()))")
    .font(.system(size: 34...36, weight: .black))
    .tracking(-0.8 ... -1.2)
    .monospacedDigit()
    .foregroundStyle(.primary)
    .contentTransition(.numericText(value: animatedValue))  // iOS 17+
```

**递增动效标准节奏**：

| 场景 | 做法 |
|------|------|
| 首次出现 | `animatedValue = 0`，短延迟（约 0.06s）后 `easeOut(duration: 0.9)` 到目标值 |
| 数据更新 | `easeOut(duration: 0.55)` 过渡到新值 |
| 驱动方式 | `onChange(of: targetValue)` 驱动，避免只依赖 `onAppear` |

参考实现：`ContentView.swift` — `ProfileStatCard`；`BadgeView.swift` — 点亮进度百分比。

---

### 2.5 区块标题（Section Header）

通用模板：

- **左侧**：品牌色 SF Symbol（`.headline` 量级）
- **右侧**：`.headline` + `.semibold` 标题文案
- **布局**：标题下方直接接内容，不再套一层大卡片

---

### 2.6 统计栅格（2×2 模式）

任意 App 有 4 个核心指标时都可复用：

```swift
LazyVGrid(columns: [
    GridItem(.flexible(), spacing: 12),
    GridItem(.flexible(), spacing: 12)
], spacing: 12) {
    // 每格：品牌色图标 → 大数字 → .caption 说明
}
```

- 每格内容：左对齐 `VStack`
- 图标：品牌色，`.headline`
- 数字：见 §2.4
- 说明：`.caption` + `.secondary`，允许 `lineLimit(2)`

---

### 2.7 图片内容卡（列表行）

参考 `YearFilteredDestinationView.swift` — `DestinationRowCard`：

| 属性 | 值 |
|------|-----|
| 圆角 | `RoundedRectangle(cornerRadius: 18, style: .continuous)` |
| 高度 | 约 168 pt |
| 标题 | `.system(size: 22, weight: .black)`，略 `tracking`，白字 + 轻阴影 |
| 遮罩 | 顶部透明 → 底部 `black.opacity(0.58)` 渐变 |
| 描边 | `Color.primary.opacity(0.08~0.12)` 细线 |
| 阴影 | 浅模式 `black.opacity(0.1)`，深模式可略加重 |

---

## 3. 交互模式

### 3.1 导航结构

| 模式 | 用途 |
|------|------|
| `TabView` + `NavigationStack` | 浅层次主导航 |
| `.sheet()` | 设置子页、编辑页、选择器 |
| 设置分层 | 主设置页只做入口，具体选项进子 Sheet |

### 3.2 设置行标准样式

```
[品牌色图标]  标题（.primary）    当前值 / chevron
```

使用 `SettingsRowLabel`：图标保留品牌色，文字使用 `.primary`。

### 3.3 反馈与状态

| 场景 | 做法 |
|------|------|
| 数据变化 | 数字递增动画（§2.4） |
| 选项切换 | `.spring(response: 0.3, dampingFraction: 0.8)` |
| 批量操作 | 半透明遮罩 + `.regularMaterial` 进度面板 |
| 破坏性操作 | Alert 警告 → 输入关键词确认 Sheet |

### 3.4 触控与无障碍

- 可点击区域最小 **44×44 pt**
- 玻璃/材质按钮必须加 `.contentShape()`，避免只有图标能点
- 文字用语义色 + 支持动态字体
- 所有可见文案走 `.localized`

---

## 4. 通用 UI 设置架构

与具体业务无关、可移植到其他 App 的设置层设计。

### 4.1 外观模式（深浅色）

| 项 | 说明 |
|----|------|
| 管理类 | `AppearanceManager.shared` |
| 存储键 | `UserDefaults: "AppearanceMode"` |
| 选项 | `system`（跟随系统）/ `dark` / `light` |
| 默认值 | `system` |
| 应用方式 | 根视图 `.preferredColorScheme(appearanceManager.preferredColorScheme)` |
| UI 控件 | 分段选择器（Segmented Picker） |
| 设置入口 | 通用设置 Sheet |

```swift
// FootprintApp.swift
.preferredColorScheme(appearanceManager.preferredColorScheme)
```

---

### 4.2 品牌颜色（主题色）

| 项 | 说明 |
|----|------|
| 管理类 | `BrandColorManager.shared` |
| 存储键 | `UserDefaults: "CustomBrandColor"`（RGB 分量序列化） |
| 默认色 | `#00A1D8` |
| 自定义 | `ColorPicker`，`supportsOpacity: false` |
| 广播 | `@Published currentBrandColor` + `Notification.Name.brandColorChanged` |
| 影响范围 | Tab 选中色、图标、进度条、导出图等 |
| 重置 | 「恢复默认」按钮，仅自定义激活时可点 |

```swift
// 视图中使用
@EnvironmentObject var brandColorManager: BrandColorManager

Image(systemName: "star.fill")
    .foregroundColor(brandColorManager.currentBrandColor)
```

---

### 4.3 语言

| 项 | 说明 |
|----|------|
| 管理类 | `LanguageManager.shared` |
| 存储键 | `UserDefaults: "SelectedLanguage"` |
| 机制 | 动态切换 `Bundle`，`.localized` 扩展即时生效 |
| 默认值 | 检测系统语言，不支持则回退英文 |
| UI | 设置页显示国旗 + 语言名，点进选择 Sheet |

---

### 4.4 设置页信息架构（通用模板）

```
设置
├── 账户区（头像、基本信息、登录状态）
├── 通用设置 → Sheet
│   ├── 语言
│   ├── 外观模式（深浅色）
│   └── 品牌颜色
├── 数据设置 → Sheet（导入/导出/清理等）
└── 关于
```

**要点**：主 `List` 只做导航入口；复杂表单放 Sheet；每行用 `SettingsRowLabel` 保持视觉一致。

---

## 5. 工具类架构（推荐复用）

```
App 入口
  ├── .environmentObject(BrandColorManager)
  ├── .environmentObject(AppearanceManager)
  ├── .environmentObject(LanguageManager)
  └── .preferredColorScheme(...)

设计 Token 层（AppColorScheme）
  ├── 页面渐变 pageBackgroundGradient
  ├── 卡片背景/边框/阴影
  └── 按钮、进度条配色

View 修饰符
  ├── .appPageBackgroundGradient
  ├── .whiteCardStyle / .beigeCardStyle / .glassCardStyle
  └── .brandColorAware

可复用组件
  ├── StatCard（数字 + 图标 + 递增动画）
  ├── ImageRowCard（图片背景列表行）
  └── SettingsRowLabel（设置行）
```

---

## 6. Liquid Glass 通用规范（iOS 26+）

与具体业务无关的使用边界：

| 应该用 | 不应该用 |
|--------|----------|
| 底部导航（系统自动） | 长列表每行背景 |
| 浮层工具条、少量核心按钮 | 主阅读区大面积铺底 |
| 面板顶部、弹出层 | 多层玻璃叠放 |

**标准写法**：

```swift
if #available(iOS 26, *) {
    content
        .glassEffect(.regular.interactive(), in: Circle())
        .contentShape(Circle())  // 必须：保证完整触控区域
} else {
    content
        .background(.ultraThinMaterial, in: Circle())
        .contentShape(Circle())
}
```

**要点**：

- `.regular.interactive()` 提供标准强度与触控反馈
- `.contentShape()` 在 `.glassEffect()` 之后添加，确保 padding 区域可点击
- iOS 18–25 降级使用 `.ultraThinMaterial` 或 `.regularMaterial`

---

## 7. App 内与导出图一致

只要 App 会生成分享图、海报或截图，应遵循：

- 统计文案 key 与 App 内一致（统一 `.localized`）
- 数字样式（等宽、粗体、负字距）一致
- 背景渐变语义一致
- 品牌色从同一个 `BrandColorManager` 读取

避免「App 内一套、分享图另一套」长期分叉。参考：`StatsImageGenerator.swift`、`TripImageGenerator.swift`。

---

## 8. 新页面接入检查清单

- [ ] 页面根视图是否用了统一渐变背景（`.appPageBackgroundGradient`）？
- [ ] 关键数字是否：黑粗 + 等宽 + 负字距 + 递增动效？
- [ ] 品牌色是否只用于图标/强调，数字是否用 `.primary`？
- [ ] 是否去掉了不必要的外层白卡？
- [ ] 内容卡片圆角是否为 18 continuous？
- [ ] 玻璃控件是否有 `.contentShape()`？
- [ ] 深浅色下描边/阴影是否仍可读、不过重？
- [ ] 文案是否全部本地化？
- [ ] 分享图/导出图是否与 App 内语义对齐？

---

## 9. 最小可复用包

带到新项目，建议优先移植以下 8 项：

| # | 模块 | 文件 |
|---|------|------|
| 1 | 配色 Token + View 修饰符 | `Helpers/AppColorScheme.swift` |
| 2 | 可自定义主题色 | `BrandColorManager`（同上） |
| 3 | 深浅色三档 | `AppearanceManager`（同上） |
| 4 | 多语言切换 | `Helpers/LanguageManager.swift` |
| 5 | 页面渐变修饰符 | `.appPageBackgroundGradient`（同上） |
| 6 | 数字主视觉 + 动画 | `ProfileStatCard`（`ContentView.swift`） |
| 7 | 设置行一致性 | `SettingsRowLabel`（`SettingsView.swift`） |
| 8 | 新 API 降级策略 | 各视图 `if #available(iOS 26, *)` 分支 |

---

## 10. 代码锚点（便于搜索）

| 区域 | 主要文件 |
|------|----------|
| 配色与卡片样式 | `Helpers/AppColorScheme.swift` |
| 品牌色 / 外观模式 | `AppColorScheme.swift` — `BrandColorManager`、`AppearanceManager` |
| 统计数字卡片 | `ContentView.swift` — `ProfileStatCard` |
| 递增动效参考 | `BadgeView.swift` — 百分比大数字 + `contentTransition` |
| 图片列表行 | `YearFilteredDestinationView.swift` — `DestinationRowCard` |
| 设置页架构 | `SettingsView.swift` — `GeneralSettingsView`、`SettingsRowLabel` |
| 多语言 | `Helpers/LanguageManager.swift` |
| 分享图一致性 | `Helpers/StatsImageGenerator.swift` |
| 现代 UI 风格（统计/列表） | `Docs/现代UI风格指南-旅行统计与列表.md` |
| 完整配色标准 | `Docs/App配色标准.md` |
| iOS 设计规范 | `.cursor/rules/my-uiux-standard.mdc` |

---

*文档版本：2026-07；提炼自 Footprint 工程实践，不含地图等业务专属 UI。*
