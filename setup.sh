#!/bin/bash
# ensure bash is used to avoid "Bad substitution" error with sh/dash
if [ -z "$BASH_VERSION" ]; then
    exec bash "$0" "$@"
fi
set -e

echo "=== Claude Project Initialization ==="

# get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pre-install: check and install dependencies
preinstall() {
    echo ""
    echo "=== Pre-install: checking dependencies ==="

    command_exists() {
        command -v "$1" &>/dev/null
    }

    # 1. Check Node.js/npm, install via nvm if missing
    if ! command_exists node || ! command_exists npm; then
        echo "  -> Node.js/npm not found, installing via nvm..."
        curl -fsSL https://gitee.com/mirrors/nvm/raw/v0.40.3/install.sh | bash

        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

        nvm install --lts
        nvm use --lts
        echo "  ✓ Node.js $(node --version) installed"
    else
        echo "  ✓ Node.js $(node --version) found"
    fi

    # 2. Check and install claude
    if ! command_exists claude; then
        echo "  -> claude not found, installing..."
        npm install -g @anthropic-ai/claude-code
        echo "  ✓ claude installed"
    else
        echo "  ✓ claude found"
    fi

    # 3. Check and install unzip
    if ! command_exists unzip; then
        echo "  -> unzip not found, installing..."
        sudo apt install -y unzip
        echo "  ✓ unzip installed"
    else
        echo "  ✓ unzip found"
    fi

    # 4. Check and install bun (try curl first, fallback to npm)
    if ! command_exists bun; then
        echo "  -> bun not found, installing..."
        if ! curl -fsSL https://bun.sh/install | bash; then
            echo "  -> curl install failed, trying npm..."
            npm install -g bun
        fi
        echo "  ✓ bun installed"
    else
        echo "  ✓ bun found"
    fi

    echo "=== Pre-install complete ==="
}

# Run pre-install
preinstall

# 1. Scope selection
echo ""
echo "Select install scope:"
echo "  1) global  - install global config and plugins only"
echo "  2) project - install project config and plugins only"
echo "  3) all     - install all"
read -p "Select [1/2/3]: " SCOPE

# 2. Project config (if project or all selected)
PROJECT_TYPE=""
PROJECT_DIR=""
if [[ "$SCOPE" == "2" || "$SCOPE" == "3" ]]; then
    echo ""
    echo "Select project type:"
    echo "  1) dev  - development environment"
    echo "  2) test - test environment"
    read -p "Select [1/2]: " TYPE_CHOICE

    case $TYPE_CHOICE in
        1) PROJECT_TYPE="dev" ;;
        2) PROJECT_TYPE="test" ;;
        *) PROJECT_TYPE="dev" ;;
    esac

    read -p "Enter project directory [default: $(pwd)]: " INPUT_DIR
    PROJECT_DIR="${INPUT_DIR:-$(pwd)}"
fi

# 3. Copy config files
install_global_config() {
    echo ""
    echo "Installing Global config..."

    # ensure target directory exists
    mkdir -p ~/.claude

    # copy CLAUDE.md
    if [[ -f "$SCRIPT_DIR/global/CLAUDE.md" ]]; then
        cp "$SCRIPT_DIR/global/CLAUDE.md" ~/.claude/CLAUDE.md
        echo "  ✓ Copied CLAUDE.md to ~/.claude/"
    fi

    # merge settings.json (preserve user's existing config, especially env)
    if [[ -f "$SCRIPT_DIR/global/settings.json" ]]; then
        # ensure jq is available
        if ! command -v jq &>/dev/null; then
            echo "  -> Installing jq (required for JSON merge)..."
            sudo apt-get install -y jq 2>/dev/null || {
                echo "  ⚠ Cannot install jq, falling back to cp (user env config will be lost)"
                cp "$SCRIPT_DIR/global/settings.json" ~/.claude/settings.json
                echo "  ✓ Copied settings.json to ~/.claude/ (user config NOT preserved)"
                return
            }
        fi

        if [[ ! -f ~/.claude/settings.json ]]; then
            # no existing settings, just copy
            cp "$SCRIPT_DIR/global/settings.json" ~/.claude/settings.json
            echo "  ✓ Copied settings.json to ~/.claude/"
        else
            # merge with jq: user config takes priority, arrays are deduped
            jq -s '
                .[0] as $global | .[1] as $user |
                $global * {
                    permissions: {
                        allow: (($global.permissions.allow // []) + ($user.permissions.allow // []) | unique)
                    },
                    enabledPlugins: ($user.enabledPlugins // {}),
                    extraKnownMarketplaces: ($user.extraKnownMarketplaces // {}),
                    env: ($user.env // $global.env)
                }
            ' "$SCRIPT_DIR/global/settings.json" ~/.claude/settings.json > ~/.claude/settings.json.tmp

            if [[ $? -eq 0 ]]; then
                mv ~/.claude/settings.json.tmp ~/.claude/settings.json
                echo "  ✓ Merged settings.json to ~/.claude/ (user env preserved)"
            else
                rm -f ~/.claude/settings.json.tmp
                cp "$SCRIPT_DIR/global/settings.json" ~/.claude/settings.json
                echo "  ⚠ jq merge failed, overwritten settings.json"
            fi
        fi
    fi

    # copy custom skills
    if [[ -d "$SCRIPT_DIR/global/skills" ]]; then
        mkdir -p ~/.claude/skills
        cp -r "$SCRIPT_DIR/global/skills/"* ~/.claude/skills/ 2>/dev/null || true
        echo "  ✓ Copied custom skills to ~/.claude/skills/"
    fi

    echo "Global config installed"
}

install_project_config() {
    echo ""
    echo "Installing Project config (type: $PROJECT_TYPE)..."
    mkdir -p "$PROJECT_DIR/.claude"

    if [[ -f "$SCRIPT_DIR/project-configs/$PROJECT_TYPE/CLAUDE.md" ]]; then
        cp "$SCRIPT_DIR/project-configs/$PROJECT_TYPE/CLAUDE.md" "$PROJECT_DIR/CLAUDE.md"
        echo "  ✓ Copied CLAUDE.md to $PROJECT_DIR/"
    fi
    if [[ -f "$SCRIPT_DIR/project-configs/$PROJECT_TYPE/.claude/settings.json" ]]; then
        cp "$SCRIPT_DIR/project-configs/$PROJECT_TYPE/.claude/settings.json" "$PROJECT_DIR/.claude/settings.json"
        echo "  ✓ Copied settings.json to $PROJECT_DIR/.claude/"
    fi
    echo "Project config installed"
}

case $SCOPE in
    1) install_global_config ;;
    2) install_project_config ;;
    3) install_global_config; install_project_config ;;
esac

# 4. Install skills
echo ""
echo "=== Installing Skills ==="

# Predefined Global Skills (15)
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

# 4.1 Show preset skills
echo ""
echo "Preset Global Skills (15):"
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

read -p "Install preset skills? [Y/n]: " INSTALL_PRESET
INSTALL_PRESET=${INSTALL_PRESET:-Y}

# 4.1 Ensure official marketplace is available
ensure_official_marketplace() {
    echo ""
    echo "Checking official marketplace..."
    if ! claude plugins marketplace list 2>&1 | grep -q "claude-plugins-official"; then
        echo "  -> Adding claude-plugins-official marketplace..."
        claude plugins marketplace add anthropics/claude-plugins-official 2>&1 && echo "  ✓ Official marketplace added" || echo "  ⚠ Failed to add official marketplace"
    else
        echo "  ✓ Official marketplace already configured"
    fi
}

# 4.2 Plugin install function
install_plugin() {
    local plugin="$1"
    echo "  Installing $plugin..."

    # Special handling for claude-hud
    if [[ "$plugin" == "claude-hud" ]]; then
        claude plugins marketplace add jarrodwatts/claude-hud 2>&1 || true
        claude plugins install claude-hud 2>&1 && echo "    ✓ $plugin" || echo "    ⚠ $plugin skipped (already installed or not found)"
        return
    fi

    # Special handling for claude-mem
    if [[ "$plugin" == "claude-mem" ]]; then
        claude plugins marketplace add thedotmack/claude-mem 2>&1 || true
        claude plugins install claude-mem 2>&1 && echo "    ✓ $plugin" || echo "    ⚠ $plugin skipped (already installed or not found)"
        return
    fi

    # Special handling for find-skills
    if [[ "$plugin" == "find-skills" ]]; then
        npx skills add vercel-labs/skills@find-skills -g -y 2>&1 && echo "    ✓ $plugin" || echo "    ⚠ $plugin skipped"
        return
    fi

    # Regular plugin (official marketplace plugins)
    claude plugins install "$plugin" 2>&1 && echo "    ✓ $plugin" || echo "    ⚠ $plugin skipped (already installed or not found)"
}

# 4.3 Install preset skills
if [[ "$INSTALL_PRESET" =~ ^[Yy]$ ]]; then
    echo ""
    echo "Installing preset Global Skills..."
    ensure_official_marketplace
    for skill in "${GLOBAL_SKILLS[@]}"; do
        (cd ~ && install_plugin "$skill")
    done
fi

# 4.4 Get popular skills, filter preset and installed, interactive selection
echo ""
echo "=== Popular Skills (top 15) ==="

if [[ ! -f ~/.claude/plugins/install-counts-cache.json ]]; then
    echo "  (install-counts-cache.json not found, skipping popular list)"
else
    # Get installed plugins list
    installed_plugins=""
    if command -v claude &>/dev/null; then
        installed_plugins=$(claude plugin list 2>/dev/null | grep -E '^[a-zA-Z0-9@._-]+$' || true)
    fi

    # Build available list (filter preset + installed)
    AVAILABLE_POPULAR=()
    while IFS= read -r plugin; do
        [[ -z "$plugin" ]] && continue
        plugin_name=$(echo "$plugin" | cut -d'@' -f1)

        # Check if preset
        is_preset=false
        for preset in "${GLOBAL_SKILLS[@]}"; do
            preset_name=$(echo "$preset" | cut -d'@' -f1)
            if [[ "$plugin_name" == "$preset_name" ]]; then
                is_preset=true
                break
            fi
        done
        [[ "$is_preset" == "true" ]] && continue

        # Check if already installed
        if echo "$installed_plugins" | grep -q "^${plugin}$"; then
            continue
        fi

        AVAILABLE_POPULAR+=("$plugin")
    done < <(jq -r '.counts[:15] | .[] | .plugin' ~/.claude/plugins/install-counts-cache.json 2>/dev/null)

    if [[ ${#AVAILABLE_POPULAR[@]} -eq 0 ]]; then
        echo "  No popular skills available (all installed or preset)"
    else
        echo "Available popular skills (filtered: preset and installed excluded):"
        for i in "${!AVAILABLE_POPULAR[@]}"; do
            p="${AVAILABLE_POPULAR[$i]}"
            installs=$(jq -r --arg x "$p" '.counts[] | select(.plugin == $x) | .unique_installs' ~/.claude/plugins/install-counts-cache.json 2>/dev/null)
            printf "  %2d) %s - %s installs\n" "$((i+1))" "$p" "$installs"
        done

        echo ""
        echo "Select skills to install (multiple selections allowed):"
        echo "  - Enter a single number: 1"
        echo "  - Enter multiple numbers separated by commas: 1,3,5"
        echo "  - Enter 'all' to install all"
        echo "  - Enter 'skip' to skip"
        read -p "Select: " POPULAR_CHOICE

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
                        echo "  ⚠ Invalid selection: $c"
                    fi
                done
            fi

            if [[ ${#to_install[@]} -gt 0 ]]; then
                echo ""
                echo "Installing selected skills..."
                ensure_official_marketplace
                for plugin in "${to_install[@]}"; do
                    (cd ~ && install_plugin "$plugin")
                done
            fi
        fi
    fi
fi

echo ""
echo "=== Initialization complete ==="
echo ""
echo "Tips:"
echo "  - Run 'claude' to start Claude Code"
echo "  - Use '/help' to view available skills"
echo "  - To rollback, run 'bash destroy.sh'"
