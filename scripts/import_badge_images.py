#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
批量导入勋章图片到 Assets.xcassets 的 Python 脚本
支持更详细的错误处理和进度显示

使用方法:
    python3 import_badge_images.py [country|province]
"""

import os
import sys
import json
import shutil
from pathlib import Path

# 颜色输出（ANSI 转义码）
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'  # No Color

def print_colored(text, color=Colors.NC):
    """打印带颜色的文本"""
    print(f"{color}{text}{Colors.NC}")

def get_script_dir():
    """获取脚本所在目录"""
    return Path(__file__).parent.absolute()

def get_project_root():
    """获取项目根目录"""
    return get_script_dir().parent

def generate_contents_json(image_filename):
    """生成 Contents.json 内容"""
    return {
        "images": [
            {
                "filename": image_filename,
                "idiom": "universal",
                "scale": "1x"
            }
        ],
        "info": {
            "author": "xcode",
            "version": 1
        }
    }

# 国家中文名称到 ISO 代码的映射（基于 CountryManager）
COUNTRY_NAME_MAP = {
    "中国": "CN", "美国": "US", "日本": "JP", "韩国": "KR", "新加坡": "SG",
    "泰国": "TH", "马来西亚": "MY", "印度尼西亚": "ID", "菲律宾": "PH", "越南": "VN",
    "印度": "IN", "澳大利亚": "AU", "新西兰": "NZ", "加拿大": "CA", "英国": "GB",
    "法国": "FR", "德国": "DE", "意大利": "IT", "西班牙": "ES", "荷兰": "NL",
    "瑞士": "CH", "奥地利": "AT", "比利时": "BE", "丹麦": "DK", "芬兰": "FI",
    "挪威": "NO", "瑞典": "SE", "波兰": "PL", "捷克": "CZ", "匈牙利": "HU",
    "希腊": "GR", "葡萄牙": "PT", "爱尔兰": "IE", "卢森堡": "LU", "俄罗斯": "RU",
    "乌克兰": "UA", "土耳其": "TR", "以色列": "IL", "阿联酋": "AE", "沙特阿拉伯": "SA",
    "卡塔尔": "QA", "科威特": "KW", "巴林": "BH", "阿曼": "OM", "约旦": "JO",
    "黎巴嫩": "LB", "埃及": "EG", "南非": "ZA", "尼日利亚": "NG", "肯尼亚": "KE",
    "摩洛哥": "MA", "突尼斯": "TN", "阿尔及利亚": "DZ", "埃塞俄比亚": "ET", "加纳": "GH",
    "乌干达": "UG", "坦桑尼亚": "TZ", "津巴布韦": "ZW", "博茨瓦纳": "BW", "纳米比亚": "NA",
    "赞比亚": "ZM", "马拉维": "MW", "莫桑比克": "MZ", "马达加斯加": "MG", "毛里求斯": "MU",
    "塞舌尔": "SC", "巴西": "BR", "阿根廷": "AR", "智利": "CL", "哥伦比亚": "CO",
    "秘鲁": "PE", "委内瑞拉": "VE", "乌拉圭": "UY", "巴拉圭": "PY", "玻利维亚": "BO",
    "厄瓜多尔": "EC", "圭亚那": "GY", "苏里南": "SR", "法属圭亚那": "GF", "墨西哥": "MX",
    "危地马拉": "GT", "伯利兹": "BZ", "萨尔瓦多": "SV", "洪都拉斯": "HN", "尼加拉瓜": "NI",
    "哥斯达黎加": "CR", "巴拿马": "PA", "古巴": "CU", "牙买加": "JM", "海地": "HT",
    "多米尼加": "DO", "波多黎各": "PR", "特立尼达和多巴哥": "TT", "巴巴多斯": "BB", "巴哈马": "BS",
    "百慕大": "BM", "开曼群岛": "KY", "维尔京群岛": "VI", "阿鲁巴": "AW", "荷属安的列斯": "AN",
    "安提瓜和巴布达": "AG", "多米尼克": "DM", "格林纳达": "GD", "圣基茨和尼维斯": "KN", "圣卢西亚": "LC",
    "圣文森特和格林纳丁斯": "VC", "安圭拉": "AI", "蒙特塞拉特": "MS", "特克斯和凯科斯群岛": "TC",
    "英属维尔京群岛": "VG", "圣巴泰勒米": "BL", "圣马丁": "MF", "瓜德罗普": "GP", "马提尼克": "MQ",
    "圣皮埃尔和密克隆": "PM", "格陵兰": "GL", "法罗群岛": "FO", "冰岛": "IS"
}

def normalize_name(basename, prefix, badge_type="country"):
    """标准化名称（移除前缀，国家类型时映射中文名称到 ISO 代码）"""
    # 移除前缀
    if basename.startswith(prefix):
        basename = basename[len(prefix):]
    
    # 如果是国家类型，尝试将中文名称映射到 ISO 代码
    if badge_type == "country":
        # 检查是否是中文名称
        if basename in COUNTRY_NAME_MAP:
            return COUNTRY_NAME_MAP[basename]
        # 检查是否已经是 ISO 代码（2-3个大写字母）
        elif basename.isupper() and 2 <= len(basename) <= 3:
            return basename
        # 其他情况，返回原名称
        else:
            return basename
    
    # 省份类型，直接返回原名称
    return basename

def process_image(image_path, target_dir, prefix, stats, badge_type="country", force_overwrite=False):
    """处理单个图片文件"""
    image_path = Path(image_path)
    filename = image_path.name
    basename = image_path.stem
    extension = image_path.suffix[1:]  # 移除点号
    
    # 支持的格式
    supported_formats = ['png', 'jpg', 'jpeg', 'PNG', 'JPG', 'JPEG']
    if extension.lower() not in [f.lower() for f in supported_formats]:
        print_colored(f"  ⚠ 跳过不支持的格式: {filename}", Colors.YELLOW)
        stats['skip'] += 1
        return False
    
    # 标准化名称（支持中文名称映射）
    normalized_name = normalize_name(basename, prefix, badge_type)
    imageset_name = f"{prefix}{normalized_name}"
    imageset_dir = target_dir / f"{imageset_name}.imageset"
    
    # 检查是否已存在
    if imageset_dir.exists():
        if force_overwrite:
            print_colored(f"  ↻ 覆盖已存在的: {imageset_name}", Colors.YELLOW)
            # 删除旧的 imageset 文件夹
            shutil.rmtree(imageset_dir)
        else:
            print_colored(f"  ⚠ 跳过已存在的: {imageset_name}", Colors.YELLOW)
            stats['skip'] += 1
            return False
    
    try:
        # 创建 imageset 文件夹
        imageset_dir.mkdir(parents=True, exist_ok=True)
        
        # 复制图片文件
        target_image = imageset_dir / filename
        shutil.copy2(image_path, target_image)
        
        # 生成 Contents.json
        contents_json = generate_contents_json(filename)
        contents_file = imageset_dir / "Contents.json"
        with open(contents_file, 'w', encoding='utf-8') as f:
            json.dump(contents_json, f, indent=2, ensure_ascii=False)
        
        print_colored(f"  ✓ 导入成功: {imageset_name}", Colors.GREEN)
        stats['success'] += 1
        return True
        
    except Exception as e:
        print_colored(f"  ✗ 导入失败: {imageset_name} - {str(e)}", Colors.RED)
        stats['error'] += 1
        return False

def main():
    """主函数"""
    # 获取参数
    badge_type = sys.argv[1] if len(sys.argv) > 1 else "country"
    force_overwrite = "--force" in sys.argv or "-f" in sys.argv
    
    if badge_type not in ["country", "province"]:
        print_colored("错误: 参数必须是 'country' 或 'province'", Colors.RED)
        sys.exit(1)
    
    # 配置路径
    script_dir = get_script_dir()
    project_root = get_project_root()
    badge_images_dir = project_root / "BadgeImages"
    assets_dir = project_root / "Footprint" / "Assets.xcassets"
    
    # 根据类型设置路径
    if badge_type == "province":
        target_dir = assets_dir / "ProvinceBadges"
        prefix = "ProvinceBadge_"
        source_dir = badge_images_dir / "Provinces"
        type_name = "省份"
    else:
        target_dir = assets_dir / "CountryBadges"
        prefix = "CountryBadge_"
        source_dir = badge_images_dir / "Countries"
        type_name = "国家"
    
    # 打印标题
    print_colored("=" * 40, Colors.BLUE)
    print_colored(f"批量导入{type_name}勋章图片", Colors.BLUE)
    print_colored("=" * 40, Colors.BLUE)
    print()
    
    # 检查源文件夹
    if not source_dir.exists():
        print_colored(f"错误: 源文件夹不存在: {source_dir}", Colors.RED)
        print_colored("请创建文件夹并放入图片文件", Colors.YELLOW)
        print()
        print("文件夹结构应该是:")
        print(f"  BadgeImages/")
        if badge_type == "province":
            print(f"    Provinces/")
            print(f"      北京.png")
            print(f"      上海.png")
        else:
            print(f"    Countries/")
            print(f"      CN.png")
            print(f"      US.png")
        sys.exit(1)
    
    # 创建目标文件夹
    target_dir.mkdir(parents=True, exist_ok=True)
    print_colored(f"✓ 目标文件夹已准备: {target_dir}", Colors.GREEN)
    
    # 统计
    stats = {'success': 0, 'skip': 0, 'error': 0}
    
    # 查找所有图片文件
    supported_extensions = ['.png', '.jpg', '.jpeg', '.PNG', '.JPG', '.JPEG']
    image_files = []
    for ext in supported_extensions:
        image_files.extend(source_dir.glob(f"*{ext}"))
    
    if not image_files:
        print_colored(f"警告: 在 {source_dir} 中未找到图片文件", Colors.YELLOW)
        print_colored("支持的格式: PNG, JPG, JPEG", Colors.YELLOW)
        sys.exit(0)
    
    print_colored(f"找到 {len(image_files)} 个图片文件", Colors.CYAN)
    print_colored("开始处理图片...", Colors.BLUE)
    print()
    
    # 处理每个图片
    for image_file in sorted(image_files):
        process_image(image_file, target_dir, prefix, stats, badge_type, force_overwrite)
    
    # 输出统计
    print()
    print_colored("=" * 40, Colors.BLUE)
    print_colored("导入完成！", Colors.GREEN)
    print_colored("=" * 40, Colors.BLUE)
    print_colored(f"成功导入: {Colors.GREEN}{stats['success']}{Colors.NC} 个")
    print_colored(f"跳过（已存在）: {Colors.YELLOW}{stats['skip']}{Colors.NC} 个")
    print_colored(f"错误: {Colors.RED}{stats['error']}{Colors.NC} 个")
    print()
    
    if stats['success'] > 0:
        print_colored("✓ 图片已成功导入到 Assets.xcassets", Colors.GREEN)
        print_colored("提示: 请在 Xcode 中刷新 Assets.xcassets 以查看新导入的图片", Colors.YELLOW)
    
    print()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print_colored("\n\n操作已取消", Colors.YELLOW)
        sys.exit(1)
    except Exception as e:
        print_colored(f"\n\n发生错误: {str(e)}", Colors.RED)
        import traceback
        traceback.print_exc()
        sys.exit(1)

