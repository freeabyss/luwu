#!/usr/bin/env bash
# 陆吾 Luwu - 个人开发流程插件一键安装脚本
#
# 用法:
#   bash <(curl -fsSL https://raw.githubusercontent.com/freeabyss/luwu/main/install.sh)          # 交互式安装
#   bash <(curl -fsSL https://raw.githubusercontent.com/freeabyss/luwu/main/install.sh) install  # 非交互：安装
#   bash <(curl -fsSL https://raw.githubusercontent.com/freeabyss/luwu/main/install.sh) update   # 更新
#   bash <(curl -fsSL https://raw.githubusercontent.com/freeabyss/luwu/main/install.sh) uninstall # 卸载
#   bash <(curl -fsSL https://raw.githubusercontent.com/freeabyss/luwu/main/install.sh) install --claude --opencode  # 指定平台

set -euo pipefail

# ============ 配置 ============
REPO_URL="https://github.com/freeabyss/luwu.git"
GITHUB_REPO="freeabyss/luwu"
INSTALL_DIR="$HOME/.luwu"
PLUGIN_NAME="luwu"
MARKETPLACE_NAME="luwu-plugin"
PLUGIN_VERSION="1.0.0"
NOW_ISO=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
BACKUP_SUFFIX=".bak.$(date +%Y%m%d%H%M%S)"

# 平台定义
# 格式: "标识|显示名|配置目录检测路径"
PLATFORMS=(
  "claude|Claude Code|$HOME/.claude"
  "codex|Codex|$HOME/.codex"
  "opencode|OpenCode|$HOME/.config/opencode"
)

# ============ 颜色输出 ============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
die()   { err "$*"; exit 1; }

# ============ 参数解析 ============
COMMAND=""
INSTALL_CLAUDE=false
INSTALL_CODEX=false
INSTALL_OPENCODE=false
INSTALL_ALL=false
INTERACTIVE=false

# 无参数时进入交互模式
if [ $# -eq 0 ]; then
  INTERACTIVE=true
fi

while [ $# -gt 0 ]; do
  case "$1" in
    install)   COMMAND="install" ;;
    update)    COMMAND="update" ;;
    uninstall) COMMAND="uninstall" ;;
    --claude)  INSTALL_CLAUDE=true ;;
    --codex)   INSTALL_CODEX=true ;;
    --opencode) INSTALL_OPENCODE=true ;;
    --all)     INSTALL_ALL=true ;;
    -y|--yes)  INTERACTIVE=false ;;
    -h|--help)
      echo "用法: bash install.sh [install|update|uninstall] [选项]"
      echo ""
      echo "命令:"
      echo "  install    安装插件（默认）"
      echo "  update     更新到最新版本"
      echo "  uninstall  卸载插件"
      echo ""
      echo "选项:"
      echo "  --all          自动检测并安装所有已安装的 agent 工具（默认）"
      echo "  --claude       仅安装 Claude Code"
      echo "  --codex        仅安装 Codex"
      echo "  --opencode     仅安装 OpenCode"
      echo "  -y, --yes      非交互模式，不弹出菜单"
      echo "  -h, --help     显示此帮助"
      echo ""
      echo "不带任何参数时进入交互式菜单。"
      exit 0
      ;;
    *) warn "未知参数: $1" ;;
  esac
  shift
done

# 如果指定了具体平台，则关闭 all
if $INSTALL_CLAUDE || $INSTALL_CODEX || $INSTALL_OPENCODE; then
  INSTALL_ALL=false
fi

# ============ 依赖检查 ============
check_deps() {
  command -v git >/dev/null 2>&1 || die "需要 git，请先安装"
  command -v python3 >/dev/null 2>&1 || die "需要 python3，请先安装"
}

# ============ 工具函数 ============
backup_file() {
  local f="$1"
  if [ -f "$f" ]; then
    cp "$f" "${f}${BACKUP_SUFFIX}"
    info "已备份: $f -> ${f}${BACKUP_SUFFIX}"
  fi
}

# ============ 平台检测 ============
detect_platforms() {
  local detected=()
  for p in "${PLATFORMS[@]}"; do
    local id="${p%%|*}"
    local rest="${p#*|}"
    local dir="${rest#*|}"
    if [ -d "$dir" ]; then
      detected+=("$id")
    fi
  done
  echo "${detected[@]}"
}

# ============ 交互式菜单 ============
show_banner() {
  echo ""
  echo "  ╔═══════════════════════════════════════╗"
  echo "  ║       陆吾 Luwu - 开发流程插件        ║"
  echo "  ╚═══════════════════════════════════════╝"
  echo ""
}

# Radio/Checkbox 字符（兼容中文终端）
RADIO_ON="(●)"
RADIO_OFF="( )"
CHK_ON="[✓]"
CHK_OFF="[ ]"

# 在交互式终端中用光标上移重绘，否则逐行追加打印
_tt_redraw() {
  local lines="$1"
  if [ -t 1 ]; then
    printf '\033[%dA\r' "$lines"
  fi
}

show_menu_action() {
  echo -e "${BOLD}请选择操作 (单选):${NC}"
  local labels=("安装插件" "更新插件" "卸载插件")
  local cmds=("install" "update" "uninstall")
  local selected=0  # 默认选第一个

  _draw_action() {
    for i in 0 1 2; do
      if [ "$i" -eq "$selected" ]; then
        printf "  ${GREEN}%s${NC} %d. %s\n" "$RADIO_ON" "$((i+1))" "${labels[$i]}"
      else
        printf "  %s %d. %s\n" "$RADIO_OFF" "$((i+1))" "${labels[$i]}"
      fi
    done
  }

  _draw_action
  local choice
  while true; do
    read -rp "请输入选项 [1]: " choice
    choice="${choice:-1}"
    if [ "$choice" = "1" ] || [ "$choice" = "2" ] || [ "$choice" = "3" ]; then
      selected=$((choice-1))
      [ -t 1 ] && { _tt_redraw 3; _draw_action; }
      break
    fi
    warn "无效选项，请输入 1、2 或 3"
  done
  COMMAND="${cmds[$selected]}"
}

show_menu_platforms() {
  echo ""
  echo -e "${BOLD}请选择要配置的 Agent 工具 (多选):${NC}"
  echo "  输入编号切换勾选状态，直接回车确认"
  echo ""

  local -a plat_ids=()
  local -a plat_names=()
  local -a plat_detected=()
  local -a plat_checked=()
  local count=0

  for p in "${PLATFORMS[@]}"; do
    local id="${p%%|*}"
    local rest="${p#*|}"
    local name="${rest%%|*}"
    local dir="${rest#*|}"
    plat_ids+=("$id")
    plat_names+=("$name")
    if [ -d "$dir" ]; then
      plat_detected+=(true)
      plat_checked+=(true)   # 已检测的默认勾选
    else
      plat_detected+=(false)
      plat_checked+=(false)
    fi
    count=$((count+1))
  done

  _draw_platforms() {
    for i in "${!plat_ids[@]}"; do
      local mark
      if [ "${plat_checked[$i]}" = true ]; then
        mark="${GREEN}${CHK_ON}${NC}"
      else
        mark="${CHK_OFF}"
      fi
      local tag=""
      if [ "${plat_detected[$i]}" = true ]; then
        tag="  ${GREEN}(已检测)${NC}"
      else
        tag="  ${YELLOW}(未检测，仍可强制选择)${NC}"
      fi
      # %b 解释变量中的 \033 转义序列
      printf "  %b %d. %-13s%b\n" "$mark" "$((i+1))" "${plat_names[$i]}" "$tag"
    done
    echo ""
  }

  _draw_platforms
  local sel
  while true; do
    read -rp "输入编号切换勾选（空格分隔多个），回车确认: " sel
    [ -z "$sel" ] && break
    for n in $sel; do
      if [[ "$n" =~ ^[0-9]+$ ]] && [ "$n" -ge 1 ] && [ "$n" -le "$count" ]; then
        local idx=$((n-1))
        if [ "${plat_checked[$idx]}" = true ]; then
          plat_checked[$idx]=false
        else
          plat_checked[$idx]=true
        fi
      else
        warn "无效编号: $n（有效范围 1-$count）"
      fi
    done
    if [ -t 1 ]; then
      _tt_redraw $((count+1))
      _draw_platforms
    fi
  done

  INSTALL_CLAUDE=false
  INSTALL_CODEX=false
  INSTALL_OPENCODE=false
  INSTALL_ALL=false

  for i in "${!plat_ids[@]}"; do
    if [ "${plat_checked[$i]}" = true ]; then
      case "${plat_ids[$i]}" in
        claude)   INSTALL_CLAUDE=true ;;
        codex)    INSTALL_CODEX=true ;;
        opencode) INSTALL_OPENCODE=true ;;
      esac
    fi
  done

  if ! $INSTALL_CLAUDE && ! $INSTALL_CODEX && ! $INSTALL_OPENCODE; then
    warn "未选择任何平台，退出"
    exit 0
  fi

  local selected_names=""
  $INSTALL_CLAUDE && selected_names+="Claude Code "
  $INSTALL_CODEX && selected_names+="Codex "
  $INSTALL_OPENCODE && selected_names+="OpenCode "
  info "已选择: ${selected_names% }"
}

# ============ 仓库克隆/更新 ============
install_repo() {
  if [ -d "$INSTALL_DIR/.git" ]; then
    info "已存在安装目录 ${INSTALL_DIR}，执行更新..."
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
# Claude Code 使用官方 CLI 从 GitHub marketplace 安装，无需本地 clone 或手写 JSON。
install_claude() {
  if ! command -v claude >/dev/null 2>&1; then
    warn "未检测到 claude CLI，跳过 Claude Code（请先安装 Claude Code）"
    return
  fi
  info "配置 Claude Code（从 GitHub marketplace 安装）..."

  # 清理旧的 directory source 配置（v1 版本曾用 ~/.luwu 本地路径注册 marketplace）
  local settings_file="$HOME/.claude/settings.json"
  if [ -f "$settings_file" ] && python3 -c "
import json, sys
d = json.load(open('$settings_file'))
src = d.get('extraKnownMarketplaces',{}).get('$MARKETPLACE_NAME',{}).get('source',{})
sys.exit(0 if src.get('source') == 'directory' else 1)
" 2>/dev/null; then
    info "  检测到旧版 directory source，迁移到 GitHub source..."
    claude plugin marketplace remove "$MARKETPLACE_NAME" >/dev/null 2>&1 || true
    claude plugin uninstall "${PLUGIN_NAME}@${MARKETPLACE_NAME}" >/dev/null 2>&1 || true
  fi

  # 添加 GitHub marketplace（已存在则 CLI 会提示，不影响）
  if claude plugin marketplace add "$GITHUB_REPO" 2>&1 | grep -qi "successfully added\|already"; then
    ok "  marketplace 已就绪: $MARKETPLACE_NAME"
  else
    err "  添加 marketplace 失败"
    return 1
  fi

  # 安装插件
  if claude plugin install "${PLUGIN_NAME}@${MARKETPLACE_NAME}" 2>&1 | grep -qi "successfully installed\|already installed\|already enabled"; then
    ok "  插件已启用: ${PLUGIN_NAME}@${MARKETPLACE_NAME}"
  else
    err "  插件安装失败"
    return 1
  fi

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

# ============ OpenCode 安装 ============
install_opencode() {
  local oc_dir="$HOME/.config/opencode"
  if [ ! -d "$oc_dir" ]; then
    warn "未检测到 OpenCode 配置目录 (~/.config/opencode)，跳过"
    return
  fi
  info "配置 OpenCode..."

  local skills_dir="$oc_dir/skills"
  local agents_file="$oc_dir/AGENTS.md"
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

  # AGENTS.md 添加 luwu 引用
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
# OpenCode Global Instructions

## luwu/prd agent

PRD 撰写专家代理。当用户需要撰写、修改、评审 PRD 时，请参考以下定义：
- 读取 \`$abs_install_dir/agents/prd.md\` 作为 prd agent 的系统提示
EOF
    info "已创建 AGENTS.md"
  fi

  ok "OpenCode 配置完成"
}

# ============ 卸载 ============
uninstall_all() {
  warn "开始卸载陆吾插件..."
  echo ""

  # Claude Code
  if $INSTALL_CLAUDE; then
    if command -v claude >/dev/null 2>&1; then
      claude plugin uninstall "${PLUGIN_NAME}@${MARKETPLACE_NAME}" 2>&1 || true
      claude plugin marketplace remove "$MARKETPLACE_NAME" 2>&1 || true
      ok "已从 Claude Code 卸载 luwu 插件"
    else
      warn "未找到 claude CLI，跳过 Claude Code 卸载"
    fi
  fi

  # Codex
  if $INSTALL_CODEX; then
    local codex_config="$HOME/.codex/config.toml"
    if [ -f "$codex_config" ]; then
      backup_file "$codex_config"
      python3 -c "
import re
with open('$codex_config') as f: content=f.read()
content = re.sub(r'\n\[marketplaces\.$MARKETPLACE_NAME\][\s\S]*?(?=\n\[|\Z)', '', content)
content = re.sub(r'\n\[plugins\.\"${PLUGIN_NAME}@${MARKETPLACE_NAME}\"\][\s\S]*?(?=\n\[|\Z)', '', content)
with open('$codex_config','w') as f: f.write(content)
"
      ok "已从 Codex config.toml 移除 luwu"
    fi
    local codex_skills="$HOME/.codex/skills"
    if [ -d "$codex_skills" ]; then
      for skill_dir in "$INSTALL_DIR"/skills/*/; do
        skill_name=$(basename "$skill_dir")
        [ "$skill_name" = "vendor" ] && continue
        local link="$codex_skills/$skill_name"
        if [ -L "$link" ]; then
          rm "$link"
          info "  移除 Codex symlink: $link"
        fi
      done
    fi
    local codex_agents="$HOME/.codex/AGENTS.md"
    if [ -f "$codex_agents" ]; then
      backup_file "$codex_agents"
      python3 -c "
import re
with open('$codex_agents') as f: c=f.read()
c = re.sub(r'\n---\n## luwu/prd agent[\s\S]*?(?=\n---\n|\Z)', '', c)
with open('$codex_agents','w') as f: f.write(c)
"
      ok "已从 Codex AGENTS.md 移除 luwu 引用"
    fi
  fi

  # OpenCode
  if $INSTALL_OPENCODE; then
    local oc_skills="$HOME/.config/opencode/skills"
    if [ -d "$oc_skills" ]; then
      for skill_dir in "$INSTALL_DIR"/skills/*/; do
        skill_name=$(basename "$skill_dir")
        [ "$skill_name" = "vendor" ] && continue
        local link="$oc_skills/$skill_name"
        if [ -L "$link" ]; then
          rm "$link"
          info "  移除 OpenCode symlink: $link"
        fi
      done
    fi
    local oc_agents="$HOME/.config/opencode/AGENTS.md"
    if [ -f "$oc_agents" ]; then
      backup_file "$oc_agents"
      python3 -c "
import re
with open('$oc_agents') as f: c=f.read()
c = re.sub(r'\n---\n## luwu/prd agent[\s\S]*?(?=\n---\n|\Z)', '', c)
with open('$oc_agents','w') as f: f.write(c)
"
      ok "已从 OpenCode AGENTS.md 移除 luwu 引用"
    fi
  fi

  # 询问是否删除本地仓库（仅 codex/opencode 用户才有）
  if [ -d "$INSTALL_DIR/.git" ]; then
    echo ""
    read -rp "是否删除插件仓库目录 $INSTALL_DIR ? [y/N] " ans
    if [ "$ans" = "y" ] || [ "$ans" = "Y" ]; then
      rm -rf "$INSTALL_DIR"
      ok "已删除 $INSTALL_DIR"
    else
      info "保留 ${INSTALL_DIR}（可手动删除）"
    fi
  fi

  echo ""
  ok "卸载完成。配置备份文件保留在原路径（后缀 $BACKUP_SUFFIX）"
}

# ============ 主流程 ============
main() {
  show_banner
  check_deps

  # 交互式菜单
  if $INTERACTIVE; then
    show_menu_action
    show_menu_platforms
  else
    # 非交互模式默认值
    COMMAND="${COMMAND:-install}"
    if ! $INSTALL_CLAUDE && ! $INSTALL_CODEX && ! $INSTALL_OPENCODE; then
      INSTALL_ALL=true
    fi
  fi

  # codex/opencode 需要本地 clone；Claude Code 走官方 CLI 从 GitHub 安装
  local needs_local_repo=false
  if $INSTALL_CODEX || $INSTALL_OPENCODE; then
    needs_local_repo=true
  elif $INSTALL_ALL; then
    # --all 模式下按实际检测到的目录判断
    [ -d "$HOME/.codex" ] && needs_local_repo=true
    [ -d "$HOME/.config/opencode" ] && needs_local_repo=true
  fi

  case "$COMMAND" in
    install)
      $needs_local_repo && install_repo
      ;;
    update)
      # Claude Code 通过官方 CLI 更新（独立完成，无需后续 install_claude）
      if $INSTALL_CLAUDE && command -v claude >/dev/null 2>&1; then
        info "更新 Claude Code 插件..."
        claude plugin update "${PLUGIN_NAME}@${MARKETPLACE_NAME}" 2>&1 || true
      fi
      # codex/opencode 拉取最新仓库后重新链接
      if $needs_local_repo; then
        update_repo
      fi
      # 更新后重配 codex/opencode（symlink 已指向最新目录，刷新 config 即可）
      echo ""
      info "刷新各平台配置..."
      echo ""
      if $INSTALL_ALL; then
        install_codex
        echo ""
        install_opencode
      else
        $INSTALL_CODEX && { install_codex; echo ""; }
        $INSTALL_OPENCODE && { install_opencode; echo ""; }
      fi
      echo ""
      ok "陆吾插件更新完成！"
      echo ""
      warn "请重启对应的 Agent 工具或执行 /plugin reload 使配置生效"
      echo ""
      exit 0
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
    echo ""
    install_opencode
  else
    $INSTALL_CLAUDE && { install_claude; echo ""; }
    $INSTALL_CODEX && { install_codex; echo ""; }
    $INSTALL_OPENCODE && { install_opencode; echo ""; }
  fi

  echo ""
  ok "陆吾插件${COMMAND}完成！"
  echo ""
  if $needs_local_repo; then
    echo "  本地安装位置: $INSTALL_DIR"
    echo ""
  fi
  echo "  使用方法:"
  echo "    /flow         - 项目全流程编排（需求→PRD→架构→开发→测试→PR）"
  echo "    /prd          - PRD 撰写"
  echo "    /architecture - 架构设计/评审"
  echo "    /test         - 测试全流程"
  echo "    /code-review  - 代码审查"
  echo ""
  echo "  更新插件:  bash install.sh update"
  echo "  卸载插件:  bash install.sh uninstall"
  echo ""
  warn "请重启对应的 Agent 工具或执行 /plugin reload 使配置生效"
  echo ""
}

main "$@"
