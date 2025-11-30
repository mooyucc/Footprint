# WeatherKit 配置指南

## 🔍 错误诊断

如果遇到以下错误：
```
🌧️ WeatherKit请求失败: 未能完成操作。（WeatherDaemon.WDSJWTAuthenticatorServiceListener.Errors错误2。）
```

这通常表示 WeatherKit 服务配置不正确。

---

## 🚀 快速检查（如果你已经在 Apple Developer 后台勾选了 WeatherKit）

如果你已经在 Apple Developer 后台的 App ID 配置页面勾选了 WeatherKit（如附图所示），接下来需要：

1. **✅ 已完成**：在 Apple Developer 后台启用 WeatherKit
2. **⏭️ 下一步**：在 Xcode 中添加 WeatherKit Capability（见下方步骤 3）
3. **⏭️ 最后**：清理并重新构建项目

**注意**：新版本的 Apple Developer 界面已经简化，对于 iOS 应用，通常只需要：
- ✅ 在 App ID 中勾选 WeatherKit（你已经完成）
- ✅ 在 Xcode 中添加 WeatherKit Capability
- ⚠️ **不需要**创建单独的 Service ID（这是旧版本的要求）

---

## ✅ 完整配置流程

### 步骤 1: 检查 Xcode 中的 Capability 配置

1. **打开 Xcode**
2. **选择项目** → 点击左侧蓝色的 `Footprint` 项目图标
3. **选择 Target** → 在 TARGETS 中选择 `Footprint`
4. **切换到 Signing & Capabilities 标签**
5. **查找 WeatherKit 卡片**

   如果看到：
   ```
   ╔════════════════════════════════╗
   ║ WeatherKit                     ║
   ║ Service ID: (未配置)           ║
   ╚════════════════════════════════╝
   ```
   
   说明 Capability 已添加，但缺少 Service ID 配置。

---

### 步骤 2: 在 Apple Developer 后台配置 WeatherKit

#### 2.1 访问 Apple Developer 网站

1. 打开浏览器，访问：https://developer.apple.com/account
2. 使用你的 Apple Developer 账号登录
3. 点击左侧菜单 **"Certificates, Identifiers & Profiles"**

#### 2.2 创建或配置 App ID

1. 点击左侧菜单 **"Identifiers"**
2. 在列表中查找你的 App ID（格式类似：`com.yourcompany.Footprint`）
   - 如果找不到，需要先创建一个 App ID
3. **点击你的 App ID** 进入详情页

#### 2.3 启用 WeatherKit 服务

在 App ID 详情页面：

1. **向下滚动找到 "Capabilities" 区域**
2. **找到 "WeatherKit"** 选项
3. **勾选 ☑️ WeatherKit** 复选框
4. **点击右上角 "Save" 保存**

#### 2.4 启用 WeatherKit（已完成 ✅）

根据当前的 Apple Developer 界面：

1. 在 **"App Services"** 标签页中
2. **勾选 ☑️ WeatherKit** 复选框
3. **点击 "Save"** 按钮保存

**注意**：新版本的 Apple Developer 界面已经简化，对于 iOS 应用，只需要：
- ✅ 在 App ID 中启用 WeatherKit（你已经完成）
- ✅ 在 Xcode 中添加 WeatherKit Capability（下一步）
- ⚠️ 某些情况下可能需要创建 Service ID（如果 Xcode 中要求），但通常 iOS 应用不需要

---

### 步骤 3: 在 Xcode 中配置 WeatherKit Capability

1. **返回 Xcode**
2. **选择项目** → 点击左侧蓝色的 `Footprint` 项目图标
3. **选择 Target** → 在 TARGETS 中选择 `Footprint`
4. **切换到 Signing & Capabilities 标签**
5. **点击 "+ Capability" 按钮**
6. **在搜索框中输入 "weather"** 或 "weatherkit"
7. **双击 "WeatherKit"** 添加 Capability

**检查 WeatherKit 卡片：**

如果看到以下情况，配置已正确：
```
╔════════════════════════════════╗
║ WeatherKit                     ║
╚════════════════════════════════╝
```

**如果卡片中显示 "Service ID" 字段：**
- 大多数情况下可以留空（iOS 应用通常不需要）
- 如果下拉框中有选项，可以选择一个，但不是必需的
- 只有在出现错误时才需要创建 Service ID

---

### 步骤 4: 验证配置

#### 4.1 检查 Entitlements 文件

打开 `Footprint.entitlements` 文件，应该包含：

```xml
<key>com.apple.developer.weatherkit</key>
<true/>
```

#### 4.2 检查项目配置文件

在 Xcode 中检查：
- ✅ Team 已选择
- ✅ Bundle Identifier 正确
- ✅ WeatherKit Capability 已添加
- ✅ WeatherKit Service ID 已配置

#### 4.3 清理并重新构建

1. **Product → Clean Build Folder** (或按 `Shift + Command + K`)
2. **关闭 Xcode**
3. **重新打开 Xcode 和项目**
4. **Product → Build** (或按 `Command + B`)

---

## 🔧 常见问题排查

### 问题 1: 在 Xcode 中看不到 WeatherKit Capability

**解决方案：**
1. 确保 **Team 已设置**（不是 None）
2. 点击 **+ Capability** 按钮
3. 在搜索框中输入 **"weather"**
4. 双击 **"WeatherKit"** 添加

### 问题 2: Service ID 下拉框为空

**可能原因：**
- Apple Developer 后台还没有创建 Service ID
- Team 账号权限不足（需要付费开发者账号）
- Xcode 没有同步到最新配置

**解决方案：**
1. 按照上面的步骤 2.4 创建 Service ID
2. 等待几分钟让 Apple 服务器同步
3. 在 Xcode 中点击 **Team 下拉框** → 选择 **"Download Manual Profiles"**
4. 或者完全关闭 Xcode 重新打开

### 问题 3: 仍然报认证错误

**检查清单：**
- [ ] Apple Developer 后台 App ID 已启用 WeatherKit
- [ ] 已创建 WeatherKit Service ID
- [ ] App ID 与 Service ID 已关联
- [ ] Xcode 中已选择正确的 Service ID
- [ ] Bundle Identifier 与 App ID 匹配
- [ ] 使用的是付费开发者账号（WeatherKit 需要付费账号）

### 问题 4: 免费 Apple ID 无法使用

**重要说明：**
- WeatherKit 是付费服务，需要 **Apple Developer Program 会员资格**（$99/年）
- 个人免费 Apple ID 无法使用 WeatherKit
- 如果只有免费账号，天气功能将无法工作

**解决方案：**
1. 注册 Apple Developer Program: https://developer.apple.com/programs/
2. 或者暂时禁用天气功能（在代码中处理错误情况）

---

## 🎯 快速配置检查清单

在开始之前，确认：

- [ ] 我有 Apple Developer Program 账号（付费）
- [ ] 我已在 Xcode 中添加了 Apple ID
- [ ] 我已在 Xcode 中选择了正确的 Team
- [ ] 我已在 Apple Developer 后台创建了 App ID
- [ ] 我已在 Apple Developer 后台启用了 WeatherKit
- [ ] 我已在 Apple Developer 后台创建了 WeatherKit Service ID
- [ ] 我已在 Xcode 中添加了 WeatherKit Capability
- [ ] 我已在 Xcode 中配置了 WeatherKit Service ID

如果所有都勾选了，WeatherKit 应该能正常工作！

---

## 📝 代码中的错误处理

即使配置正确，也应该在代码中处理可能的错误：

```swift
// 当前实现已经包含了错误处理
do {
    let weather = try await weatherService.weather(for: location)
    // 处理天气数据
} catch {
    // 记录错误但不影响用户体验
    print("🌧️ WeatherKit请求失败: \(error.localizedDescription)")
    // 天气图标将不显示，但地点标注仍然正常显示
}
```

这样即使 WeatherKit 请求失败，也不会影响地图的核心功能。

---

## 🔗 参考资源

- [Apple Developer - WeatherKit Documentation](https://developer.apple.com/documentation/weatherkit)
- [Apple Developer - Capabilities](https://developer.apple.com/documentation/xcode/configuring-capabilities)
- [Apple Developer Account](https://developer.apple.com/account)

---

## 💡 提示

1. **配置生效需要时间**：Apple Developer 后台的更改可能需要几分钟才能同步到 Xcode
2. **真机测试**：WeatherKit 必须在真机上测试，模拟器可能无法正常工作
3. **网络要求**：需要网络连接才能获取天气数据
4. **数据限制**：WeatherKit 有 API 调用限制，代码中已经实现了缓存机制

---

如果按照以上步骤操作后仍然遇到问题，请提供：
1. 你在 Apple Developer 后台看到的配置截图
2. Xcode 中 WeatherKit Capability 的配置截图
3. 完整的错误信息

我会根据具体情况提供进一步的帮助！

