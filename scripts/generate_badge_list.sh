#!/bin/bash

# 生成勋章图片名称列表的脚本
# 用于帮助准备图片文件，生成完整的图片名称列表

set -e

# 颜色输出
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="$PROJECT_ROOT/BadgeImages/image_name_list.txt"

echo -e "${BLUE}生成勋章图片名称列表...${NC}"
echo ""

# 国家列表（基于 CountryManager.Country 枚举）
cat > "$OUTPUT_FILE" << 'EOF'
# 勋章图片名称列表
# 这个文件列出了所有需要的勋章图片名称
# 你可以根据这个列表准备对应的图片文件

========================================
国家勋章图片列表 (CountryBadges)
========================================

命名方式1（推荐）: 使用中文名称
中国.jpg      - 中国
美国.jpg      - 美国
俄罗斯.jpg    - 俄罗斯
日本.jpg      - 日本

命名方式2: 使用 ISO 代码
CN.jpg      - 中国
US.jpg      - 美国
RU.jpg      - 俄罗斯
JP.jpg      - 日本
KR.png      - 韩国
SG.png      - 新加坡
TH.png      - 泰国
MY.png      - 马来西亚
ID.png      - 印度尼西亚
PH.png      - 菲律宾
VN.png      - 越南
IN.png      - 印度
AU.png      - 澳大利亚
NZ.png      - 新西兰
CA.png      - 加拿大
GB.png      - 英国
FR.png      - 法国
DE.png      - 德国
IT.png      - 意大利
ES.png      - 西班牙
NL.png      - 荷兰
CH.png      - 瑞士
AT.png      - 奥地利
BE.png      - 比利时
DK.png      - 丹麦
FI.png      - 芬兰
NO.png      - 挪威
SE.png      - 瑞典
PL.png      - 波兰
CZ.png      - 捷克
HU.png      - 匈牙利
GR.png      - 希腊
PT.png      - 葡萄牙
IE.png      - 爱尔兰
LU.png      - 卢森堡
RU.png      - 俄罗斯
UA.png      - 乌克兰
TR.png      - 土耳其
IL.png      - 以色列
AE.png      - 阿联酋
SA.png      - 沙特阿拉伯
QA.png      - 卡塔尔
KW.png      - 科威特
BH.png      - 巴林
OM.png      - 阿曼
JO.png      - 约旦
LB.png      - 黎巴嫩
EG.png      - 埃及
ZA.png      - 南非
NG.png      - 尼日利亚
KE.png      - 肯尼亚
MA.png      - 摩洛哥
TN.png      - 突尼斯
DZ.png      - 阿尔及利亚
ET.png      - 埃塞俄比亚
GH.png      - 加纳
UG.png      - 乌干达
TZ.png      - 坦桑尼亚
ZW.png      - 津巴布韦
BW.png      - 博茨瓦纳
NA.png      - 纳米比亚
ZM.png      - 赞比亚
MW.png      - 马拉维
MZ.png      - 莫桑比克
MG.png      - 马达加斯加
MU.png      - 毛里求斯
SC.png      - 塞舌尔
BR.png      - 巴西
AR.png      - 阿根廷
CL.png      - 智利
CO.png      - 哥伦比亚
PE.png      - 秘鲁
VE.png      - 委内瑞拉
UY.png      - 乌拉圭
PY.png      - 巴拉圭
BO.png      - 玻利维亚
EC.png      - 厄瓜多尔
GY.png      - 圭亚那
SR.png      - 苏里南
GF.png      - 法属圭亚那
MX.png      - 墨西哥
GT.png      - 危地马拉
BZ.png      - 伯利兹
SV.png      - 萨尔瓦多
HN.png      - 洪都拉斯
NI.png      - 尼加拉瓜
CR.png      - 哥斯达黎加
PA.png      - 巴拿马
CU.png      - 古巴
JM.png      - 牙买加
HT.png      - 海地
DO.png      - 多米尼加
PR.png      - 波多黎各
TT.png      - 特立尼达和多巴哥
BB.png      - 巴巴多斯
BS.png      - 巴哈马
BM.png      - 百慕大
KY.png      - 开曼群岛
VI.png      - 维尔京群岛
AW.png      - 阿鲁巴
AN.png      - 荷属安的列斯
AG.png      - 安提瓜和巴布达
DM.png      - 多米尼克
GD.png      - 格林纳达
KN.png      - 圣基茨和尼维斯
LC.png      - 圣卢西亚
VC.png      - 圣文森特和格林纳丁斯
AI.png      - 安圭拉
MS.png      - 蒙特塞拉特
TC.png      - 特克斯和凯科斯群岛
VG.png      - 英属维尔京群岛
BL.png      - 圣巴泰勒米
MF.png      - 圣马丁
GP.png      - 瓜德罗普
MQ.png      - 马提尼克
PM.png      - 圣皮埃尔和密克隆
GL.png      - 格陵兰
FO.png      - 法罗群岛
IS.png      - 冰岛

命名方式2: 使用完整名称（带前缀）
CountryBadge_CN.png
CountryBadge_US.png
... (以此类推)

========================================
省份勋章图片列表 (ProvinceBadges)
========================================

命名方式（推荐）: 使用省份名称（中文）
北京.jpg
天津.jpg
河北.jpg
山西.jpg
内蒙古.jpg
辽宁.jpg
吉林.jpg
黑龙江.jpg
上海.jpg
江苏.jpg
浙江.jpg
安徽.jpg
福建.jpg
江西.jpg
山东.jpg
河南.jpg
湖北.jpg
湖南.jpg
广东.jpg
广西.jpg
海南.jpg
重庆.jpg
四川.jpg
贵州.jpg
云南.jpg
西藏.jpg
陕西.jpg
甘肃.jpg
青海.jpg
宁夏.jpg
新疆.jpg

命名方式2: 使用完整名称（带前缀）
ProvinceBadge_北京.jpg
ProvinceBadge_上海.jpg
... (以此类推)

========================================
使用说明
========================================

1. 将图片文件放入对应的文件夹：
   - 国家图片 → BadgeImages/Countries/
   - 省份图片 → BadgeImages/Provinces/

2. 运行导入脚本：
   ./scripts/import_badge_images.sh country
   ./scripts/import_badge_images.sh province

3. 在 Xcode 中查看 Assets.xcassets 确认导入成功

EOF

echo -e "${GREEN}✓ 图片名称列表已生成: $OUTPUT_FILE${NC}"
echo ""
echo -e "${YELLOW}提示: 你可以打开这个文件查看所有需要的图片名称${NC}"
echo ""

