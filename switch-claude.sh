#!/bin/bash
#
# Claude 配置切换和启动脚本
# 用法: ./switch-claude.sh [配置名称]
#

set -e

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETTINGS_FILE="$SCRIPT_DIR/settings.json"
API_CONFIGS_FILE="$SCRIPT_DIR/api_configs.json"

# 日志函数
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${BLUE}$1${NC}"
}

# 检查并初始化 API 配置文件
ensure_api_configs_file() {
    if [ ! -f "$API_CONFIGS_FILE" ]; then
        log_info "初始化 API 配置文件..."
        cat > "$API_CONFIGS_FILE" << 'EOF'
{
  "current": "",
  "api_configs": {}
}
EOF
    fi
}

# 获取所有可用配置名称
get_available_configs() {
    ensure_api_configs_file
    if command -v jq >/dev/null 2>&1; then
        jq -r '.api_configs | keys[]' "$API_CONFIGS_FILE" 2>/dev/null || echo ""
    else
        # 不依赖 jq 的解析方法
        grep -o '"[^"]*": {' "$API_CONFIGS_FILE" | sed 's/": {$//' | sed 's/^"//' | grep -v current
    fi
}

# 获取当前配置名称
get_current_config() {
    ensure_api_configs_file
    if command -v jq >/dev/null 2>&1; then
        jq -r '.current' "$API_CONFIGS_FILE" 2>/dev/null || echo ""
    else
        # 不依赖 jq 的解析方法
        grep -o '"current": "[^"]*"' "$API_CONFIGS_FILE" | sed 's/"current": "//' | sed 's/"$//'
    fi
}

# 获取指定配置的信息
get_config_info() {
    local config_name="$1"
    ensure_api_configs_file
    
    if command -v jq >/dev/null 2>&1; then
        local token=$(jq -r ".api_configs[\"$config_name\"].ANTHROPIC_AUTH_TOKEN" "$API_CONFIGS_FILE" 2>/dev/null)
        local base_url=$(jq -r ".api_configs[\"$config_name\"].ANTHROPIC_BASE_URL" "$API_CONFIGS_FILE" 2>/dev/null)
        if [ "$token" != "null" ] && [ "$base_url" != "null" ]; then
            echo "$token|$base_url"
        fi
    else
        # 不依赖 jq 的解析方法
        local config_block=$(sed -n "/\"$config_name\": {/,/}/p" "$API_CONFIGS_FILE")
        local token=$(echo "$config_block" | grep -o '"ANTHROPIC_AUTH_TOKEN": "[^"]*"' | sed 's/.*": "//' | sed 's/"$//')
        local base_url=$(echo "$config_block" | grep -o '"ANTHROPIC_BASE_URL": "[^"]*"' | sed 's/.*": "//' | sed 's/"$//')
        if [ -n "$token" ] && [ -n "$base_url" ]; then
            echo "$token|$base_url"
        fi
    fi
}

# 批量获取所有配置信息 - 性能优化版本
get_all_configs_info() {
    ensure_api_configs_file
    
    if command -v jq >/dev/null 2>&1; then
        # 使用jq一次性解析所有配置信息
        jq -r '
            .current as $current | 
            .api_configs | 
            to_entries[] | 
            "\(.key)|\(.value.ANTHROPIC_AUTH_TOKEN)|\(.value.ANTHROPIC_BASE_URL)|\(if .key == $current then "current" else "-" end)"
        ' "$API_CONFIGS_FILE" 2>/dev/null
    else
        # 不依赖jq的批量解析方法 - 一次读取文件内容
        local json_content=$(cat "$API_CONFIGS_FILE")
        local current_config=$(echo "$json_content" | grep -o '"current": "[^"]*"' | sed 's/"current": "//' | sed 's/"$//')
        
        # 提取所有配置名称
        local config_names=$(echo "$json_content" | grep -o '"[^"]*": {' | sed 's/": {$//' | sed 's/^"//' | grep -v current)
        
        # 为每个配置提取信息
        echo "$config_names" | while IFS= read -r config_name; do
            if [ -n "$config_name" ]; then
                # 提取该配置的完整块
                local config_section=$(echo "$json_content" | sed -n "/\"$config_name\": {/,/}/p")
                local token=$(echo "$config_section" | grep -o '"ANTHROPIC_AUTH_TOKEN": "[^"]*"' | sed 's/.*": "//' | sed 's/"$//')
                local base_url=$(echo "$config_section" | grep -o '"ANTHROPIC_BASE_URL": "[^"]*"' | sed 's/.*": "//' | sed 's/"$//')
                
                if [ -n "$token" ] && [ -n "$base_url" ]; then
                    local status="-"
                    if [ "$config_name" = "$current_config" ]; then
                        status="current"
                    fi
                    echo "$config_name|$token|$base_url|$status"
                fi
            fi
        done
    fi
}

# 设置当前配置
set_current_config() {
    local config_name="$1"
    ensure_api_configs_file
    
    if command -v jq >/dev/null 2>&1; then
        # 使用 jq 更新
        local temp_file=$(mktemp)
        jq ".current = \"$config_name\"" "$API_CONFIGS_FILE" > "$temp_file" && mv "$temp_file" "$API_CONFIGS_FILE"
    else
        # 不依赖 jq 的更新方法
        sed -i.tmp "s/\"current\": \"[^\"]*\"/\"current\": \"$config_name\"/" "$API_CONFIGS_FILE"
        rm -f "${API_CONFIGS_FILE}.tmp"
    fi
}

# 添加或更新 API 配置
add_or_update_api_config() {
    local config_name="$1"
    local auth_token="$2"
    local base_url="$3"
    
    ensure_api_configs_file
    
    if command -v jq >/dev/null 2>&1; then
        # 使用 jq 更新
        local temp_file=$(mktemp)
        jq ".api_configs[\"$config_name\"] = {\"ANTHROPIC_AUTH_TOKEN\": \"$auth_token\", \"ANTHROPIC_BASE_URL\": \"$base_url\"}" "$API_CONFIGS_FILE" > "$temp_file" && mv "$temp_file" "$API_CONFIGS_FILE"
    else
        # 不依赖 jq 的更新方法 - 比较复杂，需要处理 JSON 结构
        # 先检查配置是否已存在
        if grep -q "\"$config_name\": {" "$API_CONFIGS_FILE"; then
            # 更新现有配置
            sed -i.tmp "/\"$config_name\": {/,/}/ {
                s/\"ANTHROPIC_AUTH_TOKEN\": \"[^\"]*\"/\"ANTHROPIC_AUTH_TOKEN\": \"$auth_token\"/
                s/\"ANTHROPIC_BASE_URL\": \"[^\"]*\"/\"ANTHROPIC_BASE_URL\": \"$base_url\"/
            }" "$API_CONFIGS_FILE"
        else
            # 添加新配置 - 在 api_configs 末尾添加
            sed -i.tmp "/\"api_configs\": {/ a\\
    \"$config_name\": {\\
      \"ANTHROPIC_AUTH_TOKEN\": \"$auth_token\",\\
      \"ANTHROPIC_BASE_URL\": \"$base_url\"\\
    }," "$API_CONFIGS_FILE"
        fi
        rm -f "${API_CONFIGS_FILE}.tmp"
    fi
}

# 删除 API 配置
remove_api_config() {
    local config_name="$1"
    
    ensure_api_configs_file
    
    if command -v jq >/dev/null 2>&1; then
        # 使用 jq 删除
        local temp_file=$(mktemp)
        jq "del(.api_configs[\"$config_name\"])" "$API_CONFIGS_FILE" > "$temp_file" && mv "$temp_file" "$API_CONFIGS_FILE"
    else
        # 不依赖 jq 的删除方法
        sed -i.tmp "/\"$config_name\": {/,/},*/d" "$API_CONFIGS_FILE"
        # 清理可能的多余逗号
        sed -i.tmp 's/,\s*}/}/' "$API_CONFIGS_FILE"
        rm -f "${API_CONFIGS_FILE}.tmp"
    fi
}

# 从旧配置目录迁移到新的 API 配置文件
migrate_from_old_configs() {
    local config_dir="$SCRIPT_DIR/config"
    local migrated_count=0
    
    if [ ! -d "$config_dir" ]; then
        return 0
    fi
    
    log_info "检测到旧配置目录，开始迁移..."
    
    for config_file in "$config_dir"/*-settings.json; do
        if [ -f "$config_file" ]; then
            local config_name=$(basename "$config_file" | sed 's/-settings\.json$//')
            local base_url=$(grep -A 10 '"env":' "$config_file" | grep -o '"ANTHROPIC_BASE_URL": "[^"]*"' | sed 's/"ANTHROPIC_BASE_URL": "\([^"]*\)"/\1/')
            local auth_token=$(grep -A 10 '"env":' "$config_file" | grep -o '"ANTHROPIC_AUTH_TOKEN": "[^"]*"' | sed 's/"ANTHROPIC_AUTH_TOKEN": "\([^"]*\)"/\1/')
            
            if [ -n "$base_url" ] && [ -n "$auth_token" ]; then
                # 检查新配置文件中是否已存在此配置
                local existing_config=$(get_config_info "$config_name")
                if [ -z "$existing_config" ]; then
                    add_or_update_api_config "$config_name" "$auth_token" "$base_url"
                    echo "  迁移配置: $config_name"
                    ((migrated_count++))
                fi
            fi
        fi
    done
    
    if [ $migrated_count -gt 0 ]; then
        log_info "成功迁移 $migrated_count 个配置到新格式"
        
        # 尝试设置当前配置
        if [ -f "$SCRIPT_DIR/.current_config" ]; then
            local old_current=$(cat "$SCRIPT_DIR/.current_config")
            set_current_config "$old_current"
            echo "  保持当前配置: $old_current"
            rm -f "$SCRIPT_DIR/.current_config"
        fi
        
        echo ""
        read -p "是否删除旧的配置目录？(y/N): " confirm
        case "$confirm" in
            y|Y|yes|YES)
                rm -rf "$config_dir"
                log_info "旧配置目录已删除"
                ;;
            *)
                log_info "保留旧配置目录"
                ;;
        esac
    else
        log_info "没有找到需要迁移的配置"
    fi
    
    return $migrated_count
}

# 显示帮助信息
show_help() {
    cat << EOF
Claude 配置切换和启动脚本

用法: $0 [选项] [配置名称]

选项:
    -h, --help          显示帮助信息
    -l, --list          列出所有可用配置
    -s, --status        显示当前配置状态
    -c, --current       显示当前使用的配置
    -n, --no-start      只切换配置，不启动 Claude
    -a, --add           添加新配置
    -d, --delete        删除配置
    -m, --migrate       从旧配置目录迁移到新格式

可用配置:
EOF
    
    local available_configs=($(get_available_configs))
    for config in "${available_configs[@]}"; do
        echo "    $config"
    done
    
    cat << EOF

示例:
    $0 \${available_configs[0]}           # 切换配置并启动 Claude
    $0 \${available_configs[1]} --no-start  # 只切换配置
    $0 -l               # 列出所有配置
    $0 -s               # 显示当前状态并启动 Claude
    $0 -a my-config     # 添加名为 my-config 的新配置
    $0 -d my-config     # 删除名为 my-config 的配置

EOF
}

# 列出所有可用配置
list_configs() {
    log_header "=== 可用配置列表 ==="
    
    echo ""
    
    # 打印表格顶部边框
    echo "┌──────────────────────┬──────────┬────────────────────────────────────────────────────┬───────────────────────────┐"
    
    # 打印表格头部（直接匹配边框宽度）
    echo "│ 配置名称             │ 状态     │ Base URL                                           │ Token 预览                │"
    
    # 打印分隔线
    echo "├──────────────────────┼──────────┼────────────────────────────────────────────────────┼───────────────────────────┤"
    
    # 使用优化的批量获取函数 - 一次性获取所有配置信息
    local all_configs_info=$(get_all_configs_info)
    
    if [ -z "$all_configs_info" ]; then
        echo ""
        log_warn "没有找到任何有效的API配置"
        echo "使用 '$0 -a <配置名>' 添加新配置"
        echo ""
        return
    fi
    
    # 处理每行配置信息
    echo "$all_configs_info" | while IFS='|' read -r config_name token base_url status_flag; do
        if [ -n "$config_name" ] && [ -n "$token" ] && [ -n "$base_url" ]; then
            local token_preview=$(echo "$token" | cut -c1-20)
            
            # 设置状态显示
            local status=""
            if [ "$status_flag" = "current" ]; then
                status="当前    "  # "当前"(4宽度) + 4个空格 = 8宽度
            else
                status="-       "  # "-"(1宽度) + 7个空格 = 8宽度
            fi
            
            # 截断过长的 URL
            if [ ${#base_url} -gt 50 ]; then
                base_url="${base_url:0:47}..."
            fi
            
            # 根据是否为当前配置添加颜色并打印
            if [ "$status_flag" = "current" ]; then
                # 当前配置行用绿色突出显示配置名称，黄色显示状态
                printf "│ ${GREEN}%-20s${NC} │ ${YELLOW}%-8s${NC} │ %-50s │ %-25s │\n" "$config_name" "$status" "$base_url" "${token_preview}..."
            else
                # 普通行不加颜色
                printf "│ %-20s │ %-8s │ %-50s │ %-25s │\n" "$config_name" "$status" "$base_url" "${token_preview}..."
            fi
        fi
    done
    
    # 打印表格底部边框
    echo "└──────────────────────┴──────────┴────────────────────────────────────────────────────┴───────────────────────────┘"
    echo ""
}

# 显示当前配置状态
show_status() {
    log_header "=== 当前配置状态 ==="
    
    local current_config_name=$(get_current_config)
    
    if [ -z "$current_config_name" ]; then
        echo ""
        log_warn "当前没有设置任何配置"
        echo "使用 '$0 <配置名>' 切换到指定配置"
        echo ""
        return
    fi
    
    local config_info=$(get_config_info "$current_config_name")
    if [ -n "$config_info" ]; then
        local token=$(echo "$config_info" | cut -d'|' -f1)
        local base_url=$(echo "$config_info" | cut -d'|' -f2)
        local token_preview=$(echo "$token" | cut -c1-20)
        
        echo ""
        echo -e "  当前配置: ${YELLOW}$current_config_name${NC}"
        echo -e "  Base URL: ${GREEN}$base_url${NC}"
        echo -e "  Token:    ${GREEN}${token_preview}...${NC}"
        echo ""
    else
        echo ""
        log_warn "配置 '$current_config_name' 的信息不完整"
        echo ""
    fi
}


# 切换配置
switch_config() {
    local config_name="$1"
    
    # 检查配置是否存在
    local config_info=$(get_config_info "$config_name")
    if [ -z "$config_info" ]; then
        log_error "配置 '$config_name' 不存在"
        echo ""
        log_info "可用的配置:"
        local available_configs=($(get_available_configs))
        for config in "${available_configs[@]}"; do
            echo "  $config"
        done
        exit 1
    fi
    
    # 提取配置信息
    local new_auth_token=$(echo "$config_info" | cut -d'|' -f1)
    local new_base_url=$(echo "$config_info" | cut -d'|' -f2)
    
    # 如果 settings.json 不存在，创建一个基础模板
    if [ ! -f "$SETTINGS_FILE" ]; then
        cat > "$SETTINGS_FILE" << EOF
{
  "env": {
    "ANTHROPIC_AUTH_TOKEN": "",
    "ANTHROPIC_BASE_URL": "",
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
    fi
    
    # 使用 sed 更新特定字段
    # 备份原文件
    cp "$SETTINGS_FILE" "${SETTINGS_FILE}.bak"
    
    # 更新 ANTHROPIC_BASE_URL
    sed -i.tmp 's|\("ANTHROPIC_BASE_URL": "\)[^"]*\(".*\)|\1'"$new_base_url"'\2|' "$SETTINGS_FILE"
    
    # 更新 ANTHROPIC_AUTH_TOKEN  
    sed -i.tmp 's|\("ANTHROPIC_AUTH_TOKEN": "\)[^"]*\(".*\)|\1'"$new_auth_token"'\2|' "$SETTINGS_FILE"
    
    # 清理临时文件
    rm -f "${SETTINGS_FILE}.tmp"
    
    # 更新当前配置记录
    set_current_config "$config_name"
    
    log_info "已切换到配置: $config_name"
    
    # 显示新配置信息
    local new_token_preview=$(echo "$new_auth_token" | cut -c1-20)
    
    echo ""
    echo -e "  新配置信息:"
    echo -e "  Base URL: ${GREEN}$new_base_url${NC}"
    echo -e "  Token:    ${GREEN}$new_token_preview...${NC}"
    echo ""
}

# 启动 Claude
start_claude() {
    log_info "正在启动 Claude..."
    
    # 检查 claude 命令是否存在
    if ! command -v claude >/dev/null 2>&1; then
        log_error "claude 命令未找到，请确保已正确安装 Claude CLI"
        exit 1
    fi
    
    # 启动 Claude
    claude
}

# 添加新配置
add_config() {
    local config_name="$1"
    
    if [ -z "$config_name" ]; then
        echo ""
        read -p "请输入新配置的名称: " config_name
    fi
    
    # 验证配置名称
    if [ -z "$config_name" ]; then
        log_error "配置名称不能为空"
        exit 1
    fi
    
    # 检查配置是否已存在
    local existing_config=$(get_config_info "$config_name")
    if [ -n "$existing_config" ]; then
        log_error "配置 '$config_name' 已存在"
        exit 1
    fi
    
    log_info "正在添加新配置: $config_name"
    echo ""
    
    # 获取用户输入
    read -p "请输入 ANTHROPIC_BASE_URL: " base_url
    if [ -z "$base_url" ]; then
        log_error "ANTHROPIC_BASE_URL 不能为空"
        exit 1
    fi
    
    read -s -p "请输入 ANTHROPIC_AUTH_TOKEN: " auth_token
    echo ""
    if [ -z "$auth_token" ]; then
        log_error "ANTHROPIC_AUTH_TOKEN 不能为空"
        exit 1
    fi
    
    # 添加配置到 API 配置文件
    add_or_update_api_config "$config_name" "$auth_token" "$base_url"
    
    log_info "配置 '$config_name' 已成功添加"
    echo ""
    echo -e "  配置名称: ${GREEN}$config_name${NC}"
    echo -e "  Base URL: ${GREEN}$base_url${NC}"
    echo -e "  Token:    ${GREEN}${auth_token:0:20}...${NC}"
    echo ""
}

# 删除配置
delete_config() {
    local config_name="$1"
    
    if [ -z "$config_name" ]; then
        echo ""
        log_info "可用的配置:"
        local available_configs=($(get_available_configs))
        if [ ${#available_configs[@]} -eq 0 ]; then
            log_warn "没有找到任何配置"
            return
        fi
        for config in "${available_configs[@]}"; do
            echo "  $config"
        done
        echo ""
        read -p "请输入要删除的配置名称: " config_name
    fi
    
    # 验证配置名称
    if [ -z "$config_name" ]; then
        log_error "配置名称不能为空"
        exit 1
    fi
    
    # 检查配置是否存在
    local config_info=$(get_config_info "$config_name")
    if [ -z "$config_info" ]; then
        log_error "配置 '$config_name' 不存在"
        exit 1
    fi
    
    # 获取配置信息用于显示
    local token=$(echo "$config_info" | cut -d'|' -f1)
    local base_url=$(echo "$config_info" | cut -d'|' -f2)
    local token_preview=$(echo "$token" | cut -c1-20)
    
    # 显示要删除的配置信息
    echo ""
    log_warn "即将删除配置: $config_name"
    echo -e "  Base URL: $base_url"
    echo -e "  Token:    ${token_preview}..."
    echo ""
    
    # 确认删除
    read -p "确认删除此配置？(y/N): " confirm
    case "$confirm" in
        y|Y|yes|YES)
            remove_api_config "$config_name"
            
            # 如果删除的是当前配置，清空当前配置
            local current_config=$(get_current_config)
            if [ "$current_config" = "$config_name" ]; then
                set_current_config ""
                log_info "当前配置已重置"
            fi
            
            log_info "配置 '$config_name' 已成功删除"
            ;;
        *)
            log_info "取消删除操作"
            ;;
    esac
    echo ""
}

# 检查 Claude 进程
check_claude_process() {
    if pgrep -f "claude" >/dev/null 2>&1; then
        log_warn "检测到 Claude 进程正在运行"
        echo ""
        read -p "是否要终止现有进程并重新启动？(y/N): " choice
        case "$choice" in
            y|Y|yes|YES)
                log_info "正在终止现有 Claude 进程..."
                pkill -f "claude" 2>/dev/null || true
                sleep 2
                ;;
            *)
                log_info "保持现有进程运行"
                return 1
                ;;
        esac
    fi
    return 0
}

# 主函数
main() {
    local config_name=""
    local no_start=false
    
    # 检查是否需要自动迁移（仅在第一次运行或api_configs.json不存在时）
    if [ -d "$SCRIPT_DIR/config" ] && [ ! -f "$API_CONFIGS_FILE" ]; then
        migrate_from_old_configs
    fi
    
    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -l|--list)
                list_configs
                exit 0
                ;;
            -s|--status)
                log_header "=== Claude 配置切换工具 ==="
                show_status
                if check_claude_process; then
                    start_claude
                fi
                exit 0
                ;;
            -c|--current)
                show_status
                exit 0
                ;;
            -n|--no-start)
                no_start=true
                shift
                ;;
            -a|--add)
                shift
                add_config "$1"
                exit 0
                ;;
            -d|--delete)
                shift
                delete_config "$1"
                exit 0
                ;;
            -m|--migrate)
                migrate_from_old_configs
                exit 0
                ;;
            *)
                # 检查是否是有效的配置名称
                local available_configs=($(get_available_configs))
                local is_valid_config=false
                for valid_config in "${available_configs[@]}"; do
                    if [ "$1" = "$valid_config" ]; then
                        config_name="$1"
                        is_valid_config=true
                        break
                    fi
                done
                
                if [ "$is_valid_config" = false ]; then
                    log_error "未知参数或配置: $1"
                    echo ""
                    log_info "可用的配置:"
                    for config in "${available_configs[@]}"; do
                        echo "  $config"
                    done
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    log_header "=== Claude 配置切换工具 ==="
    
    # 如果没有指定配置名称，显示交互式选择
    if [ -z "$config_name" ]; then
        local available_configs=($(get_available_configs))
        echo ""
        log_info "请选择要切换的配置:"
        echo ""
        
        local i=1
        for config in "${available_configs[@]}"; do
            echo "  $i) $config"
            ((i++))
        done
        echo ""
        read -p "请输入选择 (1-${#available_configs[@]}) 或配置名称: " choice
        
        # 检查是否是数字选择
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#available_configs[@]}" ]; then
            config_name="${available_configs[$((choice-1))]}"
        else
            # 检查是否是有效的配置名称
            local is_valid=false
            for config in "${available_configs[@]}"; do
                if [ "$choice" = "$config" ]; then
                    config_name="$choice"
                    is_valid=true
                    break
                fi
            done
            
            if [ "$is_valid" = false ]; then
                log_error "无效选择"
                exit 1
            fi
        fi
    fi
    
    # 显示当前状态
    show_status
    
    # 切换配置
    switch_config "$config_name"
    
    # 启动 Claude（如果需要）
    if [ "$no_start" = false ]; then
        if check_claude_process; then
            start_claude
        fi
    else
        log_info "配置切换完成，使用 -n 参数，未启动 Claude"
    fi
}

# 运行主函数
main "$@"
