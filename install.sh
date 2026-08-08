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
RAW_DEPS_URL="https://raw.githubusercontent.com/${GITHUB_REPO}/main/dependencies.json"
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
CURSOR="❯"
# ANSI: 反白（光标行）、清除到行尾
REV='\033[7m'; RST='\033[0m'; CLR_EOL='\033[K'

# ============ 终端原始模式 / 按键读取 ============
STTY_SAVE=""

tty_raw_on() {
  [ -t 0 ] && [ -t 1 ] || return 1
  STTY_SAVE=$(stty -g)
  stty -echo -icanon min 1 time 0
  trap 'tty_raw_off' EXIT INT TERM
  return 0
}

tty_raw_off() {
  [ -n "$STTY_SAVE" ] && stty "$STTY_SAVE" 2>/dev/null
  STTY_SAVE=""
  trap - EXIT INT TERM
}

# 读取一个按键，输出符号：UP / DOWN / ENTER / SPACE / 数字 / 其他字符
read_key() {
  local key rest
  IFS= read -rsn1 key
  case "$key" in
    $'\x1b')
      # 方向键为 ESC [ A/B/C/D 三字节；后两字节同批到达，立即读取
      # -t 1 作为单独按 ESC 时的兜底（bash 3.2 的 read -t 仅支持整数秒）
      IFS= read -rsn2 -t 1 rest 2>/dev/null || true
      case "$rest" in
        "[A") echo "UP" ;;
        "[B") echo "DOWN" ;;
        "[C") echo "RIGHT" ;;
        "[D") echo "LEFT" ;;
        *)   echo "ESC" ;;
      esac
      ;;
    ""|$'\n'|$'\r') echo "ENTER" ;;
    " ")            echo "SPACE" ;;
    *)              printf '%s' "$key" ;;
  esac
}

# 光标上移 N 行并回到行首
move_up() {
  printf '\033[%dA\r' "$1"
}

# 数组间接访问（兼容 bash 3.2，无 nameref）
arr_len()     { eval "echo \${#$1[@]}"; }
arr_get()     { eval "echo \"\${$1[\$2]}\""; }
arr_get_bool(){ eval "eval \"[ \\\"\${$1[\$2]}\\\" = true ]\""; }

# ============ 单选菜单（radio）============
# 用法: menu_radio "标题" "项1" "项2" ...
# 选中索引写入全局变量 MENU_RESULT
MENU_RESULT=-1
menu_radio() {
  local title="$1"; shift
  local -a items=("$@")
  local n=${#items[@]}
  local cur=0
  local hint="↑/↓ 移动  回车确认  (也可按数字键)"

  echo -e "${BOLD}${title}${NC}"

  local i marker line key
  while true; do
    for ((i=0; i<n; i++)); do
      if [ "$i" -eq "$cur" ]; then
        marker="${GREEN}${RADIO_ON}${NC}"
        line="${CURSOR} ${marker} ${items[$i]}"
        printf "  ${REV}%b${RST}${CLR_EOL}\n" "$line"
      else
        marker="${RADIO_OFF}"
        printf "   %b %b${CLR_EOL}\n" "$marker" "${items[$i]}"
      fi
    done
    printf "  ${CYAN}%b${RST}${CLR_EOL}" "$hint"

    key=$(read_key)
    case "$key" in
      UP|k)   cur=$(( (cur - 1 + n) % n )); move_up "$n" ;;
      DOWN|j) cur=$(( (cur + 1) % n ));     move_up "$n" ;;
      ENTER|SPACE) break ;;
      [0-9])
        local idx=$((key - 1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "$n" ]; then
          cur=$idx; move_up "$n"
        fi ;;
    esac
  done

  printf "${CLR_EOL}\n"
  MENU_RESULT=$cur
}

# ============ 多选菜单（checkbox）============
# 用法: menu_checkbox "标题" 名称数组名 勾选数组名
# 勾选数组元素为 true/false，会被原地修改（通过 eval）
menu_checkbox() {
  local title="$1"
  local names_ref="$2"
  local checked_ref="$3"
  local n; n=$(arr_len "$names_ref")
  local cur=0
  local hint="↑/↓ 移动  空格勾选/取消  回车确认  (也可按数字键)"

  echo -e "${BOLD}${title}${NC}"

  local i mark name_i line key curval
  while true; do
    for ((i=0; i<n; i++)); do
      name_i=$(arr_get "$names_ref" "$i")
      if arr_get_bool "$checked_ref" "$i"; then
        mark="${GREEN}${CHK_ON}${NC}"
      else
        mark="${CHK_OFF}"
      fi
      if [ "$i" -eq "$cur" ]; then
        line="${CURSOR} ${mark} ${name_i}"
        printf "  ${REV}%b${RST}${CLR_EOL}\n" "$line"
      else
        printf "   %b  %b${CLR_EOL}\n" "$mark" "$name_i"
      fi
    done
    printf "  ${CYAN}%b${RST}${CLR_EOL}" "$hint"

    key=$(read_key)
    case "$key" in
      UP|k)   cur=$(( (cur - 1 + n) % n )); move_up "$n" ;;
      DOWN|j) cur=$(( (cur + 1) % n ));     move_up "$n" ;;
      SPACE)
        if arr_get_bool "$checked_ref" "$cur"; then
          eval "$checked_ref[$cur]=false"
        else
          eval "$checked_ref[$cur]=true"
        fi
        move_up "$n" ;;
      ENTER) break ;;
      [0-9])
        local idx=$((key - 1))
        if [ "$idx" -ge 0 ] && [ "$idx" -lt "$n" ]; then
          if arr_get_bool "$checked_ref" "$idx"; then
            eval "$checked_ref[$idx]=false"
          else
            eval "$checked_ref[$idx]=true"
          fi
          move_up "$n"
        fi ;;
    esac
  done

  printf "${CLR_EOL}\n"
}

# ============ 回退：数字输入菜单（非 TTY 环境）============
fallback_radio() {
  local title="$1"; shift
  local -a items=("$@")
  local n=${#items[@]} i
  echo -e "${BOLD}${title}${NC}"
  for ((i=0; i<n; i++)); do
    printf "  %d. %b\n" "$((i+1))" "${items[$i]}"
  done
  local choice
  read -rp "请输入选项 [1]: " choice
  choice="${choice:-1}"
  MENU_RESULT=$((choice - 1))
}

fallback_checkbox() {
  local names_ref="$1"
  local checked_ref="$2"
  local n; n=$(arr_len "$names_ref")
  local i sel name_i
  while true; do
    for ((i=0; i<n; i++)); do
      name_i=$(arr_get "$names_ref" "$i")
      if arr_get_bool "$checked_ref" "$i"; then
        printf "  [x] %d. %b\n" "$((i+1))" "$name_i"
      else
        printf "  [ ] %d. %b\n" "$((i+1))" "$name_i"
      fi
    done
    read -rp "输入编号切换勾选，直接回车确认: " sel
    [ -z "$sel" ] && break
    for num in $sel; do
      if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le "$n" ]; then
        local idx=$((num-1))
        if arr_get_bool "$checked_ref" "$idx"; then
          eval "$checked_ref[$idx]=false"
        else
          eval "$checked_ref[$idx]=true"
        fi
      fi
    done
    move_up "$n" 2>/dev/null || true
  done
}

show_menu_action() {
  local labels=("安装插件" "更新插件" "卸载插件")
  local cmds=("install" "update" "uninstall")
  if tty_raw_on; then
    menu_radio "请选择操作 (单选):" "${labels[@]}"
    tty_raw_off
    echo ""
  else
    fallback_radio "请选择操作 (单选):" "${labels[@]}"
  fi
  COMMAND="${cmds[$MENU_RESULT]}"
}

show_menu_platforms() {
  echo ""
  local -a plat_ids=()
  local -a plat_names=()
  local -a plat_checked=()

  for p in "${PLATFORMS[@]}"; do
    local id="${p%%|*}"
    local rest="${p#*|}"
    local name="${rest%%|*}"
    local dir="${rest#*|}"
    plat_ids+=("$id")
    if [ -d "$dir" ]; then
      name+="  ${GREEN}(已检测)${NC}"
      plat_checked+=(true)
    else
      name+="  ${YELLOW}(未检测)${NC}"
      plat_checked+=(false)
    fi
    plat_names+=("$name")
  done

  if tty_raw_on; then
    menu_checkbox "请选择要配置的 Agent 工具 (多选):" plat_names plat_checked
    tty_raw_off
    echo ""
  else
    echo -e "${BOLD}请选择要配置的 Agent 工具 (多选):${NC}"
    fallback_checkbox plat_names plat_checked
  fi

  INSTALL_CLAUDE=false
  INSTALL_CODEX=false
  INSTALL_OPENCODE=false
  INSTALL_ALL=false

  local i
  for ((i=0; i<${#plat_ids[@]}; i++)); do
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
  ok "已更新到最新版本 (commit: $(git rev-parse --short HEAD))"
}

# ============ 依赖插件安装 ============
# 读取 dependencies.json：优先本地 clone（$INSTALL_DIR），否则从 GitHub raw 拉取。
load_dependencies_json() {
  if [ -f "$INSTALL_DIR/dependencies.json" ]; then
    cat "$INSTALL_DIR/dependencies.json"
  elif command -v curl >/dev/null 2>&1; then
    curl -fsSL "$RAW_DEPS_URL" 2>/dev/null || true
  fi
}

# 检查某 Claude 插件是否已安装（精确匹配 name@marketplace 整行，忽略前导 cursor/空白）。
is_claude_plugin_installed() {
  local name="$1" mkt="$2"
  claude plugin list 2>/dev/null \
    | sed 's/^[[:space:]]*❯[[:space:]]*//; s/^[[:space:]]*//' \
    | grep -qx "${name}@${mkt}"
}

# 安装 dependencies.json 中声明的 Claude 平台插件：已安装则跳过，缺失则按官方方式添加 marketplace 并安装。
install_dependencies() {
  if ! command -v claude >/dev/null 2>&1; then
    info "  跳过依赖安装（未检测到 claude CLI）"
    return 0
  fi
  local deps_json
  deps_json=$(load_dependencies_json)
  if [ -z "$deps_json" ]; then
    warn "  无法获取 dependencies.json，跳过依赖安装"
    return 0
  fi

  info "检查依赖插件..."
  local name mkt repo
  while IFS=$'\t' read -r name mkt repo; do
    [ -n "$name" ] || continue
    if is_claude_plugin_installed "$name" "$mkt"; then
      ok "  已安装: ${name}@${mkt}"
      continue
    fi
    info "  安装依赖: ${name}@${mkt} (from ${repo})"
    if claude plugin marketplace add "$repo" 2>&1 | grep -qi "successfully added\|already"; then
      if claude plugin install "${name}@${mkt}" 2>&1 | grep -qi "successfully installed\|already installed\|already enabled"; then
        ok "    已安装: ${name}@${mkt}"
      else
        warn "    ${name} 安装失败，请手动执行: claude plugin install ${name}@${mkt}"
      fi
    else
      warn "    添加 marketplace 失败: ${repo}，请手动执行: claude plugin marketplace add ${repo}"
    fi
  done < <(printf '%s' "$deps_json" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for d in data.get("dependencies", []):
    if d.get("type") == "plugin" and "claude" in d.get("platforms", []):
        print("\t".join([d["name"], d["marketplace"], d["repo"]]))
')
}

# ============ 个人知识库脚手架 ============
# 在默认路径 ~/.luwu/knowledge-base/ 铺好 index.md + 00_template/ + 01_global/ 骨架。
# 只补不盖：已存在的文件（用户已沉淀的知识）一律不动。
scaffold_knowledge_base() {
  local kb_dir="${LUWU_KB_PATH:-$HOME/.luwu/knowledge-base}"
  local scaffold_src="$INSTALL_DIR/skills/init-project/references/kb-scaffold"

  if [ ! -d "$scaffold_src" ]; then
    # 通过 curl 安装且本地无 clone 时，脚手架源可能不存在；init-project 运行时仍会兜底。
    info "未找到知识库脚手架源（$scaffold_src），跳过；首次运行 /init-project 时会自动创建。"
    return 0
  fi

  if [ -f "$kb_dir/index.md" ]; then
    info "个人知识库已存在: $kb_dir（保留已有内容，不覆盖）"
    return 0
  fi

  info "初始化个人知识库: $kb_dir"
  mkdir -p "$kb_dir/00_template" "$kb_dir/01_global"
  # 逐个拷贝，已存在则不覆盖
  [ -f "$kb_dir/index.md" ]              || cp "$scaffold_src/index.md"              "$kb_dir/index.md"
  [ -f "$kb_dir/00_template/README.md" ] || cp "$scaffold_src/00_template/README.md" "$kb_dir/00_template/README.md"
  [ -f "$kb_dir/01_global/README.md" ]   || cp "$scaffold_src/01_global/README.md"   "$kb_dir/01_global/README.md"
  ok "个人知识库就绪: $kb_dir（在 index.md 登记你的通用知识与自定义模板）"
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

  echo ""
  install_dependencies

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
  mkdir -p "$skills_dir"

  local abs_install_dir
  abs_install_dir=$(cd "$INSTALL_DIR" && pwd)

  # Symlink skills
  for skill_dir in "$INSTALL_DIR"/skills/*/; do
    skill_name=$(basename "$skill_dir")
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
  mkdir -p "$skills_dir"

  local abs_install_dir
  abs_install_dir=$(cd "$INSTALL_DIR" && pwd)

  # Symlink skills
  for skill_dir in "$INSTALL_DIR"/skills/*/; do
    skill_name=$(basename "$skill_dir")
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
        local link="$codex_skills/$skill_name"
        if [ -L "$link" ]; then
          rm "$link"
          info "  移除 Codex symlink: $link"
        fi
      done
    fi
  fi

  # OpenCode
  if $INSTALL_OPENCODE; then
    local oc_skills="$HOME/.config/opencode/skills"
    if [ -d "$oc_skills" ]; then
      for skill_dir in "$INSTALL_DIR"/skills/*/; do
        skill_name=$(basename "$skill_dir")
        local link="$oc_skills/$skill_name"
        if [ -L "$link" ]; then
          rm "$link"
          info "  移除 OpenCode symlink: $link"
        fi
      done
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
        echo ""
        install_dependencies
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

  # 个人知识库脚手架（只补不盖；无本地 clone 时跳过，init-project 运行时兜底）
  scaffold_knowledge_base
  echo ""

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
