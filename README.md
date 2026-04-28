# Claude 项目配置

可迁移的 Claude Code 项目配置，包含全局和项目级配置、常用插件和初始化脚本。

## 快速开始

```bash
git clone <repo-url> ~/workshop/claude
cd ~/workshop/claude
bash setup.sh
```

## 目录结构

```
.
├── setup.sh           # 初始化脚本（安装）
├── destroy.sh         # 回滚脚本（卸载）
├── global/            # 全局配置和自定义 skill
│   ├── skills/       # 自定义 skill 目录
│   ├── CLAUDE.md
│   └── settings.json
├── project-configs/
│   └── dev/         # dev 类型配置
│       ├── CLAUDE.md
│       └── .claude/
│           └── settings.json
├── .gitignore
└── README.md
```

## 预配置 Skills（15个）

### Global Skills
1. code-review - 代码审查
2. security-guidance - 安全指导
3. code-simplifier - 代码简化
4. skill-creator - 技能创建
5. superpowers - 超级权限
6. commit-commands - Git 提交
7. github - GitHub 集成
8. playwright - 浏览器自动化测试
9. ralph-loop - Ralph Loop
10. typescript-lsp - TypeScript LSP
11. claude-hud - Claude HUD (jarrodwatts)
12. claude-mem - Claude Mem (thedotmack)
13. feature-dev - 功能开发
14. claude-md-management - CLAUDE.md 管理
15. find-skills - 技能查找工具 (npx)

## 使用说明

### 初始化
```bash
bash setup.sh
```
脚本会交互式地询问：
1. 安装范围：global / project / all
2. 项目类型（如选 project）：dev / test
3. 项目目录路径

### 回滚
```bash
bash destroy.sh
```
卸载所有已安装的 skills 和配置，恢复初始状态。

## 新机器迁移
1. `git clone <repo-url> ~/workshop/claude`
2. `cd ~/workshop/claude`
3. `bash setup.sh`
4. 按提示完成配置

## 扩展
- 在 `global/skills/` 添加自定义 skill
- 在 `project-configs/` 下添加新项目类型（test 等）
- 修改 `global/` 和 `project-configs/dev/` 中的配置文件

## 验证
- 运行 `claude` 检查配置加载
- 使用 `/help` 查看可用技能
- 检查 `claude plugin list` 确认 skills 安装
