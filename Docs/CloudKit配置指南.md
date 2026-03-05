# CloudKit 公共数据库配置指南

## 📋 概述

本文档说明如何在 CloudKit Dashboard 中创建 `PublicDestination` schema，用于存储所有用户共享的目的地。

---

## 📦 第一步：选择正确的 CloudKit Container

Footprint 项目下有多个类似的 CloudKit 容器，**必须选对**，否则 App 无法访问。

### 容器对照表

| Container | 对应版本 | Bundle ID | 何时使用 |
|-----------|----------|-----------|----------|
| **`iCloud.Mooyu.Footprint`** | 生产版（正式版） | `Mooyu.Footprint` | **推荐**：日常开发、App Store 版本 |
| `iCloud.Mooyu.Footprint.beta` | Beta 测试版 | `Mooyu.Footprint.beta` | 仅 Beta 构建、TestFlight 测试 |
| `iCloud.MooFootprint.Footprint` | 旧版 / 其他配置 | - | 当前项目**未使用**，忽略 |

### 操作步骤

1. 访问 [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
2. 使用你的 **Apple Developer 账号**登录
3. 在顶部 **Container** 下拉菜单中选择：**`iCloud.Mooyu.Footprint`**
4. 确认右侧显示 **Development**（开发时）或 **Production**（发布后）

> ⚠️ **注意**：本指南后续所有操作都在 **`iCloud.Mooyu.Footprint`** 下进行。若你在 Beta 版 App 中测试发现地图，则需在 **`iCloud.Mooyu.Footprint.beta`** 中同样创建一份 Schema。

---

## 🔧 第二步：打开 Schema 并创建 Record Type

1. 在左侧菜单选择 **Schema** > **Record Types**
2. 点击右上角的 **+** 按钮，创建新的 Record Type
3. 输入名称：`PublicDestination`
4. 点击 **Create**

---

## 🗂️ 第三步：添加字段

在 `PublicDestination` Record Type 中，添加以下字段：

| 字段名 | 类型 | 说明 | 是否必需 |
|--------|------|------|----------|
| `destinationId` | String | 本地目的地 ID（UUID 字符串） | ✅ |
| `ownerId` | String | 分享者 ID（CloudKit userRecordID） | ✅ |
| `name` | String | 地点名称 | ✅ |
| `country` | String | 国家 | ✅ |
| `province` | String | 省份/州 | ✅ |
| `location` | Location | 坐标（CLLocation） | ✅ |
| `visitYear` | Int(64) | 访问年份 | ✅ |
| `isActive` | Int(64) 或 Boolean | 是否激活（1=是/true，0=否/false） | ✅ |
| `sharedAt` | Date/Time | 共享时间 | ✅ |

### 添加字段步骤：

1. 在 `PublicDestination` Record Type 页面，点击 **Add Field** 按钮
2. 输入字段名（例如：`destinationId`）
3. 选择字段类型（例如：`String`）
4. 点击 **Save**
5. 重复以上步骤，添加所有字段

---

## 🔍 第四步：创建索引

当前实现会先按 `isActive` 查询，再在内存中按可见区域过滤，因此**至少**需要为 `isActive` 创建 Queryable 索引。

### 创建索引步骤

1. 在左侧菜单选择 **Schema** > **Indexes**
2. 点击右上角的 **+** 按钮，打开 **Add Index** 对话框
3. 在对话框中填写：
   - **Record Type**: 选择 `PublicDestination`
   - **Name**: 输入索引名称（通常与字段名相同，例如：`isActive`）
   - **Type**: 选择 `QUERYABLE`
   - **Field**: 选择要索引的字段（例如：`isActive`）
4. 点击 **Add** 按钮创建索引

### 需要创建的索引

**必需索引：**
- **`isActive`** (QUERYABLE) - 用于查询激活的公共目的地

**建议索引（便于去重和排序）：**
- **`destinationId`** (QUERYABLE) - 用于查找已存在的记录
- **`sharedAt`** (QUERYABLE + SORTABLE) - 用于按共享时间排序
  - ⚠️ **重要**：如果需要在 CloudKit 查询中直接排序，必须同时标记为 **QUERYABLE** 和 **SORTABLE**
  - 当前代码已在内存中排序，所以 SORTABLE 不是必须的，但可以提升性能

**Dashboard Records 查询所需（可选但推荐）：**
- **`recordName`** (QUERYABLE) - 系统字段。若不建此索引，在 **Data > Records** 中选 `PublicDestination` 查询时会报 **"Field 'recordName' is not marked queryable"**，无法在 Dashboard 里浏览记录。App 端查询不受影响。

> 💡 **提示**：`location` 字段目前不需要索引，因为我们在内存中过滤位置。如果未来改用 CloudKit 的距离查询，再为 `location` 添加 Queryable 索引。

### 重复创建其他索引

按照上述步骤，再为以下字段分别创建 QUERYABLE 索引：
- Record Type: `PublicDestination`，Name: `destinationId`，Type: `QUERYABLE`，Field: `destinationId`
- Record Type: `PublicDestination`，Name: `sharedAt`，Type: `QUERYABLE`，Field: `sharedAt`
  - 💡 **可选优化**：如果需要在 CloudKit 查询中直接排序（而非内存排序），可以再创建一个 **SORTABLE** 索引：
    - Record Type: `PublicDestination`，Name: `sharedAt_SORTABLE`，Type: `SORTABLE`，Field: `sharedAt`
- Record Type: `PublicDestination`，Name: `recordName`，Type: `QUERYABLE`，Field: `recordName`（用于 Dashboard **Records** 查询，否则报 `recordName is not marked queryable`）

> ⚠️ **注意**：如果 `sharedAt` 字段未标记为 SORTABLE，在查询中使用 `sortDescriptors` 会报错 **"Field 'sharedAt' is not marked sortable"**（错误码 12）。当前代码已在内存中排序，所以此错误不会影响功能，但标记为 SORTABLE 可以提升性能。

---

## ✅ 第五步：设置 Security Roles（权限）

权限在 **Schema** > **Security Roles** 中，通过默认角色 **`_world`**、**`_icloud`**、**`_creator`** 配置。针对 **`PublicDestination`** 需满足：

- **Read**: World（所有人可读）→ `_world` 有 **Read**
- **Write**: 仅登录用户可写 → `_icloud` 有 **Create**，`_creator` 有 **Write**

### 操作步骤

1. 左侧菜单选择 **Schema** > **Security Roles**
2. 在 **Default Roles** 中依次检查并配置：

**`_world`（所有人，含未登录）：**
- 找到 **PublicDestination** 行
- 勾选 **Read**，不勾选 Create、Write  
- 效果：所有人都能在「发现地图」中查看共享地点

**`_icloud`（已登录用户）：**
- 找到 **PublicDestination** 行
- 勾选 **Create**，不勾选 Read、Write  
- 效果：登录用户可**共享**新地点（创建记录）

**`_creator`（记录创建者）：**
- 找到 **PublicDestination** 行
- 勾选 **Write**，不勾选 Create、Read  
- 效果：用户可**更新/删除**自己共享的地点（取消共享、编辑）

3. 点击 **Save** 保存

### 配置对照表

| 角色 | Create | Read | Write | 含义 |
|------|--------|------|-------|------|
| `_world` | ❌ | ✅ | ❌ | 所有人可读 |
| `_icloud` | ✅ | ❌ | ❌ | 登录用户可创建 |
| `_creator` | ❌ | ❌ | ✅ | 创建者可更新/删除 |

这样设置后：
- 所有用户（含未登录）都可以在「发现地图」中看到共享的地点
- 只有登录用户才能共享新地点；只有创建者才能取消共享或编辑已共享的地点

---

## 🧪 第六步：验证配置

1. 确认当前 Container 为 **`iCloud.Mooyu.Footprint`**（或 Beta 用的 `iCloud.Mooyu.Footprint.beta`）
2. 在 **Schema** > **Record Types** 中，确认 `PublicDestination` 已创建
3. 检查所有字段均已添加，类型与上表一致
4. 确认 **`isActive`**（及建议的 `destinationId`、`sharedAt`）已添加 Queryable 索引

---

## 📝 注意事项

1. **选对 Container**：
   - 生产版 App 使用 **`iCloud.Mooyu.Footprint`**，Beta 版使用 **`iCloud.Mooyu.Footprint.beta`**
   - 若选错容器，App 无法读写对应 CloudKit 数据，发现地图会一直为空或同步失败

2. **开发环境 vs 生产环境**：
   - CloudKit 有 Development 和 Production 两个环境
   - 开发时使用 Development，发布前需要部署到 Production
   - 在 Dashboard 右上角可以切换环境

3. **必须部署 Schema 后才会生效**（常见遗漏）：
   - 在 Dashboard 里创建/修改 Record Types、Indexes、Security 后，左侧会显示 **Modified**
   - 必须点击 **Deploy Schema Changes**，选择 **Development**，部署到开发环境
   - 否则 App 查询会报 **"Did not find record type: PublicDestination"**，因为 schema 尚未生效
   - 发布前再部署到 **Production**

4. **首次部署到 Production**：
   - 在 Development 环境测试完成后
   - 在 Dashboard 中选择 **Deploy Schema Changes** > **Production**
   - 这会同步 schema 到生产环境

5. **数据隐私**：
   - 公共数据库中的数据对所有用户可见
   - 确保只存储可以公开的信息（名称、位置、国家等）
   - 不要存储私密信息（详细笔记、消费记录等）

---

## 🚀 完成

配置完成后，你的 App 就可以：
- 将用户共享的目的地同步到 CloudKit 公共数据库
- 从公共数据库拉取所有用户共享的地点
- 在「发现地图」中展示这些地点

---

## ✅ CloudKit 配置完成检查清单

在进入 App 测试前，请逐项确认：

| 项目 | 状态 |
|------|------|
| Container 选择 **`iCloud.Mooyu.Footprint`** | ☐ |
| **PublicDestination** Record Type 已创建 | ☐ |
| 9 个字段已添加（destinationId, ownerId, name, country, province, location, visitYear, isActive, sharedAt） | ☐ |
| **isActive** QUERYABLE 索引已创建 | ☐ |
| **destinationId**、**sharedAt** QUERYABLE 索引已创建（建议） | ☐ |
| **Security Roles**：`_world` Read、`_icloud` Create、`_creator` Write（PublicDestination） | ☐ |
| 所有修改已 **Save** | ☐ |
| **Deploy Schema Changes** > **Development** 已执行（必须，否则报 `Did not find record type`） | ☐ |

全部打勾后，CloudKit 配置即告完成，可进行 App 端测试。

---

## 🔗 相关文档

- [CloudKit 官方文档](https://developer.apple.com/documentation/cloudkit)
- [CloudKit Dashboard 使用指南](https://developer.apple.com/documentation/cloudkit/cloudkit_dashboard)
- 项目内：`Docs/CloudKit配置指南-Beta版.md`（Beta 版配置指南）
- 项目内：`Docs/CloudKit错误11排查步骤.md`（错误排查）
- 项目内：`Docs/CloudKit查询优化说明.md`（查询策略与索引说明）
- 项目内：`Docs/发现地图功能快速测试指南.md`（配置完成后的测试步骤）
