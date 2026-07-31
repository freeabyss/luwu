#!/usr/bin/env bash
# 陆吾 Luwu - 个人开发流程插件一键安装脚本
#
# 用法:
#   bash <(curl -fsSL https://raw.githubusercontent.com/freeabyss/luwu/main/install.sh)          # 安装全部已检测到的平台
#   bash <(curl -fsSL https://raw.githubusercontent.com/freeabyss/luwu/main/install.sh) update   # 更新
#   bash <(curl -fsSL https://raw.githubusercontent.com/freeabyss/luwu/main/install.sh) uninstall # 卸载
#   bash <(curl -fsSL https://raw.githubusercontent.com/freeabyss/luwu/main/install.sh) --claude  # 仅安装 Claude Code

set -euo pipefail

# ============ 配置 ============
REPO_URL="https://github.com/freeabyss/luwu.git"
INSTALL_DIR="$HOME/.luwu"
PLUGIN_NAME="luwu"
MARKETPLACE_NAME="luwu-plugin"
PLUGIN_VERSION="1.0.0"
NOW_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

# ============ 颜色输出 ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { err "$*"; exit 1; }

# ============ 参数解析 ============
COMMAND="install"
INSTALL_CLAUDE=false
INSTALL_CODEX=false
INSTALL_ALL=true

for arg in "$@"; do
  case "$arg" in
    install)   COMMAND="install" ;;
    update)    COMMAND="update" ;;
    uninstall) COMMAND="uninstall" ;;
    --claude)  INSTALL_CLAUDE=true; INSTALL_ALL=false ;;
    --codex)   INSTALL_CODEX=true; INSTALL_ALL=false ;;
    --all)     INSTALL_ALL=true ;;
    -h|--help)
      echo "用法: bash install.sh [install|update|uninstall] [--claude|--codex|--all]"
      echo ""
      echo "命令:"
      echo "  install    安装插件（默认）"
      echo "  update     更新到最新版本"
      echo "  uninstall  卸载插件"
      echo ""
      echo "平台选项:"
      echo "  --all      自动检测并安装所有已安装的 agent 工具（默认）"
      echo "  --claude   仅安装 Claude Code"
      echo "  --codex    仅安装 Codex"
      exit 0
      ;;
    *) warn "未知参数: $arg" ;;
  esac
done

# ============ 依赖检查 ============
check_deps() {
  command -v git >/dev/null 2>&1 || die "需要 git，请先安装"
  if ! command -v jq >/dev/null 2>&1; then
    if command -v python3 >/dev/null 2>&1; then
      warn "未安装 jq，将使用 python3 处理 JSON"
      USE_PYTHON_JSON=true
    else
      die "需要 jq 或 python3，请先安装其中之一"
    fi
  else
    USE_PYTHON_JSON=false
  fi
}

# ============ JSON 操作工具 ============
# json_get file path       - 读取 JSON 值（返回 raw 字符串）
# json_set file path value - 设置 JSON 值（value 是 JSON 字符串）
# json_merge file file2   - 深度合并 file2 到 file（file2 优先），结果写回 file

json_get() {
  local file="$1" path="$2"
  if $USE_PYTHON_JSON; then
    python3 -c "
import json,sys
with open('$file') as f: d=json.load(f)
keys='$path'.split('.')
for k in keys:
  if k.endswith(']'):
    k,i=k[:-1].split('[')
    d=d.get(k,{}) if k else d
    d=d[int(i)]
  else:
    d=d.get(k) if isinstance(d,dict) else None
  if d is None: break
print(json.dumps(d) if not isinstance(d,str) else d)
" 2>/dev/null || echo ""
  else
    jq -r ".$path // empty" "$file" 2>/dev/null || echo ""
  fi
}

# 用 python 做深度 JSON 合并（最可靠）
json_merge_into() {
  local target="$1" patch_json="$2"
  python3 -c "
import json, sys

def deep_merge(base, patch):
    if isinstance(base, dict) and isinstance(patch, dict):
        result = dict(base)
        for k, v in patch.items():
            if k in result:
                result[k] = deep_merge(result[k], v)
            else:
                result[k] = v
        return result
    return patch

with open('$target') as f:
    try:
        base = json.load(f)
    except:
        base = {}
patch = json.loads('''$patch_json''')
merged = deep_merge(base, patch)
with open('$target', 'w') as f:
    json.dump(merged, f, indent=2, ensure_ascii=False)
    f.write('\n')
"
}

backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    cp "$f" "${f}${BACKUP_SUFFIX}"
    info "已备份: $f -> ${f}${BACKUP_SUFFIX}"
  fi
}

# ============ 仓库克隆/更新 ============
install_repo() {
  if [ -d "$INSTALL_DIR/.git" ]; then
    info "已存在安装目录 $INSTALL_DIR，执行更新..."
    cd "$INSTALL_DIR"
    git fetch origin main
    git reset --hard origin/main
  else
    info "克隆仓库到 $INSTALL_DIR ..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
  fi
  info "初始化 submodule..."
  git submodule update --init --recursive
  ok "仓库就绪: $INSTALL_DIR (commit: $(git rev-parse --short HEAD))"
}

update_repo() {
  if [ ! -d "$INSTALL_DIR/.git" ]; then
    warn "未找到已安装的仓库，将执行全新安装"
    install_repo
    return
  fi
  cd "$INSTALL_DIR"
  info "拉取最新代码..."
  git pull origin main
  git submodule update --init --recursive
  ok "已更新到最新版本 (commit: $(git rev-parse --short HEAD))"
}

# ============ Claude Code 安装 ============
install_claude() {
  local claude_dir="$HOME/.claude"
  if [ ! -d "$claude_dir" ]; then
    warn "未检测到 Claude Code 配置目录 (~/.claude)，跳过"
    return
  fi
  info "配置 Claude Code..."

  local settings_file="$claude_dir/settings.json"
  local installed_file="$claude_dir/plugins/installed_plugins.json"

  # 确保 settings.json 存在
  if [ ! -f "$settings_file" ]; then
    echo '{}' > "$settings_file"
  fi
  mkdir -p "$claude_dir/plugins"
  if [ ! -f "$installed_file" ]; then
    echo '{"version":2,"plugins":{}}' > "$installed_file"
  fi

  backup_file "$settings_file"
  backup_file "$installed_file"

  local abs_install_dir
  abs_install_dir=$(cd "$INSTALL_DIR" && pwd)

  # 合并 settings.json
  local settings_patch
  settings_patch=$(cat <<EOF
{
  "extraKnownMarketplaces": {
    "$MARKETPLACE_NAME": {
      "source": {
        "source": "directory",
        "path": "$abs_install_dir"
      }
    }
  },
  "enabledPlugins": {
    "${PLUGIN_NAME}@${MARKETPLACE_NAME}": true
  }
}
EOF
)
  json_merge_into "$settings_file" "$settings_patch"

  # 合并 installed_plugins.json
  local installed_patch
  installed_patch=$(python3 -c "
import json
patch = {
    'version': 2,
    'plugins': {
        '${PLUGIN_NAME}@${MARKETPLACE_NAME}': [{
            'scope': 'user',
            'installPath': '$abs_install_dir',
            'version': '$PLUGIN_VERSION',
            'installedAt': '$NOW_ISO',
            'lastUpdated': '$NOW_ISO'
        }]
    }
}
print(json.dumps(patch))
")
  json_merge_into "$installed_file" "$installed_patch"

  ok "Claude Code 配置完成"
}

# ============ Codex 安装 ============
install_codex() {
  local codex_dir="$HOME/.codex"
  if [ ! -d "$codex_dir" ]; then
    warn "未检测到 Codex 配置目录 (~/.codex)，跳过"
    return
  fi
  info "配置 Codex..."

  local config_file="$codex_dir/config.toml"
  local skills_dir="$codex_dir/skills"
  local agents_file="$codex_dir/AGENTS.md"
  mkdir -p "$skills_dir"

  local abs_install_dir
  abs_install_dir=$(cd "$INSTALL_DIR" && pwd)

  # Symlink skills（排除 vendor 目录）
  for skill_dir in "$INSTALL_DIR"/skills/*/; do
    skill_name=$(basename "$skill_dir")
    [ "$skill_name" = "vendor" ] && continue
    local link="$skills_dir/$skill_name"
    if [ -L "$link" ]; then
      rm "$link"
    elif [ -e "$link" ]; then
      backup_file "$link"
      rm -rf "$link"
    fi
    ln -s "$skill_dir" "$link"
    info "  skills/$skill_name -> $skill_dir"
  done

  # 追加 config.toml
  if [ -f "$config_file" ]; then
    backup_file "$config_file"
    if grep -q "\[marketplaces.$MARKETPLACE_NAME\]" "$config_file" 2>/dev/null; then
      info "config.toml 中已存在 luwu marketplace 配置，跳过追加"
    else
      cat >> "$config_file" <<EOF

[marketplaces.$MARKETPLACE_NAME]
last_updated = "$NOW_ISO"
source_type = "local"
source = "$abs_install_dir"

[plugins."${PLUGIN_NAME}@${MARKETPLACE_NAME}"]
enabled = true
EOF
      info "已追加 luwu 配置到 config.toml"
    fi
  else
    cat > "$config_file" <<EOF
[marketplaces.$MARKETPLACE_NAME]
last_updated = "$NOW_ISO"
source_type = "local"
source = "$abs_install_dir"

[plugins."${PLUGIN_NAME}@${MARKETPLACE_NAME}"]
enabled = true
EOF
    info "已创建 config.toml"
  fi

  # AGENTS.md 添加 prd agent 引用
  if [ -f "$agents_file" ]; then
    if grep -q "luwu/prd agent" "$agents_file" 2>/dev/null; then
      info "AGENTS.md 中已存在 luwu 引用"
    else
      backup_file "$agents_file"
      cat >> "$agents_file" <<EOF

---
## luwu/prd agent

PRD 撰写专家代理。当用户需要撰写、修改、评审 PRD 时，请参考以下定义：
- 读取 \`$abs_install_dir/agents/prd.md\` 作为 prd agent 的系统提示
EOF
      info "已追加 prd agent 引用到 AGENTS.md"
    fi
  else
    cat > "$agents_file" <<EOF
# Codex Global Agents

## luwu/prd agent

PRD 撰写专家代理。当用户需要撰写、修改、评审 PRD 时，请参考以下定义：
- 读取 \`$abs_install_dir/agents/prd.md\` 作为 prd agent 的系统提示
EOF
    info "已创建 AGENTS.md"
  fi

  ok "Codex 配置完成"
}

# ============ 卸载 ============
uninstall_all() {
  warn "开始卸载陆吾插件..."

  # Claude Code
  local claude_settings="$HOME/.claude/settings.json"
  local claude_installed="$HOME/.claude/plugins/installed_plugins.json"
  if [ -f "$claude_settings" ]; then
    backup_file "$claude_settings"
    python3 -c "
import json
with open('$claude_settings') as f: d=json.load(f)
d.get('extraKnownMarketplaces',{}).pop('$MARKETPLACE_NAME',None)
d.get('enabledPlugins',{}).pop('${PLUGIN_NAME}@${MARKETPLACE_NAME}',None)
with open('$claude_settings','w') as f: json.dump(d,f,indent=2,ensure_ascii=False); f.write('\n')
"
    ok "已从 Claude Code settings.json 移除 luwu"
  fi
  if [ -f "$claude_installed" ]; then
    backup_file "$claude_installed"
    python3 -c "
import json
with open('$claude_installed') as f: d=json.load(f)
d.get('plugins',{}).pop('${PLUGIN_NAME}@${MARKETPLACE_NAME}',None)
with open('$claude_installed','w') as f: json.dump(d,f,indent=2,ensure_ascii=False); f.write('\n')
"
    ok "已从 Claude Code installed_plugins.json 移除 luwu"
  fi

  # Codex
  local codex_config="$HOME/.codex/config.toml"
  if [ -f "$codex_config" ]; then
    backup_file "$codex_config"
    # 使用 sed 移除 luwu 相关 section（简单标记到下一个 [section] 之前）
    python3 -c "
import re
with open('$codex_config') as f: content=f.read()
# 移除 [marketplaces.luwu-plugin] 和 [plugins.\"luwu@luwu-plugin\"] section
content = re.sub(r'\n\[marketplaces\.$MARKETPLACE_NAME\][\s\S]*?(?=\n\[|\Z)', '', content)
content = re.sub(r'\n\[plugins\.\"${PLUGIN_NAME}@${MARKETPLACE_NAME}\"\][\s\S]*?(?=\n\[|\Z)', '', content)
with open('$codex_config','w') as f: f.write(content)
"
    ok "已从 Codex config.toml 移除 luwu"
  fi
  local codex_skills="$HOME/.codex/skills"
  for skill_dir in "$INSTALL_DIR"/skills/*/; do
    skill_name=$(basename "$skill_dir")
    [ "$skill_name" = "vendor" ] && continue
    local link="$codex_skills/$skill_name"
    if [ -L "$link" ]; then
      rm "$link"
      info "  移除 symlink: $link"
    fi
  done

  # 询问是否删除仓库
  echo ""
  read -rp "是否删除插件仓库目录 $INSTALL_DIR ? [y/N] " ans
  if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
    rm -rf "$INSTALL_DIR"
    ok "已删除 $INSTALL_DIR"
  else
    info "保留 $INSTALL_DIR（可手动删除）"
  fi

  ok "卸载完成。配置备份文件保留在原路径（后缀 $BACKUP_SUFFIX）"
}

# ============ 主流程 ============
main() {
  echo ""
  echo "  ╔═══════════════════════════════════════╗"
  echo "  ║       陆吾 Luwu - 开发流程插件        ║"
  echo "  ╚═══════════════════════════════════════╝"
  echo ""

  check_deps

  case "$COMMAND" in
    install)
      install_repo
      ;;
    update)
      update_repo
      ;;
    uninstall)
      uninstall_all
      exit 0
      ;;
  esac

  echo ""
  info "开始配置各平台..."
  echo ""

  if $INSTALL_ALL; then
    install_claude
    echo ""
    install_codex
  else
    $INSTALL_CLAUDE && install_claude
    $INSTALL_CODEX && install_codex
  fi

  echo ""
  ok "陆吾插件${COMMAND}完成！"
  echo ""
  echo "  安装位置: $INSTALL_DIR"
  echo ""
  echo "  使用方法:"
  echo "    /flow      - 项目全流程编排（需求→PRD→架构→开发→测试→PR）"
  echo "    /prd       - PRD 撰写"
  echo "    /architecture - 架构设计/评审"
  echo "    /test      - 测试全流程"
  echo "    /code-review - 代码审查"
  echo ""
  echo "  更新插件:  bash <(curl -fsSL https://raw.githubusercontent.com/freeabyss/luwu/main/install.sh) update"
  echo "  卸载插件:  bash <(curl -fsSL https://raw.githubusercontent.com/freeabyss/luwu/main/install.sh) uninstall"
  echo ""
  warn "请重启 Claude Code / Codex 或执行 /plugin reload 使配置生效"
  echo ""
}

main "$@"
