# CloudKit 错误 11 排查步骤

## ❌ 错误信息

```
❌ 加载公共目的地失败: Did not find record type: PublicDestination
   CloudKit 错误码: 11
   CloudKit 错误域: CKErrorDomain
```

**错误码 11 = `CKError.Code.unknownItem`**：表示 CloudKit 找不到 `PublicDestination` Record Type。

---

## 🔍 排查步骤（按顺序执行）

### 步骤 1：确认 Container 和环境

1. 访问 [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
2. 在左侧导航栏顶部，确认：
   - **Container**: `iCloud.Mooyu.Footprint` ✅
   - **环境**: `Development` ✅

> ✅ 从你的截图看，这两项已正确。

---

### 步骤 2：检查 Record Type 是否已创建

1. 在左侧导航栏，点击 **Schema** > **Record Types**
2. 在右侧主内容区域，查找 **`PublicDestination`** Record Type
3. 确认它是否存在

**情况 A：如果 `PublicDestination` 不存在**
- 说明：Record Type 尚未创建
- 解决：按照 `CloudKit配置指南.md` 的步骤创建 Record Type、字段、索引和权限

**情况 B：如果 `PublicDestination` 存在**
- 继续执行步骤 3

---

### 步骤 3：检查 Schema 是否已部署（最常见原因）

即使 `PublicDestination` Record Type 已创建，**如果没有部署 Schema Changes，App 仍然无法访问它**。

#### 3.1 检查是否有未部署的更改

1. 在左侧导航栏，查看 **Schema** 部分
2. 如果看到 **"Modified"** 标记（红色圆点或文字），说明有未部署的更改

#### 3.2 部署 Schema Changes

1. 在左侧导航栏底部，找到 **"Deploy Schema Changes..."** 链接
2. 点击它
3. 在弹出的对话框中：
   - 选择 **Development**（开发环境）
   - 点击 **Deploy** 或 **Deploy to Development**
4. 等待部署完成（通常几秒到几十秒）

#### 3.3 验证部署是否成功

部署成功后：
- 左侧导航栏的 **"Modified"** 标记应该消失
- 在 **Schema** > **Record Types** 中，`PublicDestination` 应该显示为已部署状态

---

### 步骤 4：验证字段和索引

即使已部署，如果字段或索引配置不正确，也可能导致查询失败。

1. 在 **Schema** > **Record Types** 中，点击 **`PublicDestination`**
2. 确认以下字段已添加：
   - `destinationId` (String)
   - `ownerId` (String)
   - `name` (String)
   - `country` (String)
   - `province` (String)
   - `location` (Location)
   - `visitYear` (Int(64))
   - `isActive` (Boolean 或 Int(64))
   - `sharedAt` (Date/Time)

3. 在 **Schema** > **Indexes** 中，确认以下索引已创建：
   - `isActive` (QUERYABLE) - **必需**
   - `destinationId` (QUERYABLE) - 建议
   - `sharedAt` (QUERYABLE) - 建议

---

### 步骤 5：验证 Security Roles

1. 在 **Schema** > **Security Roles** 中
2. 确认 `PublicDestination` 的权限配置：
   - **`_world`**: Read ✅
   - **`_icloud`**: Create ✅
   - **`_creator`**: Write ✅

---

### 步骤 6：重新部署（如果修改了任何配置）

如果在步骤 4 或 5 中修改了任何配置：

1. 再次点击 **"Deploy Schema Changes..."**
2. 选择 **Development**
3. 点击 **Deploy**

---

### 步骤 7：测试 App

1. 关闭 App（完全退出）
2. 重新打开 App
3. 切换到「发现地图」模式
4. 查看控制台日志

**预期结果：**
- 不再出现 "Did not find record type" 错误
- 控制台显示：`✅ 加载了 X 个新的公共目的地`

---

## 🎯 快速检查清单

在 CloudKit Dashboard 中，逐项确认：

- [ ] Container 为 `iCloud.Mooyu.Footprint`
- [ ] 环境为 `Development`
- [ ] `PublicDestination` Record Type 已创建
- [ ] 所有 9 个字段已添加
- [ ] `isActive` 索引已创建（QUERYABLE）
- [ ] Security Roles 已配置（`_world` Read、`_icloud` Create、`_creator` Write）
- [ ] **已执行 "Deploy Schema Changes" > Development** ⚠️ **最关键**
- [ ] 部署后左侧导航栏没有 "Modified" 标记

---

## 💡 常见问题

### Q1: 我已经创建了 Record Type，为什么还是报错？

**A:** 最常见的原因是**没有部署 Schema Changes**。在 Dashboard 中创建或修改 Schema 后，必须点击 **"Deploy Schema Changes"** 才能让 App 访问。

### Q2: 部署需要多长时间？

**A:** 通常几秒到几十秒。部署完成后，左侧导航栏的 "Modified" 标记会消失。

### Q3: 我部署了，但还是报错？

**A:** 请检查：
1. 是否部署到了正确的环境（Development vs Production）
2. 是否部署到了正确的 Container（`iCloud.Mooyu.Footprint`）
3. App 中打印的 Container 标识符是否与 Dashboard 一致（查看控制台的 `🔍 PublicDiscoverStore Container: ...`）

### Q4: 如何确认部署是否成功？

**A:** 
- 左侧导航栏的 "Modified" 标记消失
- 在 **Data** > **Records** 中，选择 `PublicDestination` 可以正常查询（如果已创建记录）

---

## 📞 如果仍然无法解决

如果按照以上步骤操作后仍然报错，请提供：

1. CloudKit Dashboard 截图：
   - **Schema** > **Record Types** > `PublicDestination` 的详情页
   - **Schema** > **Indexes** 中 `PublicDestination` 的索引列表
   - **Schema** > **Security Roles** 中 `PublicDestination` 的权限配置

2. App 控制台完整日志（包括 Container 标识符）

3. 确认是否已执行 "Deploy Schema Changes"

---

---

## ❌ 错误码 12：Field 'sharedAt' is not marked sortable

### 错误信息

```
❌ 加载公共目的地失败: Field 'sharedAt' is not marked sortable
   CloudKit 错误码: 12
   CloudKit 错误域: CKErrorDomain
```

**错误码 12 = `CKError.Code.invalidArguments`**：表示尝试对一个未标记为 SORTABLE 的字段进行排序。

### 原因

在 CloudKit 查询中使用了 `sortDescriptors` 对 `sharedAt` 字段排序，但该字段在 CloudKit Schema 中只标记为 **QUERYABLE**，未标记为 **SORTABLE**。

### 解决方案

**方案一（推荐）：代码已修复，在内存中排序**

当前代码已在内存中排序，不再在 CloudKit 查询中排序，因此此错误不会影响功能。代码会自动处理排序。

**方案二（可选优化）：在 CloudKit 中标记为 SORTABLE**

如果需要在 CloudKit 查询中直接排序（提升性能），可以：

1. 在 CloudKit Dashboard 中，进入 **Schema** > **Indexes**
2. 为 `PublicDestination` Record Type 创建一个新的索引：
   - **Name**: `sharedAt_SORTABLE`
   - **Type**: `SORTABLE`
   - **Field**: `sharedAt`
3. 点击 **Save**
4. 执行 **"Deploy Schema Changes"** > **Development**
5. 部署完成后，可以修改代码恢复 CloudKit 排序（可选）

> 💡 **提示**：方案一（内存排序）已经足够，除非有大量数据需要排序，否则不需要方案二。

---

**最后更新**: 2026-01-25
