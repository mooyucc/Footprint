# Footprint App 配色标准

> **版本**: 1.0  
> **创建日期**: 2025-01-27  
> **设计参考**: 墨鱼足迹品牌视觉规范

本文档定义了Footprint应用的整体配色系统，确保应用在所有界面中保持一致的视觉风格和优雅的用户体验。

---

## 一、设计理念

### 1.1 核心配色原则

Footprint采用**温暖、优雅、现代**的配色方案，以米色系为主基调，配合黑色、白色、灰色和红色强调色，营造出：

- **温暖感**：米色渐变背景带来舒适、柔和的视觉体验
- **优雅感**：低饱和度的配色和精致的层次感
- **现代感**：清晰的对比度和简洁的设计语言

### 1.2 色彩层级

采用**三层色彩系统**：
1. **背景层**：页面背景、渐变背景
2. **卡片层**：大卡片、小卡片、半透明卡片
3. **内容层**：文字、图标、交互元素

---

## 二、主色调定义

### 2.1 品牌主色

#### 红色（Accent Red）
- **用途**：强调色、重要操作、品牌标识
- **品牌红色**：`#F75C62` (RGB: 247, 92, 98) - 统一使用此颜色，不区分浅色/深色模式
- **SwiftUI实现**：
```swift
// 推荐：使用工具类
Color.footprintRed
// 或 AppColorScheme.iconColor

// 手动定义
Color(red: 247/255, green: 92/255, blue: 98/255)
```

#### 米色系（Beige Palette）
- **用途**：背景、卡片、柔和元素
- **主要米色**：`#F7F3EB` (RGB: 247, 243, 235) - 页面背景（单色模式）
- **卡片米色**：`#F0E7DA` (RGB: 240, 231, 218) - 小卡片背景
- **渐变色系**：三色渐变，**主要用于视图的页面背景**
  - **25%**：`#FBEFEC` (RGB: 251, 239, 236) - 浅粉色
  - **50%**：`#FAF7F2` (RGB: 250, 247, 242) - 浅米色
  - **75%**：`#FBF6EC` (RGB: 251, 246, 236) - 浅黄米色

---

## 三、文字颜色系统

### 3.1 文字颜色层级

#### 主要文字（Primary Text）
- **用途**：标题、重要内容、主要信息
- **浅色模式**：`.primary` (系统自动的深灰色，通常为 #333333)
- **深色模式**：`.primary` (系统自动适配)
- **SwiftUI实现**：
```swift
private var primaryTextColor: Color {
    Color.primary  // 系统自动适配浅色/深色模式
}
```

#### 次要文字（Secondary Text）
- **用途**：副标题、辅助信息、说明文字
- **浅色模式**：`.secondary` (系统自动，约 #666666)
- **深色模式**：`.secondary` (系统自动适配)
- **SwiftUI实现**：
```swift
.foregroundColor(.secondary)
```

#### 三级文字（Tertiary Text）
- **用途**：提示文字、占位符、标签
- **浅色模式**：`.tertiary` (系统自动，约 #999999)
- **深色模式**：`.tertiary` (系统自动适配)
- **SwiftUI实现**：
```swift
.foregroundColor(.tertiary)
```

#### 强调文字（Accent Text）
- **用途**：重要数字、统计数据、强调内容
- **颜色**：品牌红色 `Color.footprintRed` (`#F75C62`)
- **SwiftUI实现**：
```swift
.foregroundColor(.footprintRed)
// 或使用工具类
.foregroundColor(AppColorScheme.iconColor)
```

---

## 四、图标颜色系统

### 4.1 图标颜色规范

> **重要原则**：Footprint应用中，**所有图标颜色（按钮图标除外）统一使用品牌主色（红色）**，以保持视觉一致性和品牌识别度。

#### 通用图标颜色（非按钮图标）

- **颜色**：品牌红色 `Color.footprintRed` (`#F75C62`)
- **用途**：统计图标、功能图标、状态图标、列表项图标等
- **例外**：按钮图标（工具栏按钮、浮动按钮等）使用 `.primary` 颜色，配合Liquid Glass效果

**SwiftUI实现**：
```swift
// 推荐方式：使用工具类方法
Image(systemName: "map.fill")
    .foregroundColor(AppColorScheme.iconColor)

// 或直接使用品牌色
Image(systemName: "calendar")
    .foregroundColor(.footprintRed)
```

#### 图标颜色使用场景

| 图标类型 | 颜色 | 说明 | 示例 |
|---------|------|------|------|
| **统计图标** | 品牌红色 ✅ | 统计卡片中的图标 | 地图、国家、足迹等统计图标 |
| **功能图标** | 品牌红色 ✅ | 功能入口、操作提示图标 | 登录提示、设置入口等 |
| **状态图标** | 品牌红色 ✅ | 状态指示、标记图标 | 已完成、已点亮等状态 |
| **列表项图标** | 品牌红色 ✅ | 列表中的图标元素 | 目的地列表、旅程列表等 |
| **按钮图标** | `.primary` | 工具栏按钮、浮动按钮 | 使用Liquid Glass效果的按钮 |
| **导航图标** | `.primary` | 导航栏、标签栏图标 | 系统导航元素 |

#### 图标颜色工具方法

使用 `AppColorScheme.iconColor` 获取统一的图标颜色：

```swift
// 使用工具类方法（推荐）
Image(systemName: "map.fill")
    .foregroundColor(AppColorScheme.iconColor)

// 或使用扩展属性
Image(systemName: "calendar")
    .foregroundColor(.footprintIconColor)
```

---

## 五、背景颜色系统

### 5.1 页面背景（Page Background）

> **重要提示**：所有视图页面背景**必须使用渐变背景**，而不是单色背景。这符合Footprint应用的视觉设计规范，提供温暖、优雅的视觉体验。

#### 浅色模式（推荐使用渐变）

- **渐变类型**：三色线性渐变
- **颜色停止点**：
  - **25%**：`#FBEFEC` (RGB: 251, 239, 236) - 浅粉色
  - **50%**：`#FAF7F2` (RGB: 250, 247, 242) - 浅米色
  - **75%**：`#FBF6EC` (RGB: 251, 246, 236) - 浅黄米色
- **渐变方向**：从右上角（`.topTrailing`）到左下角（`.bottomLeading`）

**推荐实现方式（使用 AppColorScheme 工具类）**：
```swift
struct MyView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            // 内容
        }
        .appPageBackgroundGradient(for: colorScheme)  // ✅ 推荐：使用渐变背景
    }
}
```

**手动实现方式**：
```swift
// 渐变背景（推荐）- 三色渐变
LinearGradient(
    stops: [
        .init(color: Color(red: 0.984, green: 0.937, blue: 0.925), location: 0.0),    // #FBEFEC at 0%
        .init(color: Color(red: 0.984, green: 0.937, blue: 0.925), location: 0.25),  // #FBEFEC at 25%
        .init(color: Color(red: 0.980, green: 0.969, blue: 0.949), location: 0.50),  // #FAF7F2 at 50%
        .init(color: Color(red: 0.984, green: 0.965, blue: 0.925), location: 0.75),  // #FBF6EC at 75%
        .init(color: Color(red: 0.984, green: 0.965, blue: 0.925), location: 1.0)    // #FBF6EC at 100%
    ],
    startPoint: .topTrailing,
    endPoint: .bottomLeading
)

// ❌ 不推荐：单色背景（仅用于特殊场景）
private var pageBackgroundColor: Color {
    colorScheme == .dark 
        ? Color(.systemGroupedBackground)
        : Color(red: 0.969, green: 0.953, blue: 0.922) // #f7f3eb
}
```

#### 深色模式

- **背景**：`.systemGroupedBackground` (系统自动适配)
- **渐变**：深色模式下使用单色系统背景（系统自动处理）

**实现方式**：
```swift
// AppColorScheme 会自动处理深色模式
.appPageBackgroundGradient(for: colorScheme)
// 深色模式下会返回系统分组背景的单色渐变（视觉上为单色）
```

---

## 六、卡片颜色系统

Footprint应用中的卡片分为四种主要类型：**白卡片**、**红卡片**、**黑卡片**、**浅米色卡片**，以及**半透明卡片**（Glass Card），每种卡片有明确的配色规范。

### 6.1 白卡片（White Card）

#### 用途
统计卡片、信息展示卡片、数据卡片等常规内容展示。

#### 配色规范
- **背景色**：`#FFFFFF` (RGB: 255, 255, 255) - 纯白色
- **标签文字**：`.secondary` (灰色，约 #666666) - 用于"TIME"、"OUTPUT"等标签
- **主要数字**：`.primary` (深灰色/黑色，约 #333333) - 用于重要数字展示
- **单位文字**：`.secondary` (灰色) - 用于"个月"等单位
- **描述文字**：`.primary` (深灰色/黑色) - 用于正文描述
- **强调元素**：品牌红色 `#F75C62` - 用于"+1"、圆点等强调元素
- **圆角**：15-20pt
- **阴影**：`Color.black.opacity(0.08)`, radius: 6, y: 2

#### SwiftUI实现示例
> **注意**：以下代码为示例实现，仅用于演示如何使用配色规范。实际开发中可根据具体需求灵活调整布局和样式。

```swift
// 白卡片样式示例
struct WhiteCard: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack {
            // 标签：灰色
            Text("TIME")
                .foregroundColor(.secondary)
                .font(.caption)
            
            // 主要数字：黑色
            HStack(alignment: .firstTextBaseline) {
                Text("7")
                    .foregroundColor(.primary)
                    .font(.system(size: 32, weight: .bold))
                
                // 单位：灰色
                Text("个月")
                    .foregroundColor(.secondary)
                    .font(.body)
            }
            
            // 强调元素：品牌红色
            HStack {
                Circle()
                    .fill(Color.footprintRed)
                    .frame(width: 6, height: 6)
                
                Text("零基础 Xcode 入门")
                    .foregroundColor(.primary)
            }
        }
        .padding()
        .background(Color.white) // #FFFFFF
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
    }
}
```

---

### 6.2 红卡片（Red Card）

#### 用途
重要功能入口、设置面板、品牌强调卡片等需要突出显示的内容。

#### 配色规范
- **背景色**：品牌红色 `#F75C62` (RGB: 247, 92, 98)
- **标题文字**：`Color.white` (白色) - 用于主标题
- **描述文字**：`Color.white` (白色) - 用于描述性文字
- **嵌套面板背景**：品牌红色 + 透明度 0.85-0.9，或稍浅的红色变体
- **按钮背景**：`Color.white` (白色)
- **按钮文字**：品牌红色 `#F75C62`
- **圆角**：15-20pt
- **阴影**：`Color.black.opacity(0.15)`, radius: 8, y: 4

#### SwiftUI实现示例
> **注意**：以下代码为示例实现，仅用于演示如何使用配色规范。实际开发中可根据具体需求灵活调整布局和样式。

```swift
// 红卡片样式示例
struct RedCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题：白色
            HStack {
                Image(systemName: "photo.artframe")
                    .foregroundColor(.white)
                Text("Logo 设置")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            
            // 嵌套面板：稍浅的红色
            VStack(spacing: 12) {
                // 描述文字：白色
                Text("上传您的 Artwork.jpg 以替换默认的墨鱼SVG。")
                    .foregroundColor(.white)
                    .font(.body)
                
                // 按钮：白色背景，红色文字
                Button(action: {}) {
                    HStack {
                        Image(systemName: "arrow.up.line")
                        Text("点击上传 Logo")
                    }
                    .foregroundColor(Color.footprintRed)
                    .padding()
                    .background(Color.white)
                    .cornerRadius(10)
                }
            }
            .padding()
            .background(Color.footprintRed.opacity(0.85))
            .cornerRadius(12)
        }
        .padding()
        .background(Color.footprintRed) // #F75C62
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.15), radius: 8, y: 4)
    }
}
```

---

### 6.3 黑卡片（Dark Card）

#### 用途
进度展示、任务状态、重要通知等需要深色背景突出显示的内容。

#### 配色规范
- **背景色**：深炭灰色 `#1C1C1E` (RGB: 28, 28, 30) - 或使用 `.systemBackground` 在深色模式
- **标题文字**：品牌红色 `#F75C62` - 用于"CURRENT MISSION"等标题
- **百分比/数值**：`.secondary` (浅灰色，约 #999999) - 用于"85%"等数值
- **描述文字**：`Color.white` (白色) - 用于主要描述文字
- **圆角**：15-20pt
- **阴影**：`Color.black.opacity(0.2)`, radius: 10, y: 4
- **注意**：进度条作为独立组件，可在任何卡片中组合使用，详见"进度条颜色系统"章节

#### SwiftUI实现示例
> **注意**：以下代码为示例实现，仅用于演示如何使用配色规范。实际开发中可根据具体需求灵活调整布局和样式。

```swift
// 黑卡片样式示例
struct DarkCard: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题行
            HStack {
                // 标题：品牌红色
                Text("CURRENT MISSION")
                    .foregroundColor(Color.footprintRed)
                    .font(.caption)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // 百分比：浅灰色
                Text("85%")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            
            // 描述文字：白色
            Text("正在攻克 iCloud 同步难题...")
                .foregroundColor(.white)
                .font(.body)
            
            // 进度条（独立组件，可在任何卡片中使用）
            ProgressBarView(progress: 0.85)
        }
        .padding()
        .background(
            colorScheme == .dark 
                ? Color(.systemBackground)
                : Color(red: 0.11, green: 0.11, blue: 0.118) // #1C1C1E
        )
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.2), radius: 10, y: 4)
    }
}
```

---

### 6.4 浅米色卡片（Beige Card）

#### 用途
文本气泡、提示信息、说明卡片、状态展示等需要柔和、温暖视觉效果的场景。

#### 配色规范
- **背景色**：浅米色 `#FAF8F5` (RGB: 250, 248, 245) - 浅米色卡片背景
- **文字颜色**：`.primary` (深灰色/黑色，约 #333333) - 用于正文内容
- **次要文字**：`.secondary` (灰色，约 #666666) - 用于辅助信息
- **边框**：**必须使用浅米色边框**，增强视觉层次和精致感
  - **边框颜色**：`#EAE6DF` (RGB: 234, 230, 223) - 浅米色边框
  - **边框宽度**：1pt
- **圆角**：15-20pt
- **阴影**：`Color.black.opacity(0.08)`, radius: 6, y: 2

#### SwiftUI实现示例
> **注意**：以下代码为示例实现，仅用于演示如何使用配色规范。实际开发中可根据具体需求灵活调整布局和样式。

```swift
// 浅米色卡片样式示例
struct BeigeCard: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 正文内容：黑色
            Text("7个月开发3个APP,从被拒3次到终于过审,墨鱼足迹2.0上线,iCloud同步太难了")
                .foregroundColor(.primary)
                .font(.body)
        }
        .padding()
        .background(
            colorScheme == .dark
                ? Color(.secondarySystemBackground)
                : Color(red: 250/255, green: 248/255, blue: 245/255) // #FAF8F5
        )
        .cornerRadius(15)
        .overlay(
            RoundedRectangle(cornerRadius: 15)
                .stroke(Color(red: 234/255, green: 230/255, blue: 223/255), lineWidth: 1)  // ✅ 浅米色边框 #EAE6DF
        )
        .shadow(color: Color.black.opacity(0.08), radius: 6, y: 2)
    }
}
```

**边框实现要点**：
- ✅ **必须使用**：`#EAE6DF` (RGB: 234, 230, 223) - 浅米色边框
- ✅ **边框宽度**：1pt
- ✅ **圆角**：与卡片圆角保持一致（通常15-20pt）
- ✅ **文字颜色**：使用 `.primary` 确保在浅米色背景上有良好的可读性

---

### 6.5 卡片类型选择指南

| 卡片类型 | 适用场景 | 视觉权重 |
|---------|---------|---------|
| **白卡片** | 统计数据、信息展示、常规内容 | 低-中 |
| **红卡片** | 重要功能入口、设置面板、品牌强调 | 高 |
| **黑卡片** | 进度展示、任务状态、重要通知 | 中-高 |
| **浅米色卡片** | 文本气泡、提示信息、说明卡片、状态展示 | 低-中 |
| **半透明卡片** | 浮动面板、弹出层、覆盖层 | 中 |

### 6.5 统一工具方法（推荐使用）

使用 `AppColorScheme` 工具类统一管理卡片样式：

```swift
// 白卡片背景
AppColorScheme.whiteCardBackground(for: colorScheme) // #FFFFFF

// 红卡片背景
AppColorScheme.redCardBackground // #F75C62

// 黑卡片背景
AppColorScheme.darkCardBackground(for: colorScheme) // #1C1C1E (浅色模式)

// 浅米色卡片背景
AppColorScheme.beigeCardBackground(for: colorScheme) // #FAF8F5 (浅色模式)

// 浅米色卡片边框
AppColorScheme.beigeCardBorder // #EAE6DF
```

---

## 七、进度条颜色系统

### 7.1 进度条（Progress Bar）

#### 用途
进度条是独立组件，不属于任何卡片类型，但可以在任何卡片中组合使用，用于展示任务进度、加载状态、完成度等。

#### 配色规范
- **填充色**：品牌红色 `#F75C62` (RGB: 247, 92, 98) - 表示已完成/进行中的部分
- **背景色**：深灰色 `Color.black.opacity(0.3)` 或 `#2C2C2E` - 表示未完成的部分
- **高度**：6-8pt（推荐 6pt）
- **圆角**：4pt（与高度比例协调）
- **动画**：建议使用平滑的动画过渡

#### SwiftUI实现示例
> **注意**：以下代码为示例实现，仅用于演示如何使用配色规范。实际开发中可根据具体需求灵活调整布局和样式。

```swift
// 进度条组件示例（独立组件）
struct ProgressBarView: View {
    let progress: Double // 0.0 - 1.0
    let height: CGFloat = 6
    let cornerRadius: CGFloat = 4
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // 进度条背景：深灰色
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.black.opacity(0.3))
                    .frame(height: height)
                
                // 进度条填充：品牌红色
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.footprintRed) // #F75C62
                    .frame(width: geometry.size.width * progress, height: height)
            }
        }
        .frame(height: height)
    }
}

// 使用示例：在白卡片中使用
struct WhiteCardWithProgress: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("任务进度")
                .foregroundColor(.primary)
            
            ProgressBarView(progress: 0.75)
        }
        .padding()
        .whiteCardStyle(for: .light)
    }
}

// 使用示例：在黑卡片中使用
struct DarkCardWithProgress: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("CURRENT MISSION")
                    .foregroundColor(Color.footprintRed)
                Spacer()
                Text("85%")
                    .foregroundColor(.secondary)
            }
            
            Text("正在攻克 iCloud 同步难题...")
                .foregroundColor(.white)
            
            ProgressBarView(progress: 0.85)
        }
        .padding()
        .darkCardStyle(for: colorScheme)
    }
}

// 使用示例：在红卡片中使用
struct RedCardWithProgress: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("上传进度")
                .foregroundColor(.white)
            
            ProgressBarView(progress: 0.6)
        }
        .padding()
        .redCardStyle()
    }
}
```

### 7.2 进度条变体

#### 带百分比显示的进度条
```swift
struct ProgressBarWithLabel: View {
    let progress: Double
    let showPercentage: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showPercentage {
                HStack {
                    Text("\(Int(progress * 100))%")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Spacer()
                }
            }
            
            ProgressBarView(progress: progress)
        }
    }
}
```

### 7.3 统一工具方法（推荐使用）

使用 `AppColorScheme` 工具类统一管理进度条颜色：

```swift
// 进度条填充色
AppColorScheme.progressBarFill // #F75C62

// 进度条背景色
AppColorScheme.progressBarBackground // Color.black.opacity(0.3)
```

---

### 6.3 半透明卡片（Glass Card）

半透明卡片使用系统Material材质，提供原生毛玻璃模糊效果，自动适配深色模式。

- **用途**：浮动面板、弹出层、覆盖层
- **材质选项**：
  - `.ultraThinMaterial` - 超薄材质（最透明）
  - `.thinMaterial` - 薄材质（较透明）
  - `.regularMaterial` - 标准材质
  - `.thickMaterial` - 厚材质（较不透明）
  - `.ultraThickMaterial` - 超厚材质（最不透明）
- **边框**：**必须使用半透明的白色边框**，增强视觉层次和精致感
  - **边框颜色**：`Color.white.opacity(0.3)` - 半透明白色边框
  - **边框宽度**：1pt

#### 文字颜色自动适配

> **重要**：半透明卡片内的文字颜色**必须使用语义颜色**（`.primary`、`.secondary`、`.tertiary`），系统会自动根据背后背景的明暗程度自动调整文字颜色，确保在任何背景下都有良好的可读性。
> 
> - 背后是浅色背景 → 文字自动变为深色
> - 背后是深色背景 → 文字自动变为浅色
> - 系统Material材质会自动处理这个适配过程

**正确做法**：
```swift
// ✅ 使用语义颜色（自动适配）
Text("标题")
    .foregroundColor(.primary)  // 自动适配背后背景

Text("副标题")
    .foregroundColor(.secondary)  // 自动适配背后背景
```

**错误做法**：
```swift
// ❌ 不要使用固定颜色
Text("标题")
    .foregroundColor(.black)  // 在深色背景下不可读

Text("标题")
    .foregroundColor(.white)  // 在浅色背景下不可读
```

#### SwiftUI实现

```swift
// 超薄材质（最透明）
.background(.ultraThinMaterial)

// 薄材质（较透明）
.background(.thinMaterial)

// 标准材质
.background(.regularMaterial)

// 完整示例（包含文字和边框）
VStack {
    Text("标题")
        .foregroundColor(.primary)  // 自动适配
    Text("副标题")
        .foregroundColor(.secondary)  // 自动适配
}
.padding()
.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
.overlay(
    RoundedRectangle(cornerRadius: 15)
        .stroke(Color.white.opacity(0.3), lineWidth: 1)  // ✅ 半透明白色边框
)
.shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
```

**边框实现要点**：
- ✅ **必须使用**：`Color.white.opacity(0.3)` - 半透明白色边框
- ✅ **边框宽度**：1pt
- ✅ **圆角**：与卡片圆角保持一致（通常15-20pt）
- ❌ **不要使用**：黑色半透明边框（`Color.black.opacity(...)`），会降低视觉层次

---

## 八、交互元素颜色

### 7.1 按钮颜色

> **按钮类型区分**：
> - **图标按钮**：仅包含SF Symbols图标的按钮，使用iOS 26系统Liquid Glass效果
> - **文字按钮**：包含文字标签的按钮，使用标准配色方案

#### 图标按钮（Icon Button）- iOS 26 Liquid Glass

图标按钮采用iOS 26系统自带的Liquid Glass（液体玻璃）效果，提供现代化的半透明玻璃质感。

##### iOS 26+ 实现（推荐）

使用 `.backgroundStyle(.material, in: .shape)` 修饰符实现系统级Liquid Glass效果：

```swift
Button(action: {}) {
    Image(systemName: "location.fill")
        .font(.system(size: 20, weight: .medium))
        .foregroundColor(.primary)
}
.frame(width: 44, height: 44)
.backgroundStyle(.ultraThinMaterial, in: Circle())
.shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
```

**系统优势**：系统会自动处理色彩适配、模糊强度和性能优化。

##### 完整图标按钮样式

```swift
// 标准图标按钮（44x44，最小触控目标）
Button(action: {}) {
    Image(systemName: "plus")
        .font(.system(size: 20, weight: .semibold))
        .foregroundColor(.primary)
}
.frame(width: 44, height: 44)
.backgroundStyle(.regularMaterial, in: Circle())
.shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)

// 带边框增强的图标按钮（可选增强）
Button(action: {}) {
    Image(systemName: "camera.fill")
        .font(.system(size: 24, weight: .semibold))
        .foregroundColor(.primary)
}
.frame(width: 56, height: 56)
.backgroundStyle(.regularMaterial, in: Circle())
.backgroundStyleBorder()  // 可选增强：添加边框
.shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
```

##### Liquid Glass 样式选项（Material）

- **`.regularMaterial`**：标准玻璃效果（推荐用于大多数场景）
- **`.ultraThinMaterial`**：超薄玻璃效果（更透明，用于浮动按钮）
- **`.thinMaterial`**：薄玻璃效果（中等透明度）
- **`.thickMaterial`**：厚玻璃效果（较不透明）
- **`.ultraThickMaterial`**：超厚玻璃效果（最不透明）

##### 可选增强

- **`.backgroundStyleBorder()`**：为按钮添加边框，增强视觉层次

##### 图标颜色适配

根据背景自动调整图标颜色：

```swift
@Environment(\.colorScheme) var colorScheme

private var iconColor: Color {
    colorScheme == .dark ? .white : .primary
}

Button(action: {}) {
    Image(systemName: "map.fill")
        .font(.system(size: 20, weight: .medium))
        .foregroundColor(iconColor)
}
.frame(width: 44, height: 44)
.glassBackgroundEffect(in: Circle())
```

##### iOS 18-25 降级方案

对于不支持 `.backgroundStyle()` 的版本，使用传统 Material 背景：

```swift
Button(action: {}) {
    Image(systemName: "location.fill")
        .font(.system(size: 20, weight: .medium))
        .foregroundColor(.primary)
}
.frame(width: 44, height: 44)
.background(.ultraThinMaterial, in: Circle())
.overlay(
    Circle()
        .stroke(Color.white.opacity(0.2), lineWidth: 1)
)
.shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
```

**注意**：当前项目使用 iOS 26+，推荐使用 `.backgroundStyle()` API 以获得系统级优化。

##### 图标按钮使用场景

- ✅ 工具栏按钮
- ✅ 浮动操作按钮（FAB）
- ✅ 地图控制按钮
- ✅ 导航栏操作按钮
- ✅ 卡片操作按钮

##### 图标按钮尺寸规范

| 尺寸 | 用途 | 图标大小 |
|------|------|---------|
| 44x44 | 标准按钮（最小触控目标） | 20pt |
| 48x48 | 中等按钮 | 22pt |
| 56x56 | 大型按钮（主要操作） | 24pt |

---

#### 文字按钮（Text Button）

文字按钮使用标准配色方案，不使用Liquid Glass效果。

#### 主按钮（Primary Button）
- **浅色模式背景**：`#333333` (RGB: 51, 51, 51) - 深灰色/黑色
- **浅色模式文字**：`#FFFFFF` (白色)
- **深色模式背景**：`#FFFFFF` (白色)
- **深色模式文字**：`#333333` (深灰色)
- **SwiftUI实现**：
```swift
private var primaryButtonColor: Color {
    colorScheme == .dark ? Color.white : Color(red: 0.2, green: 0.2, blue: 0.2)
}

private var buttonTextColor: Color {
    colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color.white
}

// 使用示例
Button(action: {}) {
    Text("按钮文字")
        .foregroundColor(buttonTextColor)
}
.padding()
.background(primaryButtonColor)
.cornerRadius(12)
```

#### 次要按钮（Secondary Button）
- **背景**：透明或 `.bordered` 样式
- **文字**：`.primary` 或 `.red` (强调操作)
- **边框**：`borderColor`
- **SwiftUI实现**：
```swift
Button(action: {}) {
    Text("次要按钮")
        .foregroundColor(.primary)
}
.buttonStyle(.bordered)
```

#### 强调按钮（Accent Button）
- **背景**：红色 `Color.red`
- **文字**：白色
- **SwiftUI实现**：
```swift
Button(action: {}) {
    Text("强调按钮")
        .foregroundColor(.white)
}
.padding()
.background(Color.red)
.cornerRadius(12)
```

### 7.2 标签和徽章（Tags & Badges）

#### 黑色标签
- **背景**：`#000000` (黑色)
- **文字**：`#FFFFFF` (白色)
- **用途**：分类标签、状态标签
- **SwiftUI实现**：
```swift
Capsule()
    .fill(Color.black)
    .overlay(
        Text("标签")
            .foregroundColor(.white)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
    )
```

#### 白色标签（带红色图标）
- **背景**：`#FFFFFF` (白色)
- **文字**：`#000000` (黑色)
- **图标**：红色 `Color.red`
- **用途**：功能标签、特色标签
- **SwiftUI实现**：
```swift
Capsule()
    .fill(Color.white)
    .overlay(
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .foregroundColor(.red)
            Text("标签")
                .foregroundColor(.black)
        }
        .font(.caption)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    )
```

---

## 九、边框和分割线

### 8.1 边框颜色

#### 标准边框
- **浅色模式**：`Color.black.opacity(0.06)` - 非常柔和的黑色边框
- **深色模式**：`Color.white.opacity(0.08)` - 柔和的白色边框
- **SwiftUI实现**：
```swift
private var borderColor: Color {
    colorScheme == .dark 
        ? Color.white.opacity(0.08)
        : Color.black.opacity(0.06)
}

// 使用示例
.overlay(
    RoundedRectangle(cornerRadius: 15)
        .stroke(borderColor, lineWidth: 1)
)
```

#### 半透明卡片边框（Glass Card Border）
- **颜色**：`Color.white.opacity(0.3)` - 半透明白色边框
- **用途**：**专门用于半透明卡片（Glass Card）**，增强视觉层次和精致感
- **SwiftUI实现**：
```swift
// 半透明卡片边框
.overlay(
    RoundedRectangle(cornerRadius: 15)
        .stroke(Color.white.opacity(0.3), lineWidth: 1)
)
```
> **注意**：半透明卡片必须使用白色半透明边框，不要使用标准边框颜色（黑色半透明），以确保在浅色渐变背景上有良好的视觉层次。

#### 强调边框
- **颜色**：红色 `Color.red.opacity(0.3)`
- **用途**：选中状态、错误提示

### 8.2 分割线

#### 列表分割线
- **浅色模式**：`Color.black.opacity(0.06)`
- **深色模式**：`Color.white.opacity(0.08)`
- **SwiftUI实现**：
```swift
Divider()
    .background(borderColor)
```

---

## 十、阴影系统

### 9.1 阴影层级

#### 大卡片阴影
- **颜色**：`Color.black.opacity(0.12)`
- **半径**：12pt
- **偏移**：x: 0, y: 4
- **用途**：主要卡片、重要内容卡片

#### 小卡片阴影
- **颜色**：`Color.black.opacity(0.08)`
- **半径**：6pt
- **偏移**：x: 0, y: 2
- **用途**：次要卡片、嵌套卡片

#### 浮动元素阴影
- **颜色**：`Color.black.opacity(0.15)`
- **半径**：8-10pt
- **偏移**：x: 0, y: 4
- **用途**：浮动按钮、弹出层

#### 深色模式阴影
- **颜色**：`Color.black.opacity(0.3)` (更明显)
- **半径**：保持相同
- **偏移**：保持相同

---

## 十一、深色模式适配

### 10.1 适配原则

1. **自动适配**：优先使用系统语义颜色（`.primary`、`.secondary`、`.systemBackground`等）
2. **手动适配**：自定义颜色使用 `@Environment(\.colorScheme)` 判断
3. **保持对比度**：确保文字与背景对比度符合无障碍标准

### 10.2 适配示例

```swift
@Environment(\.colorScheme) var colorScheme

private var adaptiveColor: Color {
    colorScheme == .dark 
        ? Color(.systemBackground)  // 深色模式
        : Color.white               // 浅色模式
}
```

---

## 十二、完整配色工具类

### 11.1 AppColorScheme 工具类

已实现的统一配色工具类，方便全局使用。**所有视图页面背景必须使用渐变背景**。

```swift
import SwiftUI

extension Color {
    // MARK: - 品牌色
    /// 品牌红色（强调色）
    /// - 颜色值：`#F75C62` (RGB: 247, 92, 98)
    static let footprintRed = Color(red: 247/255, green: 92/255, blue: 98/255)
    
    /// 页面背景米色 #F7F3EB
    static let footprintBeige = Color(red: 0.969, green: 0.953, blue: 0.922)
    
    /// 卡片背景米色 #F0E7DA
    static let footprintCardBeige = Color(red: 0.941, green: 0.906, blue: 0.855)
    
    // MARK: - 文字色
    /// 主文字色（已废弃，请使用 `.primary` 或 `AppColorScheme.primaryText(for:)`）
    @available(*, deprecated, message: "使用 Color.primary 或 AppColorScheme.primaryText(for:) 替代")
    static let footprintPrimaryText = Color(red: 0.2, green: 0.2, blue: 0.2)
    
    // MARK: - 图标色
    /// 通用图标颜色（品牌红色）
    static let footprintIconColor = Color.footprintRed
}

struct AppColorScheme {
    // MARK: - 背景色
    
    // 页面背景渐变（推荐使用）
    static func pageBackgroundGradient(for colorScheme: ColorScheme) -> LinearGradient {
        if colorScheme == .dark {
            return LinearGradient(
                colors: [Color(.systemGroupedBackground)],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
        }
        return LinearGradient(
            stops: [
                .init(color: Color(red: 0.984, green: 0.937, blue: 0.925), location: 0.0),    // #FBEFEC at 0%
                .init(color: Color(red: 0.984, green: 0.937, blue: 0.925), location: 0.25),  // #FBEFEC at 25%
                .init(color: Color(red: 0.980, green: 0.969, blue: 0.949), location: 0.50),  // #FAF7F2 at 50%
                .init(color: Color(red: 0.984, green: 0.965, blue: 0.925), location: 0.75),  // #FBF6EC at 75%
                .init(color: Color(red: 0.984, green: 0.965, blue: 0.925), location: 1.0)    // #FBF6EC at 100%
            ],
            startPoint: .topTrailing,
            endPoint: .bottomLeading
        )
    }
    
    // MARK: - 卡片背景色
    
    // 白卡片背景色（White Card）
    static func whiteCardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(.secondarySystemBackground)
            : Color.white // #FFFFFF
    }
    
    // 红卡片背景色（Red Card）
    static var redCardBackground: Color {
        Color.footprintRed // #F75C62
    }
    
    // 黑卡片背景色（Dark Card）
    static func darkCardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(.systemBackground)
            : Color(red: 0.11, green: 0.11, blue: 0.118) // #1C1C1E
    }
    
    // 浅米色卡片背景色（Beige Card）
    static func beigeCardBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark
            ? Color(.secondarySystemBackground)
            : Color(red: 250/255, green: 248/255, blue: 245/255) // #FAF8F5
    }
    
    // 浅米色卡片边框颜色（Beige Card Border）
    static var beigeCardBorder: Color {
        Color(red: 234/255, green: 230/255, blue: 223/255) // #EAE6DF
    }
    
    // MARK: - 文字颜色
    
    // 主文字颜色（使用系统 .primary，自动适配）
    static func primaryText(for colorScheme: ColorScheme) -> Color {
        Color.primary  // 系统自动适配浅色/深色模式
    }
    
    // MARK: - 图标颜色
    
    // 通用图标颜色（品牌红色）
    static var iconColor: Color {
        Color.footprintRed // #F75C62
    }
    
    // MARK: - 进度条颜色
    
    // 进度条填充色
    static var progressBarFill: Color {
        Color.footprintRed // #F75C62
    }
    
    // 进度条背景色
    static var progressBarBackground: Color {
        Color.black.opacity(0.3)
    }
    
    // MARK: - 边框颜色
    
    // 标准边框颜色
    static func border(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark 
            ? Color.white.opacity(0.08)
            : Color.black.opacity(0.06)
    }
    
    // 半透明卡片边框颜色（白色半透明）
    static var glassCardBorder: Color {
        Color.white.opacity(0.3)  // 半透明白色边框
    }
    
    // MARK: - 按钮颜色
    
    // 主按钮背景色
    static func primaryButtonBackground(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color.white : Color(red: 0.2, green: 0.2, blue: 0.2)
    }
    
    // 主按钮文字颜色
    static func primaryButtonText(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? Color(red: 0.2, green: 0.2, blue: 0.2) : Color.white
    }
}

// MARK: - View 扩展

extension View {
    /// 应用页面背景渐变（推荐使用）✅
    func appPageBackgroundGradient(for colorScheme: ColorScheme) -> some View {
        self.background(AppColorScheme.pageBackgroundGradient(for: colorScheme))
    }
    
    /// 应用页面背景（单色，不推荐）❌
    func appPageBackground(for colorScheme: ColorScheme) -> some View {
        self.background(AppColorScheme.pageBackground(for: colorScheme))
    }
}
```

> **注意**：完整的实现代码请参考 `Footprint/Helpers/AppColorScheme.swift` 文件。所有方法都接受 `colorScheme` 参数，而不是使用 `@Environment`。
```

### 11.2 使用方式

```swift
struct MyView: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ScrollView {
            VStack {
                // 使用工具类
                Text("标题")
                    .foregroundColor(AppColorScheme.primaryText(for: colorScheme))
                
                // 使用系统主色（推荐）
                Text("内容")
                    .foregroundColor(.primary)
                
                // 卡片
                RoundedRectangle(cornerRadius: 15)
                    .fill(AppColorScheme.largeCardBackground(for: colorScheme))
                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                
                // 统计图标（使用品牌红色）✅
                HStack {
                    Image(systemName: "map.fill")
                        .foregroundColor(AppColorScheme.iconColor)
                    Text("19")
                }
                
                // 功能图标（使用品牌红色）✅
                Image(systemName: "calendar")
                    .foregroundColor(.footprintIconColor)
                
                // 图标按钮（iOS 26+ Liquid Glass，图标颜色为.primary）
                AppColorScheme.iconButton(
                    icon: "location.fill",
                    size: 44,
                    action: {}
                )
                
                // 文字按钮（标准配色）
                Button(action: {}) {
                    Text("主要操作")
                        .foregroundColor(AppColorScheme.primaryButtonText(for: colorScheme))
                }
                .padding()
                .background(AppColorScheme.primaryButtonBackground(for: colorScheme))
                .cornerRadius(12)
                
                // 半透明卡片（Glass Card）✅
                VStack {
                    Text("标题")
                        .foregroundColor(.primary)  // 自动适配
                    Text("副标题")
                        .foregroundColor(.secondary)  // 自动适配
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(AppColorScheme.glassCardBorder, lineWidth: 1)  // ✅ 半透明白色边框
                )
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                
                // 浅米色卡片（Beige Card）✅
                VStack(alignment: .leading, spacing: 8) {
                    Text("7个月开发3个APP,从被拒3次到终于过审,墨鱼足迹2.0上线,iCloud同步太难了")
                        .foregroundColor(.primary)
                        .font(.body)
                }
                .padding()
                .background(AppColorScheme.beigeCardBackground(for: colorScheme))  // ✅ 浅米色背景 #FAF8F5
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(AppColorScheme.beigeCardBorder, lineWidth: 1)  // ✅ 浅米色边框 #EAE6DF
                )
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
            }
            .padding()
        }
        .appPageBackgroundGradient(for: colorScheme)  // ✅ 使用渐变背景（推荐）
    }
}
```

### 11.3 图标按钮辅助方法（可选）

可以创建统一的图标按钮ViewBuilder，方便复用：

```swift
@ViewBuilder
func iconButton(
    icon: String,
    size: CGFloat = 44,
    iconSize: CGFloat = 20,
    action: @escaping () -> Void
) -> some View {
    Button(action: action) {
        Image(systemName: icon)
            .font(.system(size: iconSize, weight: .medium))
            .foregroundColor(.primary)
    }
    .frame(width: size, height: size)
    .backgroundStyle(.ultraThinMaterial, in: Circle())
    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
}

// 使用示例
iconButton(icon: "plus", size: 56, iconSize: 24) {
    // 执行操作
}
```

---

## 十三、配色使用指南

### 12.1 使用场景对照表

| 元素类型 | 颜色选择 | 示例 | 说明 |
|---------|---------|------|------|
| **页面背景** | `.appPageBackgroundGradient(for: colorScheme)` ✅ **推荐** | 所有页面的根背景 | **必须使用渐变背景**，提供温暖、优雅的视觉体验 |
| 页面背景（单色） | `.appPageBackground(for: colorScheme)` ❌ 不推荐 | 仅用于特殊场景 | 仅当确实需要纯色背景时使用 |
| 主要内容卡片 | `largeCardBackground(for: colorScheme)` + 大阴影 | 统计卡片、列表容器 | 使用 `AppColorScheme.largeCardBackground(for:)` |
| 嵌套卡片 | `smallCardBackground(for: colorScheme)` + 小阴影 | 列表项、子卡片 | 使用 `AppColorScheme.smallCardBackground(for:)` |
| **半透明卡片** | `.ultraThinMaterial` + `AppColorScheme.glassCardBorder` ✅ | 浮动面板、弹出层、底部面板 | 使用系统材质效果 + **半透明白色边框**（`Color.white.opacity(0.3)`） |
| **浅米色卡片** | `AppColorScheme.beigeCardBackground(for:)` + `AppColorScheme.beigeCardBorder` ✅ | 文本气泡、提示信息、说明卡片、状态展示 | 浅米色背景（`#FAF8F5`）+ **浅米色边框**（`#EAE6DF`） |
| 主标题 | `primaryText(for: colorScheme)` | 页面标题、卡片标题 | 使用 `AppColorScheme.primaryText(for:)` |
| 副标题 | `.secondary` | 说明文字、辅助信息 | 系统语义颜色 |
| 强调数字 | `.red` | 统计数据、重要数字 | 使用 `Color.red` |
| **图标按钮** | `AppColorScheme.iconButton(...)` (iOS 26+) | 工具栏按钮、浮动按钮、地图控制按钮 | 使用工具类方法，自动应用Liquid Glass效果 |
| **文字主按钮** | `primaryButtonBackground(for:)` + `primaryButtonText(for:)` | 主要操作按钮（带文字） | 使用 `AppColorScheme` 方法 |
| **文字次要按钮** | `.bordered` 样式 | 取消、返回按钮（带文字） | 系统按钮样式 |
| **文字强调按钮** | `.red` 背景 + 白色文字 | 删除、确认操作（带文字） | 使用 `Color.red` |

### 12.2 配色检查清单

- [ ] **所有页面使用渐变背景**（`.appPageBackgroundGradient(for: colorScheme)`）✅ **必须**
- [ ] 卡片使用正确的背景色和阴影
- [ ] **浅米色卡片使用浅米色边框**（`AppColorScheme.beigeCardBorder`，`#EAE6DF`）✅ **必须**
- [ ] **半透明卡片使用半透明白色边框**（`AppColorScheme.glassCardBorder`）✅ **必须**
- [ ] 文字颜色层级清晰（主/次/三级）
- [ ] **所有图标颜色统一为品牌红色**（`AppColorScheme.iconColor`）✅ **必须**（按钮图标除外）
- [ ] **图标按钮使用Liquid Glass效果（iOS 26+）**，图标颜色为 `.primary`
- [ ] **文字按钮使用标准配色方案**
- [ ] 按钮颜色符合交互层级
- [ ] 深色模式适配完整
- [ ] 对比度符合无障碍标准（4.5:1）
- [ ] 半透明元素使用正确的材质
- [ ] 强调色（红色）使用恰当，不过度

---

## 十四、渐变和特殊效果

### 13.1 背景渐变

```swift
// 三色渐变（25%, 50%, 75%）
LinearGradient(
    stops: [
        .init(color: Color(red: 0.984, green: 0.937, blue: 0.925), location: 0.0),    // #FBEFEC at 0%
        .init(color: Color(red: 0.984, green: 0.937, blue: 0.925), location: 0.25),  // #FBEFEC at 25%
        .init(color: Color(red: 0.980, green: 0.969, blue: 0.949), location: 0.50),  // #FAF7F2 at 50%
        .init(color: Color(red: 0.984, green: 0.965, blue: 0.925), location: 0.75),  // #FBF6EC at 75%
        .init(color: Color(red: 0.984, green: 0.965, blue: 0.925), location: 1.0)    // #FBF6EC at 100%
    ],
    startPoint: .topTrailing,
    endPoint: .bottomLeading
)
```

### 13.2 文字渐变

```swift
Text("渐变文字")
    .foregroundStyle(
        LinearGradient(
            colors: [.red, .orange],
            startPoint: .leading,
            endPoint: .trailing
        )
    )
```

---

## 附录：颜色值速查表

### 浅色模式颜色值

| 颜色名称 | Hex值 | RGB值 | SwiftUI值 |
|---------|-------|-------|-----------|
| 页面背景（单色） | #F7F3EB | (247, 243, 235) | `Color(red: 0.969, green: 0.953, blue: 0.922)` |
| **渐变25%** | **#FBEFEC** | **(251, 239, 236)** | `Color(red: 0.984, green: 0.937, blue: 0.925)` |
| **渐变50%** | **#FAF7F2** | **(250, 247, 242)** | `Color(red: 0.980, green: 0.969, blue: 0.949)` |
| **渐变75%** | **#FBF6EC** | **(251, 246, 236)** | `Color(red: 0.984, green: 0.965, blue: 0.925)` |
| 浅米色卡片背景 | #FAF8F5 | (250, 248, 245) | `Color(red: 250/255, green: 248/255, blue: 245/255)` |
| 浅米色卡片边框 | #EAE6DF | (234, 230, 223) | `Color(red: 234/255, green: 230/255, blue: 223/255)` |
| 卡片米色（旧版，已废弃） | #F0E7DA | (240, 231, 218) | `Color(red: 0.941, green: 0.906, blue: 0.855)` |
| 纯白色（白卡片背景） | #FFFFFF | (255, 255, 255) | `Color.white` |
| 主文字 | #333333 | (51, 51, 51) | `Color(red: 0.2, green: 0.2, blue: 0.2)` |
| 主按钮 | #333333 | (51, 51, 51) | `Color(red: 0.2, green: 0.2, blue: 0.2)` |
| 强调红 | #F75C62 | (247, 92, 98) | `Color.footprintRed` |
| 黑色 | #000000 | (0, 0, 0) | `Color.black` |

### 深色模式适配

- 使用系统语义颜色自动适配
- 自定义颜色通过 `colorScheme` 判断切换

---

**文档维护**: 开发团队  
**最后更新**: 2025-11-23  
**下一步**: 将配色标准应用到整个App的所有视图

