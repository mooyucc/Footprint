#!/bin/bash

# 批量导入勋章图片到 Assets.xcassets 的脚本
# 使用方法: ./import_badge_images.sh [图片类型]
# 图片类型: country (国家) 或 province (省份)，默认为 country

set +e  # 不立即退出，继续处理所有文件

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 配置路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
BADGE_IMAGES_DIR="$PROJECT_ROOT/BadgeImages"
ASSETS_DIR="$PROJECT_ROOT/Footprint/Assets.xcassets"

# 图片类型（country 或 province）
BADGE_TYPE="${1:-country}"

# 是否强制覆盖已存在的图片（第二个参数：--force 或 -f）
FORCE_OVERWRITE=false
if [ "$2" = "--force" ] || [ "$2" = "-f" ]; then
    FORCE_OVERWRITE=true
fi

# 根据类型设置目标文件夹和前缀
if [ "$BADGE_TYPE" = "province" ]; then
    TARGET_DIR="$ASSETS_DIR/ProvinceBadges"
    PREFIX="ProvinceBadge_"
    SOURCE_DIR="$BADGE_IMAGES_DIR/Provinces"
    TYPE_NAME="省份"
else
    TARGET_DIR="$ASSETS_DIR/CountryBadges"
    PREFIX="CountryBadge_"
    SOURCE_DIR="$BADGE_IMAGES_DIR/Countries"
    TYPE_NAME="国家"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}批量导入${TYPE_NAME}勋章图片${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 检查源文件夹是否存在
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}错误: 源文件夹不存在: $SOURCE_DIR${NC}"
    echo -e "${YELLOW}请创建文件夹并放入图片文件${NC}"
    echo ""
    echo "文件夹结构应该是:"
    echo "  BadgeImages/"
    if [ "$BADGE_TYPE" = "province" ]; then
        echo "    Provinces/"
        echo "      北京.png"
        echo "      上海.png"
        echo "      ..."
    else
        echo "    Countries/"
        echo "      CN.png (或 CountryBadge_CN.png)"
        echo "      US.png (或 CountryBadge_US.png)"
        echo "      ..."
    fi
    exit 1
fi

# 创建目标文件夹
mkdir -p "$TARGET_DIR"
echo -e "${GREEN}✓ 目标文件夹已准备: $TARGET_DIR${NC}"

# 统计变量
SUCCESS_COUNT=0
SKIP_COUNT=0
ERROR_COUNT=0

# 支持的图片格式
SUPPORTED_FORMATS=("png" "jpg" "jpeg" "PNG" "JPG" "JPEG")

# 生成 Contents.json 的函数
generate_contents_json() {
    local image_filename="$1"
    local imageset_dir="$2"
    
    cat > "$imageset_dir/Contents.json" << EOF
{
  "images" : [
    {
      "filename" : "$image_filename",
      "idiom" : "universal",
      "scale" : "1x"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF
}

# 国家中文名称到 ISO 代码的映射（基于 CountryManager）
get_country_code() {
    local chinese_name="$1"
    case "$chinese_name" in
        "中国") echo "CN" ;;
        "美国") echo "US" ;;
        "日本") echo "JP" ;;
        "韩国") echo "KR" ;;
        "新加坡") echo "SG" ;;
        "泰国") echo "TH" ;;
        "马来西亚") echo "MY" ;;
        "印度尼西亚") echo "ID" ;;
        "菲律宾") echo "PH" ;;
        "越南") echo "VN" ;;
        "印度") echo "IN" ;;
        "澳大利亚") echo "AU" ;;
        "新西兰") echo "NZ" ;;
        "加拿大") echo "CA" ;;
        "英国") echo "GB" ;;
        "法国") echo "FR" ;;
        "德国") echo "DE" ;;
        "意大利") echo "IT" ;;
        "西班牙") echo "ES" ;;
        "荷兰") echo "NL" ;;
        "瑞士") echo "CH" ;;
        "奥地利") echo "AT" ;;
        "比利时") echo "BE" ;;
        "丹麦") echo "DK" ;;
        "芬兰") echo "FI" ;;
        "挪威") echo "NO" ;;
        "瑞典") echo "SE" ;;
        "波兰") echo "PL" ;;
        "捷克") echo "CZ" ;;
        "匈牙利") echo "HU" ;;
        "希腊") echo "GR" ;;
        "葡萄牙") echo "PT" ;;
        "爱尔兰") echo "IE" ;;
        "卢森堡") echo "LU" ;;
        "俄罗斯") echo "RU" ;;
        "乌克兰") echo "UA" ;;
        "土耳其") echo "TR" ;;
        "以色列") echo "IL" ;;
        "阿联酋") echo "AE" ;;
        "沙特阿拉伯") echo "SA" ;;
        "卡塔尔") echo "QA" ;;
        "科威特") echo "KW" ;;
        "巴林") echo "BH" ;;
        "阿曼") echo "OM" ;;
        "约旦") echo "JO" ;;
        "黎巴嫩") echo "LB" ;;
        "埃及") echo "EG" ;;
        "南非") echo "ZA" ;;
        "尼日利亚") echo "NG" ;;
        "肯尼亚") echo "KE" ;;
        "摩洛哥") echo "MA" ;;
        "突尼斯") echo "TN" ;;
        "阿尔及利亚") echo "DZ" ;;
        "埃塞俄比亚") echo "ET" ;;
        "加纳") echo "GH" ;;
        "乌干达") echo "UG" ;;
        "坦桑尼亚") echo "TZ" ;;
        "津巴布韦") echo "ZW" ;;
        "博茨瓦纳") echo "BW" ;;
        "纳米比亚") echo "NA" ;;
        "赞比亚") echo "ZM" ;;
        "马拉维") echo "MW" ;;
        "莫桑比克") echo "MZ" ;;
        "马达加斯加") echo "MG" ;;
        "毛里求斯") echo "MU" ;;
        "塞舌尔") echo "SC" ;;
        "巴西") echo "BR" ;;
        "阿根廷") echo "AR" ;;
        "智利") echo "CL" ;;
        "哥伦比亚") echo "CO" ;;
        "秘鲁") echo "PE" ;;
        "委内瑞拉") echo "VE" ;;
        "乌拉圭") echo "UY" ;;
        "巴拉圭") echo "PY" ;;
        "玻利维亚") echo "BO" ;;
        "厄瓜多尔") echo "EC" ;;
        "圭亚那") echo "GY" ;;
        "苏里南") echo "SR" ;;
        "法属圭亚那") echo "GF" ;;
        "墨西哥") echo "MX" ;;
        "危地马拉") echo "GT" ;;
        "伯利兹") echo "BZ" ;;
        "萨尔瓦多") echo "SV" ;;
        "洪都拉斯") echo "HN" ;;
        "尼加拉瓜") echo "NI" ;;
        "哥斯达黎加") echo "CR" ;;
        "巴拿马") echo "PA" ;;
        "古巴") echo "CU" ;;
        "牙买加") echo "JM" ;;
        "海地") echo "HT" ;;
        "多米尼加") echo "DO" ;;
        "波多黎各") echo "PR" ;;
        "特立尼达和多巴哥") echo "TT" ;;
        "巴巴多斯") echo "BB" ;;
        "巴哈马") echo "BS" ;;
        "百慕大") echo "BM" ;;
        "开曼群岛") echo "KY" ;;
        "维尔京群岛") echo "VI" ;;
        "阿鲁巴") echo "AW" ;;
        "荷属安的列斯") echo "AN" ;;
        "安提瓜和巴布达") echo "AG" ;;
        "多米尼克") echo "DM" ;;
        "格林纳达") echo "GD" ;;
        "圣基茨和尼维斯") echo "KN" ;;
        "圣卢西亚") echo "LC" ;;
        "圣文森特和格林纳丁斯") echo "VC" ;;
        "安圭拉") echo "AI" ;;
        "蒙特塞拉特") echo "MS" ;;
        "特克斯和凯科斯群岛") echo "TC" ;;
        "英属维尔京群岛") echo "VG" ;;
        "圣巴泰勒米") echo "BL" ;;
        "圣马丁") echo "MF" ;;
        "瓜德罗普") echo "GP" ;;
        "马提尼克") echo "MQ" ;;
        "圣皮埃尔和密克隆") echo "PM" ;;
        "格陵兰") echo "GL" ;;
        "法罗群岛") echo "FO" ;;
        "冰岛") echo "IS" ;;
        *) echo "" ;;  # 未找到映射，返回空
    esac
}

# 处理单个图片文件
process_image() {
    local image_file="$1"
    local filename=$(basename "$image_file")
    local extension="${filename##*.}"
    local basename="${filename%.*}"
    
    # 移除前缀（如果存在）
    if [[ "$basename" == "$PREFIX"* ]]; then
        basename="${basename#$PREFIX}"
    fi
    
    # 如果是国家类型，尝试将中文名称映射到 ISO 代码
    local imageset_name
    if [ "$BADGE_TYPE" = "country" ]; then
        # 尝试获取 ISO 代码
        local country_code=$(get_country_code "$basename")
        if [ -n "$country_code" ]; then
            # 找到映射，使用 ISO 代码
            imageset_name="${PREFIX}${country_code}"
        else
            # 未找到映射，检查是否是 ISO 代码（2-3个大写字母）
            if [[ "$basename" =~ ^[A-Z]{2,3}$ ]]; then
                # 已经是 ISO 代码
                imageset_name="${PREFIX}${basename}"
            else
                # 使用原始名称（可能是其他格式）
                imageset_name="${PREFIX}${basename}"
            fi
        fi
    else
        # 省份类型，直接使用中文名称
        imageset_name="${PREFIX}${basename}"
    fi
    
    # 构建 imageset 路径
    local imageset_dir="$TARGET_DIR/${imageset_name}.imageset"
    
    # 检查是否已存在
    if [ -d "$imageset_dir" ]; then
        if [ "$FORCE_OVERWRITE" = true ]; then
            echo -e "${YELLOW}  ↻ 覆盖已存在的: $imageset_name${NC}"
            # 删除旧的 imageset 文件夹
            rm -rf "$imageset_dir"
        else
            echo -e "${YELLOW}  ⚠ 跳过已存在的: $imageset_name${NC}"
            ((SKIP_COUNT++))
            return
        fi
    fi
    
    # 创建 imageset 文件夹
    mkdir -p "$imageset_dir"
    
    # 复制图片文件
    local target_image="$imageset_dir/$filename"
    cp "$image_file" "$target_image"
    
    # 生成 Contents.json
    generate_contents_json "$filename" "$imageset_dir"
    
    echo -e "${GREEN}  ✓ 导入成功: $imageset_name${NC}"
    ((SUCCESS_COUNT++))
}

# 遍历源文件夹中的所有图片
echo -e "${BLUE}开始处理图片...${NC}"
echo ""

# 使用 find 命令更可靠地查找所有图片文件
while IFS= read -r -d '' image_file; do
    if [ -f "$image_file" ]; then
        process_image "$image_file"
    fi
done < <(find "$SOURCE_DIR" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) -print0 2>/dev/null)

# 输出统计信息
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}导入完成！${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "成功导入: ${GREEN}$SUCCESS_COUNT${NC} 个"
echo -e "跳过（已存在）: ${YELLOW}$SKIP_COUNT${NC} 个"
echo -e "错误: ${RED}$ERROR_COUNT${NC} 个"
echo ""

# 提示
if [ $SUCCESS_COUNT -gt 0 ]; then
    echo -e "${GREEN}✓ 图片已成功导入到 Assets.xcassets${NC}"
    echo -e "${YELLOW}提示: 请在 Xcode 中刷新 Assets.xcassets 以查看新导入的图片${NC}"
fi

echo ""

