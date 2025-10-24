#!/bin/bash

# 测试版本记录功能

echo "🧪 测试版本记录功能..."
echo ""

# 测试快速版本记录
echo "1. 测试快速版本记录脚本..."
./scripts/quick_version.sh

echo ""
echo "2. 检查版本记录文件..."
if [ -f "版本记录.md" ]; then
    echo "✅ 版本记录文件存在"
    echo "📄 文件内容预览:"
    head -n 20 "版本记录.md"
else
    echo "❌ 版本记录文件不存在"
fi

echo ""
echo "3. 检查脚本权限..."
ls -la scripts/*.sh

echo ""
echo "✅ 测试完成！"
echo "📝 现在可以编辑 版本记录.md 添加具体更新内容"
