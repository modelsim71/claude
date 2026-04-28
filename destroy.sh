#!/bin/bash
set -e

echo "=== Claude 项目回滚 ==="
echo "此操作将卸载所有已安装的 skills 和配置"
read -p "确认继续？[y/N]: " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "已取消"; exit 0; }

# 1. 卸载 Global Skills
echo ""
echo "正在卸载 Global Skills..."

uninstall_plugin() {
    local plugin="$1"
    echo "  正在卸载 $plugin..."
    claude plugin uninstall "$plugin" 2>/dev/null && echo "    ✓ 已卸载 $plugin" || echo "    ⚠ 跳过 $plugin（可能未安装）"
}

uninstall_plugin "code-review@claude-plugins-official"
uninstall_plugin "security-guidance@claude-plugins-official"
uninstall_plugin "code-simplifier@claude-plugins-official"
uninstall_plugin "skill-creator@claude-plugins-official"
uninstall_plugin "superpowers@claude-plugins-official"
uninstall_plugin "commit-commands@claude-plugins-official"
uninstall_plugin "github@claude-plugins-official"
uninstall_plugin "playwright@claude-plugins-official"
uninstall_plugin "ralph-loop@claude-plugins-official"
uninstall_plugin "typescript-lsp@claude-plugins-official"
uninstall_plugin "claude-hud"
uninstall_plugin "claude-mem"
uninstall_plugin "feature-dev@claude-plugins-official"
uninstall_plugin "claude-md-management@claude-plugins-official"

# 2. 卸载 marketplace
echo ""
echo "正在移除自定义 marketplace..."
claude plugin marketplace remove jarrodwatts/claude-hud 2>/dev/null && echo "  ✓ 已移除 jarrodwatts/claude-hud" || true
claude plugin marketplace remove thedotmack/claude-mem 2>/dev/null && echo "  ✓ 已移除 thedotmack/claude-mem" || true

# 3. find-skills (npx 安装的)
echo ""
echo "find-skills 通过 npx 运行，无需卸载"
echo "如需移除，请手动删除相关包"

# 4. 恢复配置文件（可选）
echo ""
read -p "是否删除 ~/.claude/CLAUDE.md？[y/N]: " REMOVE_CLAUDE
if [[ "$REMOVE_CLAUDE" =~ ^[Yy]$ ]]; then
    rm -f ~/.claude/CLAUDE.md
    echo "  ✓ 已删除 ~/.claude/CLAUDE.md"
fi

read -p "是否删除 ~/.claude/settings.json？[y/N]: " REMOVE_SETTINGS
if [[ "$REMOVE_SETTINGS" =~ ^[Yy]$ ]]; then
    rm -f ~/.claude/settings.json
    echo "  ✓ 已删除 ~/.claude/settings.json"
fi

# 5. 清理自定义 skills
echo ""
read -p "是否删除 ~/.claude/skills/ 自定义技能？[y/N]: " CLEAN_SKILLS
if [[ "$CLEAN_SKILLS" =~ ^[Yy]$ ]]; then
    rm -rf ~/.claude/skills/ 2>/dev/null || true
    echo "  ✓ 已删除 ~/.claude/skills/"
fi

echo ""
echo "=== 回滚完成 ==="
echo "注意：~/.claude/ 中的其他文件未自动删除"
echo "提示：重新安装请运行 'bash setup.sh'"
