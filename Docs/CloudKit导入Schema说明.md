# CloudKit Schema 导入说明

## ⚠️ 关于导入 Schema 的警告

当你尝试从正式版 Container 导入 Schema 到 Beta 版 Container 时，可能会遇到以下警告：

```
cannot remove field CD_isShared which exists in active production type 
CKRecordTypeName(value='CD_TravelDestination')
```

## 🔍 问题原因

### 1. 两种不同的 Record Type

你的项目中有**两种不同的 CloudKit Record Type**：

| Record Type | 来源 | 用途 | 说明 |
|------------|------|------|------|
| `CD_TravelDestination` | SwiftData 自动生成 | 本地数据同步（私有数据库） | SwiftData 使用 `CD_` 前缀自动创建 |
| `PublicDestination` | 手动创建 | 公共发现地图（公共数据库） | 用于发现地图功能 |

### 2. 字段冲突

- **`CD_TravelDestination`** 是 SwiftData 自动管理的类型，包含 `CD_isShared` 字段（对应 `TravelDestination.isShared`）
- 导入的 Schema 中缺少 `CD_isShared` 字段
- Beta 版的 **Production 环境**中已经存在包含 `CD_isShared` 的 `CD_TravelDestination` 类型
- CloudKit **不允许删除**生产环境中已存在的字段，以防止数据丢失

### 3. 为什么会出现这个警告

- 你导出的 Schema 可能只包含 `PublicDestination`，或者 `CD_TravelDestination` 的版本较旧
- Beta 版的 Production 环境中已经有更新的 `CD_TravelDestination` 类型（包含 `CD_isShared`）
- CloudKit 检测到导入会删除生产环境中的字段，因此拒绝导入

---

## ✅ 解决方案

### 方案一：手动配置（推荐）

**不要导入 Schema**，而是按照配置指南手动创建 `PublicDestination`：

1. **取消导入**：点击 "Cancel" 按钮
2. **按照 Beta 版配置指南操作**：
   - 打开 `Docs/CloudKit配置指南-Beta版.md`
   - 按照步骤手动创建 `PublicDestination` Record Type
   - 添加字段、创建索引、配置权限
   - 部署 Schema

**优点**：
- ✅ 不会影响现有的 `CD_TravelDestination` 类型
- ✅ 只创建需要的 `PublicDestination` 类型
- ✅ 避免字段冲突
- ✅ 更清晰、可控

**注意**：`CD_TravelDestination` 是 SwiftData 自动管理的，**不需要手动配置**。

---

### 方案二：只导入 PublicDestination（如果必须导入）

如果你确实需要导入 Schema，可以：

1. **从正式版导出时，只选择 `PublicDestination`**：
   - 在正式版 Container 中，导出 Schema 时只选择 `PublicDestination` Record Type
   - 不要包含 `CD_TravelDestination` 相关的 Schema

2. **或者，修改导出的 Schema 文件**：
   - 编辑导出的 `.ckdb` 文件（需要了解格式）
   - 确保包含 `CD_isShared` 字段（不推荐，复杂且容易出错）

**缺点**：
- ⚠️ 需要手动编辑 Schema 文件
- ⚠️ 可能引入其他问题
- ⚠️ 不推荐，除非有特殊需求

---

### 方案三：清理 Production 环境（不推荐）

**⚠️ 危险操作，可能导致数据丢失**

1. 切换到 **Production** 环境
2. 删除或修改 `CD_TravelDestination` 类型
3. 然后导入 Schema

**为什么不推荐**：
- ❌ 可能丢失生产环境中的数据
- ❌ 影响已发布的 App
- ❌ 违反 CloudKit 最佳实践

---

## 📋 推荐操作步骤

### 对于 Beta 版 Container 配置

1. **取消当前的导入操作**
   - 点击 "Cancel" 按钮

2. **手动配置 `PublicDestination`**（推荐）
   - 参考 `Docs/CloudKit配置指南-Beta版.md`
   - 按照步骤创建 `PublicDestination` Record Type
   - 添加 9 个必需字段
   - 创建索引（`isActive`、`destinationId`、`sharedAt`）
   - 配置 Security Roles
   - 部署到 Development 环境

3. **忽略 `CD_TravelDestination`**
   - `CD_TravelDestination` 是 SwiftData 自动管理的
   - 不需要手动配置
   - 它会随着 App 的使用自动同步到 CloudKit

---

## 🔍 如何确认配置是否正确

### 检查 `PublicDestination` 是否已创建

1. 在 CloudKit Dashboard 中
2. 选择 Container: `iCloud.Mooyu.Footprint.beta`
3. 环境: `Development`
4. 进入 **Schema** > **Record Types**
5. 确认 `PublicDestination` 存在

### 检查 `CD_TravelDestination`（自动管理）

1. 在 **Schema** > **Record Types** 中
2. 应该能看到 `CD_TravelDestination`（SwiftData 自动创建）
3. 它应该包含 `CD_isShared` 字段
4. **不需要手动修改**，SwiftData 会自动管理

---

## 💡 重要提示

### 关于 `CD_TravelDestination` 和 `PublicDestination`

- **`CD_TravelDestination`**：
  - SwiftData 自动创建和管理
  - 用于私有数据库同步（用户自己的数据）
  - 包含 `CD_isShared` 字段（标记是否共享）
  - **不需要手动配置**

- **`PublicDestination`**：
  - 手动创建
  - 用于公共数据库（发现地图功能）
  - 只包含可公开分享的信息
  - **需要手动配置**

### 两个类型的关系

```
TravelDestination (本地 SwiftData 模型)
    ├── isShared: Bool  // 标记是否共享
    │
    ├── 如果 isShared == true
    │   └── 同步到 PublicDestination (公共数据库)
    │
    └── 同时同步到 CD_TravelDestination (私有数据库，自动)
```

---

## 📚 相关文档

- `Docs/CloudKit配置指南-Beta版.md` - Beta 版完整配置指南
- `Docs/CloudKit配置指南.md` - 正式版配置指南
- `Docs/CloudKit错误11排查步骤.md` - 错误排查指南

---

**最后更新**: 2026-01-25
