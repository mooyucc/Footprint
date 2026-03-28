# 现代 UI 风格指南（旅行统计 / 年度记录 / 分享图）

本文档总结 Footprint 中「旅行统计」及相关页面已采用的**现代 UI 风格**，便于在其它界面沿用或微调。与项目内 `ContentView`（Profile）、`YearFilteredDestinationView`、`StatsImageGenerator` 等实现保持一致。

---

## 1. 设计意图

- **内容优先**：统计与列表直接铺在页面渐变背景上，减少「大块白底卡片 + 重阴影」的厚重感。
- **数字主视觉**：指标以**大号、重字重、略紧字距**的数字为第一视觉，说明文字退居次要层级。
- **品牌色只点睛**：图标与区块识别用小面积品牌色；数字正文使用系统主色（`.primary` / 近 `#333` 的深灰语义），避免彩虹色块抢戏。
- **与系统一致**：圆角优先 **continuous**、间距参考 12 / 16 / 20；动效时长与曲线与「点亮进度」等处统一。

---

## 2. 区块标题（Section Header）

- **左侧图标**：`chart.bar.fill`（旅行统计）或语义相近的 SF Symbol（如年度页仍可用同一套以保持一致）。
- **颜色**：`BrandColorManager.shared.currentBrandColor`（SwiftUI `foregroundColor`）。
- **字号**：图标 `.headline` 量级；标题文案 `.headline` + `.semibold`。
- **文案**：优先与 App 内 Tab 一致（如 `travel_statistics`、`year_travel_statistics`）。

---

## 3. 统计栅格（2×2）

与「我的」页 `ProfileStatCard` 栅格一致：

| 顺序 | 图标 | 说明文案 Key（示例） |
|------|------|----------------------|
| 1 | `flag.fill` | `total_destinations` |
| 2 | `globe.asia.australia.fill` | `countries_visited` |
| 3 | `house.fill` | `domestic_travel` |
| 4 | `airplane` | `international_travel` |

- **布局**：`LazyVGrid`，两列 `GridItem(.flexible(), spacing: 12)`，行间距 `12`。
- **单格内容**：左对齐 `VStack` — 上：品牌色图标（`.headline`）；中：数字；下：`.caption` + `.secondary` 说明，允许 `lineLimit(2)`。
- **不要**：浅色图标背板（如 `color.opacity(0.15)` 的方框）、整格米色/白色卡片底（除非有特殊原因）。

---

## 4. 数字样式（核心）

**展示**

- 字体：`UIFont.monospacedDigitSystemFont` 或 SwiftUI `.monospacedDigit()`。
- 字重：`.black`（或与 `.system(size:weight:.black)` 等价）。
- 字号：**列表/栅格内**约 34–36 pt（手机）；分享图等需按画布等比放大。
- 字距：`.tracking` 约 **-0.8 ~ -1.2**，避免松散。
- 颜色：`.foregroundStyle(.primary)`（或分享图上的深灰主色）。

**动效（与「点亮进度」一致）**

- 内部 `@State private var animatedValue: Double`。
- 展示：`Int(animatedValue.rounded())`，并加 `.contentTransition(.numericText(value: animatedValue))`（需 iOS 17+，项目最低 iOS 18 可满足）。
- **首次出现**：`animatedValue = 0`，短延迟后 `withAnimation(.easeOut(duration: 0.9))` 到目标值。
- **数据变化**：`withAnimation(.easeOut(duration: 0.55))` 过渡到新值。
- `onChange(of: targetValue)` 驱动更新，避免只依赖 `onAppear`。

---

## 5. 列表与卡片（目的地行）

参考 `DestinationRowCard`（年度 Travel Records）：

- **圆角**：`RoundedRectangle(cornerRadius: 18, style: .continuous)`，图片与遮罩与外层 clip 统一。
- **高度**：约 168 pt（可按内容微调），保持一行信息密度舒适。
- **标题**：`.system(size: 22, weight: .black)`，略 `tracking`，白字 + 轻阴影以保证叠在图上可读。
- **描边**：`Color.primary.opacity(浅 0.08 / 深 0.12)` 级别细线，代替粗米色描边。
- **阴影**：浅模式约 `black.opacity(0.1)`、半径偏大、略向下；深模式可略加重。
- **外层容器**：列表区块**不必**再包一层大白卡；标题与行纵向排列即可。

---

## 6. 分享图（`StatsImageGenerator`）

与 App 内「旅行统计」语义对齐，而非旧版「米色大卡片 + 白底三列」：

- **无**大圆角实心卡片底板；内容画在全局渐变上。
- **旅行统计**：品牌色图标 + `travel_statistics` + 2×2 栅格，文案 key 与 App 一致。
- **时间线**：无整块白卡；`travel_timeline` + 每行「年份 + destinations_count 小字 + 品牌→紫渐变条 + 右侧大号数字」。
- **数字**：等宽、粗体、负字距；渐变条失败时应有单色兜底，避免整段绘制中断。

---

## 7. 依赖与环境

- **品牌色**：视图需能访问 `BrandColorManager`（`@EnvironmentObject` 或 `BrandColorManager.shared`）；`UIColor(BrandColorManager.shared.currentBrandColor)` 用于 UIKit 绘制。
- **背景**：页面级使用现有 `appPageBackgroundGradient(for:)`，与现代无卡片统计区搭配。
- **本地化**：统计标签统一走现有 `.localized` key，避免分享图与 App 文案两套体系长期分叉。

---

## 8. 接入新页面时的检查清单

- [ ] 区块标题是否为「品牌色图标 + 主色标题」，且无多余卡片底？
- [ ] 统计是否为 2×2（或刻意设计的变体），且数字为黑粗 + 等宽 + 负字距？
- [ ] 是否加了递增动效（`contentTransition` + `easeOut` 两段时长）？
- [ ] 列表是否去掉外层白卡，单行卡片圆角是否为 18 continuous？
- [ ] 深色模式下描边/阴影是否仍可读、不过重？

---

## 9. 代码锚点（便于搜索）

| 区域 | 主要文件 |
|------|----------|
| 我的 · 旅行统计 | `ContentView.swift` — `ProfileStatCard`、`statisticsCard` |
| 点亮进度数字参考 | `BadgeView.swift` — 百分比大数字 + `contentTransition` |
| 年度 Travel Records | `YearFilteredDestinationView.swift` — `YearStatisticsCard`、`YearAnimatedStatCell`、`DestinationRowCard` |
| 分享图 | `StatsImageGenerator.swift` |

---

*文档版本：与 2026-03 工程内实现对齐；后续若全局改版，请同步更新本节与锚点表。*
