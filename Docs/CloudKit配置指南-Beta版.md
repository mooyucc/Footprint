# CloudKit 公共数据库配置指南 - Beta 版

## 📋 概述

本文档说明如何在 **Beta 版 Container**（`iCloud.Mooyu.Footprint.beta`）中创建 `PublicDestination` schema，用于 Beta 测试版本的发现地图功能。

> 💡 **提示**：如果你已经配置过正式版的 CloudKit Schema，可以直接参考正式版配置指南，步骤完全相同，只需切换到 Beta Container。

---

## 📦 第一步：选择 Beta 版 CloudKit Container

### 容器对照表

| Container | 对应版本 | Bundle ID | 何时使用 |
|-----------|----------|-----------|----------|
| `iCloud.Mooyu.Footprint.beta` | **Beta 测试版** | `Mooyu.Footprint.beta` | **当前配置目标**：Beta 构建、TestFlight 测试 |
| `iCloud.Mooyu.Footprint` | 生产版（正式版） | `Mooyu.Footprint` | App Store 版本（已配置） |

### 操作步骤

1. 访问 [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
2. 使用你的 **Apple Developer 账号**登录
3. 在顶部 **Container** 下拉菜单中选择：**`iCloud.Mooyu.Footprint.beta`** ⚠️ **重要：必须选择 Beta Container**
4. 确认右侧显示 **Development**（开发时）或 **Production**（发布后）

> ⚠️ **注意**：本指南后续所有操作都在 **`iCloud.Mooyu.Footprint.beta`** 下进行。Beta 版和正式版的数据完全独立。

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
| `location` | Location | 坐标（经纬度） | ✅ |
| `visitYear` | Int(64) | 访问年份 | ✅ |
| `isActive` | Boolean 或 Int(64) | 是否激活（false 表示已取消共享） | ✅ |
| `sharedAt` | Date/Time | 共享时间 | ✅ |

### 添加字段步骤

1. 在 `PublicDestination` Record Type 详情页，找到 **Fields** 部分
2. 点击 **+** 按钮添加字段
3. 输入字段名，选择类型，点击 **Save**
4. 重复上述步骤，添加所有 9 个字段

---

## 📊 第四步：创建索引（Indexes）

索引用于优化查询性能，**必须创建**，否则查询会失败或很慢。

### 必需索引

1. 在左侧菜单选择 **Schema** > **Indexes**
2. 点击右上角的 **+** 按钮
3. 填写：
   - **Record Type**: `PublicDestination`
   - **Name**: `isActive`
   - **Type**: `QUERYABLE`
   - **Field**: `isActive`
4. 点击 **Save**

### 建议索引（便于去重和排序）

- **`destinationId`** (QUERYABLE) - 用于查找已存在的记录
- **`sharedAt`** (QUERYABLE + SORTABLE) - 用于按共享时间排序
  - ⚠️ **重要**：如果需要在 CloudKit 查询中直接排序，必须同时标记为 **QUERYABLE** 和 **SORTABLE**
  - 当前代码已在内存中排序，所以 SORTABLE 不是必须的，但可以提升性能

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
- **Create**: 登录用户可创建 → `_icloud` 有 **Create**
- **Write**: 创建者可更新/删除 → `_creator` 有 **Write**

### 配置步骤

1. 在左侧菜单选择 **Schema** > **Security Roles**
2. 找到 **PublicDestination** 行，配置三个默认角色：

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

1. 确认当前 Container 为 **`iCloud.Mooyu.Footprint.beta`** ⚠️ **必须确认**
2. 在 **Schema** > **Record Types** 中，确认 `PublicDestination` 已创建
3. 检查所有字段均已添加，类型与上表一致
4. 确认 **`isActive`**（及建议的 `destinationId`、`sharedAt`）已添加 Queryable 索引

---

## 📝 注意事项

1. **选对 Container**：
   - Beta 版 App 使用 **`iCloud.Mooyu.Footprint.beta`**，正式版使用 **`iCloud.Mooyu.Footprint`**
   - 若选错容器，App 无法读写对应 CloudKit 数据，发现地图会一直为空或同步失败
   - ⚠️ **Beta 版和正式版的数据完全独立**，不会互相影响

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

6. **Beta 版与正式版的关系**：
   - Beta 版和正式版使用不同的 Container，数据完全独立
   - 在 Beta Container 中创建的 Schema 不会影响正式版
   - 两个版本需要分别配置和部署 Schema

---

## 🚀 完成

配置完成后，你的 Beta 版 App 就可以：
- 将用户共享的目的地同步到 CloudKit 公共数据库（Beta Container）
- 从公共数据库拉取所有用户共享的地点（仅 Beta 版用户的数据）
- 在「发现地图」中展示这些地点

---

## ✅ CloudKit 配置完成检查清单（Beta 版）

在进入 App 测试前，请逐项确认：

| 项目 | 状态 |
|------|------|
| Container 选择 **`iCloud.Mooyu.Footprint.beta`** ⚠️ **必须确认** | ☐ |
| **PublicDestination** Record Type 已创建 | ☐ |
| 9 个字段已添加（destinationId, ownerId, name, country, province, location, visitYear, isActive, sharedAt） | ☐ |
| **isActive** QUERYABLE 索引已创建 | ☐ |
| **destinationId**、**sharedAt** QUERYABLE 索引已创建（建议） | ☐ |
| **Security Roles**：`_world` Read、`_icloud` Create、`_creator` Write（PublicDestination） | ☐ |
| 所有修改已 **Save** | ☐ |
| **Deploy Schema Changes** > **Development** 已执行（必须，否则报 `Did not find record type`） | ☐ |

全部打勾后，Beta 版 CloudKit 配置即告完成，可进行 App 端测试。

---

## 🔗 相关文档

- [CloudKit 官方文档](https://developer.apple.com/documentation/cloudkit)
- [CloudKit Dashboard 使用指南](https://developer.apple.com/documentation/cloudkit/cloudkit_dashboard)
- 项目内：`Docs/CloudKit配置指南.md`（正式版配置指南）
- 项目内：`Docs/CloudKit错误11排查步骤.md`（错误排查）
- 项目内：`Docs/CloudKit查询优化说明.md`（查询策略与索引说明）

---

**最后更新**: 2026-01-25
