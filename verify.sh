#!/bin/bash

# ClaudeBar 验证脚本
# 用于验证项目结构和代码正确性

set -e

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="ClaudeBar"

echo "🔍 验证 $PROJECT_NAME 项目..."

# 检查项目结构
echo "📁 检查项目结构..."

required_files=(
    "$PROJECT_NAME.xcodeproj/project.pbxproj"
    "$PROJECT_NAME/App/ClaudeBarApp.swift"
    "$PROJECT_NAME/App/AppDelegate.swift"
    "$PROJECT_NAME/Core/Models/ClaudeConfig.swift"
    "$PROJECT_NAME/Core/Models/UsageEntry.swift"
    "$PROJECT_NAME/Core/Models/UsageStatistics.swift"
    "$PROJECT_NAME/Core/Models/PricingModel.swift"
    "$PROJECT_NAME/Core/Services/ConfigService.swift"
    "$PROJECT_NAME/Core/Services/KeychainService.swift"
    "$PROJECT_NAME/Core/Services/ProcessService.swift"
    "$PROJECT_NAME/Core/Services/UsageService.swift"
    "$PROJECT_NAME/Core/Services/JSONLParser.swift"
    "$PROJECT_NAME/Features/MenuBar/StatusItemManager.swift"
    "$PROJECT_NAME/Features/MenuBar/MenuBarView.swift"
    "$PROJECT_NAME/Features/MenuBar/MenuBarViewModel.swift"
    "$PROJECT_NAME/Features/ContentView.swift"
    "$PROJECT_NAME/Features/Pages/UsageStatisticsView.swift"
    "$PROJECT_NAME/Features/Components/TimelineChart.swift"
    "$PROJECT_NAME/$PROJECT_NAME.entitlements"
)

missing_files=()
for file in "${required_files[@]}"; do
    if [ ! -f "$PROJECT_DIR/$file" ]; then
        missing_files+=("$file")
    fi
done

if [ ${#missing_files[@]} -eq 0 ]; then
    echo "✅ 所有必需文件都存在"
else
    echo "❌ 缺少以下文件:"
    for file in "${missing_files[@]}"; do
        echo "   - $file"
    done
    exit 1
fi

# 检查 Swift 语法（如果有 swiftc）
if command -v swiftc &> /dev/null; then
    echo "🔍 检查 Swift 语法..."
    
    swift_files=(
        "$PROJECT_NAME/App/ClaudeBarApp.swift"
        "$PROJECT_NAME/Core/Models/ClaudeConfig.swift"
        "$PROJECT_NAME/Core/Models/UsageEntry.swift"
        "$PROJECT_NAME/Core/Models/PricingModel.swift"
        "$PROJECT_NAME/Core/Services/ConfigService.swift"
        "$PROJECT_NAME/Core/Services/UsageService.swift"
        "$PROJECT_NAME/Core/Services/JSONLParser.swift"
    )
    
    for file in "${swift_files[@]}"; do
        echo "   检查 $file..."
        if ! swiftc -parse "$PROJECT_DIR/$file" &> /dev/null; then
            echo "❌ $file 语法错误"
            exit 1
        fi
    done
    
    echo "✅ Swift 语法检查通过"
else
    echo "⚠️  未找到 swiftc，跳过语法检查"
fi

# 创建测试配置文件
echo "🧪 创建测试配置..."

test_config_dir="$HOME/.claude"
test_config_file="$test_config_dir/test-settings.json"

mkdir -p "$test_config_dir"

cat > "$test_config_file" << 'EOF'
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.anthropic.com",
    "CLAUDE_CODE_MAX_OUTPUT_TOKENS": "32000",
    "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"
  },
  "permissions": {
    "allow": [],
    "deny": []
  },
  "cleanupPeriodDays": 365,
  "includeCoAuthoredBy": false
}
EOF

echo "⚠️  注意: 测试配置不包含 ANTHROPIC_AUTH_TOKEN，需要手动添加"

echo "✅ 测试配置文件已创建: $test_config_file"

# 检查配置目录
echo "📂 检查 Claude 配置目录..."
if [ -d "$test_config_dir" ]; then
    config_files=$(ls "$test_config_dir"/*-settings.json 2>/dev/null | wc -l)
    echo "   找到 $config_files 个配置文件"
    
    if [ $config_files -gt 0 ]; then
        echo "   配置文件列表:"
        for file in "$test_config_dir"/*-settings.json; do
            if [ -f "$file" ]; then
                basename=$(basename "$file" -settings.json)
                echo "     - $basename"
            fi
        done
    fi
else
    echo "   配置目录不存在，已创建"
fi

# 项目统计
echo ""
echo "📊 项目统计:"
echo "   Swift 文件数量: $(find "$PROJECT_DIR/$PROJECT_NAME" -name "*.swift" | wc -l)"
echo "   总代码行数: $(find "$PROJECT_DIR/$PROJECT_NAME" -name "*.swift" -exec wc -l {} + | tail -1 | awk '{print $1}')"
echo "   项目大小: $(du -sh "$PROJECT_DIR" | cut -f1)"

echo ""
echo "🎯 验证完成!"
echo ""
echo "💡 下一步操作:"
echo "1. 如果有 Xcode，可以双击 $PROJECT_NAME.xcodeproj 打开项目"
echo "2. 在 Xcode 中按 Cmd+R 运行项目"
echo "3. 运行后查看菜单栏是否出现 ClaudeBar 图标"
echo "4. 点击图标查看 Claude 使用统计"
echo ""
echo "🔧 手动测试步骤:"
echo "1. 确保 ~/.claude 目录中有使用数据的 JSONL 文件"
echo "2. 在 Keychain Access 中添加 ANTHROPIC_AUTH_TOKEN"
echo "3. 运行应用，检查菜单栏图标"
echo "4. 点击图标，查看 token 使用统计"
echo "5. 验证统计数据与 ccusage 工具的结果一致"
echo ""
echo "📊 Token 统计功能:"
echo "1. 支持按日期、模型、项目查看统计"
echo "2. 显示输入/输出/缓存 tokens 使用情况"
echo "3. 计算准确的使用成本"
echo "4. 提供时间线图表展示"