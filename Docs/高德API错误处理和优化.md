# 高德API错误处理和优化

## 🐛 问题分析

根据错误日志，发现以下问题：

### 1. 高德API请求超时
```
[高德API] 网络错误: 请求超时。
```
- **原因**：超时时间设置为6秒，可能不够应对网络延迟
- **影响**：请求在6秒内未完成，被判定为超时

### 2. Apple地理编码被节流
```
Throttled "PlaceRequest.REQUEST_TYPE_REVERSE_GEOCODING" request: 
Tried to make more than 50 requests in 60 seconds
```
- **原因**：Apple系统限制，60秒内不能超过50次请求
- **影响**：降级到Apple服务时也失败，导致最终只能使用坐标兜底

### 3. 降级策略问题
- 高德失败 → 降级到Apple → Apple也被节流 → 继续尝试MKLocalSearch → 全部失败
- **问题**：在已经节流的情况下继续尝试，会进一步触发节流限制

---

## ✅ 优化方案

### 1. 增加高德API超时时间

**修改位置**：`Footprint/Helpers/AMapGeocodeService.swift`

**变更**：
```swift
// 之前：6秒
private let requestTimeout: TimeInterval = 6.0

// 之后：10秒
private let requestTimeout: TimeInterval = 10.0
```

**原因**：
- 网络不稳定时，6秒可能不够
- 增加到10秒可以应对大部分网络延迟情况
- 仍然保持合理的响应时间

---

### 2. 改进错误处理逻辑

**修改位置**：`Footprint/Views/MapView.swift` - `handleGeocodeError()` 方法

#### 2.1 检查节流状态

**新增逻辑**：
```swift
// 检查是否是节流错误
if let nsError = error as NSError?,
   nsError.domain == "GEOErrorDomain" && nsError.code == -3 {
    print("⚠️ Apple地理编码已被节流，停止尝试降级，避免进一步触发节流")
    showErrorFallback(coordinate: coordinate)
    return
}

// 检查当前是否处于节流状态
if isThrottled {
    print("⚠️ 当前处于节流状态，不继续尝试降级服务")
    showErrorFallback(coordinate: coordinate)
    return
}
```

**效果**：
- 检测到节流错误时，立即停止尝试，避免进一步触发节流
- 检查当前节流状态，避免在节流期间继续请求

#### 2.2 限制降级策略

**新增逻辑**：
```swift
// 只在用户主动点击时才尝试降级
if (error is AMapError || error.localizedDescription.contains("高德") || 
    error.localizedDescription.contains("超时") || 
    error.localizedDescription.contains("网络错误")) && isUserInitiated {
    // 尝试降级到Apple
} else {
    // 其他情况直接显示错误信息
    showErrorFallback(coordinate: coordinate)
}
```

**效果**：
- **用户主动点击**：可以尝试降级，提供更好的体验
- **自动请求**：直接显示错误，避免频繁触发节流
- **已节流状态**：不继续尝试，避免进一步触发限制

#### 2.3 添加错误回退方法

**新增方法**：
```swift
private func showErrorFallback(coordinate: CLLocationCoordinate2D) {
    fallbackWithCoordinateOnly(coordinate: coordinate)
}
```

**效果**：
- 统一处理错误情况
- 使用坐标兜底方案，至少显示位置信息

---

## 📊 优化效果

### 优化前

1. **高德超时** → 降级到Apple → Apple也被节流 → 继续尝试 → 全部失败
2. **频繁触发节流** → 60秒内超过50次请求 → 被系统限制
3. **用户体验差**：多次尝试失败后才显示兜底信息

### 优化后

1. **超时时间增加** → 减少超时错误的发生率
2. **智能检测节流** → 检测到节流立即停止，避免进一步触发
3. **限制降级策略** → 只在必要时（用户主动点击）才降级
4. **快速回退** → 检测到问题立即显示错误信息，不继续尝试

---

## 🔍 错误类型和处理策略

### 1. 高德API错误

| 错误类型 | 处理策略 |
|---------|---------|
| **网络超时** | 检查是否用户主动点击 → 是：降级到Apple；否：显示错误 |
| **API错误** | 显示错误信息，使用坐标兜底 |
| **无效响应** | 显示错误信息，使用坐标兜底 |

### 2. Apple地理编码错误

| 错误类型 | 处理策略 |
|---------|---------|
| **节流错误** (GEOErrorDomain -3) | 立即停止，显示错误，不再尝试 |
| **网络错误** | 显示错误信息，使用坐标兜底 |
| **其他错误** | 显示错误信息，使用坐标兜底 |

### 3. 节流状态

| 状态 | 处理策略 |
|------|---------|
| **已节流** | 停止所有请求，等待重置时间 |
| **节流中** | 不尝试降级，直接显示错误 |
| **未节流** | 正常处理请求 |

---

## 🎯 最佳实践建议

### 1. 避免频繁请求

- ✅ 使用请求去重（相同坐标10米内不重复请求）
- ✅ 使用防抖机制（至少间隔1-2秒）
- ✅ 启动阶段限制自动请求频率

### 2. 智能降级

- ✅ **用户主动点击**：可以尝试降级，提供更好的体验
- ❌ **自动请求**：不降级，避免触发节流
- ❌ **已节流状态**：不降级，立即显示错误

### 3. 超时设置

- ✅ 高德API：10秒（平衡响应速度和网络延迟）
- ✅ 如果网络特别不稳定，可以考虑增加到15秒

### 4. 错误处理

- ✅ 检测到节流错误立即停止
- ✅ 检查节流状态，避免继续请求
- ✅ 快速回退到兜底方案

---

## 📝 后续优化建议

### 1. 添加重试机制（可选）

```swift
// 对于网络错误，可以添加指数退避重试
private func retryWithExponentialBackoff(
    attempt: Int,
    maxAttempts: Int = 3,
    baseDelay: TimeInterval = 2.0
) {
    // 实现指数退避重试逻辑
}
```

### 2. 请求缓存（可选）

```swift
// 缓存最近的反向地理编码结果
private var geocodeCache: [String: GeocodeResult] = [:]

// 在请求前检查缓存
if let cached = geocodeCache[cacheKey] {
    return cached
}
```

### 3. 监控和日志（可选）

```swift
// 记录请求统计
private var requestStats = RequestStats()

// 监控请求频率
requestStats.recordRequest()
if requestStats.getRequestCount(in: 60) > 40 {
    print("⚠️ 警告：请求频率接近节流限制")
}
```

---

## ✅ 检查清单

- [x] 增加高德API超时时间（6秒 → 10秒）
- [x] 添加节流检测逻辑
- [x] 限制降级策略（只在用户主动点击时）
- [x] 添加错误回退方法
- [x] 检查节流状态，避免继续请求

---

**最后更新**：2025-12-05
**状态**：✅ 已完成优化

