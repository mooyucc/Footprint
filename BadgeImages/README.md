# 勋章图片文件夹

这个文件夹用于存放勋章图片的原始文件，脚本会自动将它们导入到 `Assets.xcassets` 中。

## 文件夹结构

```
BadgeImages/
├── Countries/          # 国家勋章图片
│   ├── CN.png         # 中国（可以使用 ISO 代码或完整名称）
│   ├── US.png         # 美国
│   ├── JP.png         # 日本
│   └── ...
└── Provinces/         # 省份勋章图片
    ├── 北京.png       # 北京
    ├── 上海.png       # 上海
    ├── 广东.png       # 广东
    └── ...
```

## 命名规范

### 国家图片命名（支持中文）
- **推荐方式**: 使用中文名称（如 `中国.jpg`, `美国.jpg`, `俄罗斯.jpg`, `日本.jpg`）
- **备选方式1**: 使用 ISO 国家代码（如 `CN.jpg`, `US.jpg`, `RU.jpg`）
- **备选方式2**: 使用完整名称（如 `CountryBadge_中国.jpg`, `CountryBadge_CN.jpg`）
- 脚本会自动识别中文名称并映射到对应的 ISO 代码
- 在 Assets.xcassets 中会创建为 `CountryBadge_CN.imageset`（使用 ISO 代码）

### 省份图片命名（支持中文）
- **推荐方式**: 使用省份名称（如 `北京.jpg`, `上海.jpg`, `广东.jpg`）
- **备选方式**: 使用完整名称（如 `ProvinceBadge_北京.jpg`）
- 脚本会自动识别并处理前缀
- 在 Assets.xcassets 中会创建为 `ProvinceBadge_北京.imageset`（保持中文名称）

## 使用方法

### 1. 准备图片
将你的图片文件放入对应的文件夹：
- 国家图片 → `BadgeImages/Countries/`
- 省份图片 → `BadgeImages/Provinces/`

### 2. 运行导入脚本

```bash
# 导入国家勋章图片
./scripts/import_badge_images.sh country

# 导入省份勋章图片
./scripts/import_badge_images.sh province
```

或者从项目根目录运行：

```bash
cd "/Users/kevinx/Documents/Ai Project/Footprint"
./scripts/import_badge_images.sh country
./scripts/import_badge_images.sh province
```

### 3. 在 Xcode 中查看
导入完成后，在 Xcode 中打开 `Assets.xcassets`，你应该能看到：
- `CountryBadges/` 文件夹（包含所有国家勋章）
- `ProvinceBadges/` 文件夹（包含所有省份勋章）

## 图片要求

- **格式**: PNG、JPG、JPEG（推荐 PNG）
- **尺寸**: 建议 200x200 到 400x400 像素（正方形）
- **命名**: 支持中文和英文文件名
- **数量**: 
  - 国家勋章：30+ 张
  - 省份勋章：31 张（中国31个省级行政区）

## 注意事项

1. **图片会自动去重**: 如果图片已存在于 Assets.xcassets 中，脚本会跳过
2. **支持批量导入**: 可以一次性放入所有图片，然后运行脚本
3. **自动生成配置**: 脚本会自动创建 `Contents.json` 文件
4. **保留原文件**: 原始图片文件不会被删除，可以随时重新导入

## 示例

假设你有以下图片文件：

```
BadgeImages/
├── Countries/
│   ├── 中国.jpg
│   ├── 美国.jpg
│   ├── 俄罗斯.jpg
│   └── 日本.jpg
└── Provinces/
    ├── 北京.jpg
    ├── 上海.jpg
    └── 广东.jpg
```

运行脚本后，这些图片会被导入为：

```
Assets.xcassets/
├── CountryBadges/
│   ├── CountryBadge_CN.imageset/      (中国.jpg → CN)
│   ├── CountryBadge_US.imageset/      (美国.jpg → US)
│   ├── CountryBadge_RU.imageset/      (俄罗斯.jpg → RU)
│   └── CountryBadge_JP.imageset/       (日本.jpg → JP)
└── ProvinceBadges/
    ├── ProvinceBadge_北京.imageset/    (保持中文名称)
    ├── ProvinceBadge_上海.imageset/
    └── ProvinceBadge_广东.imageset/
```

**注意**: 国家图片使用中文名称（如 `俄罗斯.jpg`）时，脚本会自动映射到 ISO 代码（如 `RU`），在 Assets 中创建为 `CountryBadge_RU.imageset`。

## 故障排除

### 问题：脚本提示"源文件夹不存在"
**解决**: 确保已创建 `BadgeImages/Countries/` 或 `BadgeImages/Provinces/` 文件夹

### 问题：图片导入后 Xcode 中看不到
**解决**: 
1. 在 Xcode 中右键点击 `Assets.xcassets` → "Add Files to..."
2. 或者关闭并重新打开 Xcode 项目

### 问题：图片名称不符合预期
**解决**: 检查图片文件名，确保符合命名规范。脚本会自动处理常见的前缀。

