#!/bin/bash
# 确保用 bash 运行，避免 sh/dash 执行时报 Bad substitution
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi
set -e

echo "=== Claude 项目初始化 ==="

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. 选择安装范围
echo ""
echo "请选择安装范围："
echo "  1) global  - 只安装全局配置和插件"
echo "  2) project - 只安装项目配置和插件"
echo "  3) all     - 全部安装"
read -p "请选择 [1/2/3]: " SCOPE

# 2. 项目配置（如果选了 project 或 all）
PROJECT_TYPE=""
PROJECT_DIR=""
if [[ "$SCOPE" == "2" || "$SCOPE" == "3" ]]; then
    echo ""
    echo "请选择项目类型："
    echo "  1) dev  - 开发环境"
    echo "  2) test - 测试环境（暂不细化）"
    read -p "请选择 [1/2]: " TYPE_CHOICE

    case $TYPE_CHOICE in
        1) PROJECT_TYPE="dev" ;;
        2) PROJECT_TYPE="test" ;;
        *) PROJECT_TYPE="dev" ;;
    esac

    read -p "请输入项目目录路径 [默认: $(pwd)]: " INPUT_DIR
    PROJECT_DIR="${INPUT_DIR:-$(pwd)}"
fi

# 3. 复制配置文件
install_global_config() {
    echo ""
    echo "正在安装 Global 配置..."
    if [[ -f "$SCRIPT_DIR/global/CLAUDE.md" ]]; then
        cp "$SCRIPT_DIR/global/CLAUDE.md" ~/.claude/CLAUDE.md
        echo "  ✓ 已复制 CLAUDE.md 到 ~/.claude/"
    fi
    if [[ -f "$SCRIPT_DIR/global/settings.json" ]]; then
        cp "$SCRIPT_DIR/global/settings.json" ~/.claude/settings.json
        echo "  ✓ 已复制 settings.json 到 ~/.claude/"
    fi
    if [[ -d "$SCRIPT_DIR/global/skills" ]]; then
        mkdir -p ~/.claude/skills
        cp -r "$SCRIPT_DIR/global/skills/"* ~/.claude/skills/ 2>/dev/null || true
        echo "  ✓ 已复制自定义 skills 到 ~/.claude/skills/"
    fi
    echo "Global 配置安装完成"
}

install_project_config() {
    echo ""
    echo "正在安装 Project 配置（类型: $PROJECT_TYPE）..."
    mkdir -p "$PROJECT_DIR/.claude"

    if [[ -f "$SCRIPT_DIR/project-configs/$PROJECT_TYPE/CLAUDE.md" ]]; then
        cp "$SCRIPT_DIR/project-configs/$PROJECT_TYPE/CLAUDE.md" "$PROJECT_DIR/CLAUDE.md"
        echo "  ✓ 已复制 CLAUDE.md 到 $PROJECT_DIR/"
    fi
    if [[ -f "$SCRIPT_DIR/project-configs/$PROJECT_TYPE/.claude/settings.json" ]]; then
        cp "$SCRIPT_DIR/project-configs/$PROJECT_TYPE/.claude/settings.json" "$PROJECT_DIR/.claude/settings.json"
        echo "  ✓ 已复制 settings.json 到 $PROJECT_DIR/.claude/"
    fi
    echo "Project 配置安装完成"
}

case $SCOPE in
    1) install_global_config ;;
    2) install_project_config ;;
    3) install_global_config; install_project_config ;;
esac

# 4. 安装 skills
echo ""
echo "=== 安装 Skills ==="

# 预定义的 Global Skills（15个）
GLOBAL_SKILLS=(
    "code-review@claude-plugins-official"
    "security-guidance@claude-plugins-official"
    "code-simplifier@claude-plugins-official"
    "skill-creator@claude-plugins-official"
    "superpowers@claude-plugins-official"
    "commit-commands@claude-plugins-official"
    "github@claude-plugins-official"
    "playwright@claude-plugins-official"
    "ralph-loop@claude-plugins-official"
    "typescript-lsp@claude-plugins-official"
    "claude-hud"
    "claude-mem"
    "feature-dev@claude-plugins-official"
    "claude-md-management@claude-plugins-official"
)

# 4.1 显示预配置的 skills
echo ""
echo "预配置的 Global Skills（15个）："
echo "  1) code-review"
echo "  2) security-guidance"
echo "  3) code-simplifier"
echo "  4) skill-creator"
echo "  5) superpowers"
echo "  6) commit-commands"
echo "  7) github"
echo "  8) playwright"
echo "  9) ralph-loop"
echo "  10) typescript-lsp"
echo "  11) claude-hud (jarrodwatts)"
echo "  12) claude-mem (thedotmack)"
echo "  13) feature-dev"
echo "  14) claude-md-management"
echo "  15) find-skills (npx)"

read -p "是否安装预配置的 skills？[Y/n]: " INSTALL_PRESET
INSTALL_PRESET=${INSTALL_PRESET:-Y}

# 4.2 安装函数
install_plugin() {
    local plugin="$1"
    echo "  正在安装 $plugin..."

    # 特殊处理 claude-hud
    if [[ "$plugin" == "claude-hud" ]]; then
        claude plugin marketplace add jarrodwatts/claude-hud 2>/dev/null || true
        claude plugin install claude-hud 2>/dev/null && echo "    ✓ $plugin" || echo "    ⚠ 跳过 $plugin（可能已安装或不存在）"
        return
    fi

    # 特殊处理 claude-mem
    if [[ "$plugin" == "claude-mem" ]]; then
        claude plugin marketplace add thedotmack/claude-mem 2>/dev/null || true
        claude plugin install claude-mem 2>/dev/null && echo "    ✓ $plugin" || echo "    ⚠ 跳过 $plugin（可能已安装或不存在）"
        return
    fi

    # 特殊处理 find-skills
    if [[ "$plugin" == "find-skills" ]]; then
        npx skills add vercel-labs/skills@find-skills -g -y 2>/dev/null && echo "    ✓ $plugin" || echo "    ⚠ 跳过 $plugin"
        return
    fi

    # 普通插件
    claude plugin install "$plugin" 2>/dev/null && echo "    ✓ $plugin" || echo "    ⚠ 跳过 $plugin（可能已安装或不存在）"
}

# 4.3 安装预配置 skills
if [[ "$INSTALL_PRESET" =~ ^[Yy]$ ]]; then
    echo ""
    echo "正在安装预配置的 Global Skills..."
    for skill in "${GLOBAL_SKILLS[@]}"; do
        (cd ~ && install_plugin "$skill")
    done
fi

# 4.4 获取热门 skills，过滤已预配置和已安装的，交互式选择
echo ""
echo "=== 热门 Skills（前 15 个）==="

if [[ ! -f ~/.claude/plugins/install-counts-cache.json ]]; then
    echo "  (install-counts-cache.json 不存在，跳过热门列表)"
else
    # 获取已安装的插件列表
    installed_plugins=""
    if command -v claude &>/dev/null; then
        installed_plugins=$(claude plugin list 2>/dev/null | grep -E '^[a-zA-Z0-9@._-]+$' || true)
    fi

    # 构建可选列表（过滤预配置 + 已安装）
    AVAILABLE_POPULAR=()
    while IFS= read -r plugin; do
        [[ -z "$plugin" ]] && continue
        plugin_name=$(echo "$plugin" | cut -d'@' -f1)

        # 检查是否预配置
        is_preset=false
        for preset in "${GLOBAL_SKILLS[@]}"; do
            preset_name=$(echo "$preset" | cut -d'@' -f1)
            if [[ "$plugin_name" == "$preset_name" ]]; then
                is_preset=true
                break
            fi
        done
        [[ "$is_preset" == "true" ]] && continue

        # 检查是否已安装
        if echo "$installed_plugins" | grep -q "^${plugin}$"; then
            continue
        fi

        AVAILABLE_POPULAR+=("$plugin")
    done < <(jq -r '.counts[:15] | .[] | .plugin' ~/.claude/plugins/install-counts-cache.json 2>/dev/null)

    if [[ ${#AVAILABLE_POPULAR[@]} -eq 0 ]]; then
        echo "  没有可安装的热门 Skills（已全部安装或预配置）"
    else
        echo "可安装的热门 Skills（已过滤预配置和已安装的）："
        for i in "${!AVAILABLE_POPULAR[@]}"; do
            p="${AVAILABLE_POPULAR[$i]}"
            installs=$(jq -r --arg x "$p" '.counts[] | select(.plugin == $x) | .unique_installs' ~/.claude/plugins/install-counts-cache.json 2>/dev/null)
            printf "  %2d) %s - %s 次安装\n" "$((i+1))" "$p" "$installs"
        done

        echo ""
        echo "请选择要安装的（可多选）："
        echo "  - 输入编号安装单个，如: 1"
        echo "  - 输入多个编号用逗号分隔，如: 1,3,5"
        echo "  - 输入 'all' 安装全部"
        echo "  - 输入 'skip' 跳过"
        read -p "请选择: " POPULAR_CHOICE

        if [[ "$POPULAR_CHOICE" != "skip" && -n "$POPULAR_CHOICE" ]]; then
            to_install=()
            if [[ "$POPULAR_CHOICE" == "all" ]]; then
                to_install=("${AVAILABLE_POPULAR[@]}")
            else
                IFS=',' read -ra CHOICES <<< "$POPULAR_CHOICE"
                for c in "${CHOICES[@]}"; do
                    c=$(echo "$c" | tr -d ' ')
                    if [[ "$c" =~ ^[0-9]+$ ]] && [[ "$c" -ge 1 ]] && [[ "$c" -le ${#AVAILABLE_POPULAR[@]} ]]; then
                        to_install+=("${AVAILABLE_POPULAR[$((c-1))]}")
                    else
                        echo "  ⚠ 忽略无效选择: $c"
                    fi
                done
            fi

            if [[ ${#to_install[@]} -gt 0 ]]; then
                echo ""
                echo "正在安装选中的 Skills..."
                for plugin in "${to_install[@]}"; do
                    (cd ~ && install_plugin "$plugin")
                done
            fi
        fi
    fi
fi

echo ""
echo "=== 初始化完成 ==="
echo ""
echo "提示："
echo "  - 运行 'claude' 启动 Claude Code"
echo "  - 使用 '/help' 查看可用技能"
echo "  - 如需回滚，请运行 'bash destroy.sh'"
