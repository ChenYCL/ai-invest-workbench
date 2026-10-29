#!/bin/bash
# 玖峰投研工作台 · macOS 安装器
# 复刻官方 install.ps1 playbook 的层级结构，适配 macOS：
#   [1] 插件层    两个 DSH 插件 -> ~/.dsh/jiufeng-plugins + profile 注册 + node_modules 软链
#   [2] 预设层    ai-finance Agent 预设（89 技能）-> ~/.dsh/.agent-presets
#   [3] 配置层    settings.yaml 默认预设 + profile cordis.patch.yml 收窄
#   [4] 图标层    品牌图标 -> ~/.dsh/icons（仅用户目录；不改 .app，保签名完整）
#
# 与 Windows 版的差异（刻意为之，见 README-macos.md）：
#   - 不 patch .app 包（会破坏 notarized 签名 → Gatekeeper 拒启）
#   - 因此「受控更新守卫 / 品牌文案 / splash」不做；更新防护改由防火墙层实现（见 harden）
#
# 用法: ./install-macos.sh [--dry-run] [--uninstall]
set -euo pipefail

DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
SELF="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# 兼容两种布局：仓库内 macos/ 子目录（私库布局）或平铺的 ../jiufeng-invest
if [ -d "$SELF/../dsh-ai-invest-sidebar" ]; then
  REPO="$(cd "$SELF/.." && pwd)"
else
  REPO="$(cd "$SELF/../jiufeng-invest" && pwd)"
fi
PLUGIN_STORE="$DSH_HOME/jiufeng-plugins"
PROFILE_DIR="$DSH_HOME/profiles/desktop"
PRESET_ID="ai-finance"
PLUGINS=(dsh-ai-invest-sidebar dsh-finance-tools)
STAMP="$(date +%Y%m%d-%H%M%S)"
DRY=0
UNINSTALL=0
[ "${1:-}" = "--dry-run" ] && DRY=1
[ "${1:-}" = "--uninstall" ] && UNINSTALL=1

say()  { printf '  \033[36m%s\033[0m\n' "$*"; }
ok()   { printf '    \033[32mOK\033[0m  %s\n' "$*"; }
info() { printf '    ..  %s\n' "$*"; }
warn() { printf '    \033[33m!!\033[0m  %s\n' "$*"; }
die()  { printf '    \033[31mXX\033[0m  %s\n' "$*"; exit 1; }

backup() { # backup <file>
  [ -f "$1" ] || return 0
  cp "$1" "$1.bak-jiufeng-$STAMP"
  info "已备份 -> $(basename "$1").bak-jiufeng-$STAMP"
}

# ---------- 0. 前置检查 ----------
[ -d "$DSH_HOME/profiles" ] || die "找不到 $DSH_HOME/profiles —— 请先启动一次 DSH Desktop 完成初始化"
[ -d "$PROFILE_DIR" ] || die "找不到 desktop profile"
for p in "${PLUGINS[@]}"; do
  [ -f "$REPO/$p/package.json" ] || die "仓库缺少插件 $p"
done
[ -f "$REPO/agent-preset/$PRESET_ID/preset.yml" ] || die "仓库缺少 agent 预设"

# DSH 必须在退出状态（否则退出时会把配置盖回去）
if pgrep -f "MacOS/DSH Desktop$" >/dev/null; then
  say "检测到 DSH Desktop 正在运行，正在退出…"
  pkill -f "MacOS/DSH Desktop$" || true
  sleep 3
  pgrep -f "MacOS/DSH Desktop$" >/dev/null && die "DSH 仍在运行，请先手动完全退出（含托盘）"
  ok "DSH 已退出"
fi

if [ "$UNINSTALL" = 1 ]; then
  say "卸载玖峰插件层"
  python3 - "$PROFILE_DIR/package.json" "${PLUGINS[@]}" <<'EOF'
import json, sys, os
p = sys.argv[1]; names = sys.argv[2:]
d = json.load(open(p))
deps = d.get('dependencies', {})
for n in names:
    deps.pop(n, None)
    b = d.get('dsh', {}).get('profile', {}).get('bundles', [])
    d['dsh']['profile']['bundles'] = [x for x in b if x != n]
json.dump(d, open(p, 'w'), indent=2, ensure_ascii=False)
EOF
  for p in "${PLUGINS[@]}"; do rm -f "$PROFILE_DIR/node_modules/$p"; done
  rm -rf "$PLUGIN_STORE" "$DSH_HOME/.agent-presets/$PRESET_ID"
  ok "已卸载（settings.yaml 与 cordis.patch.yml 里的条目可用 .bak-jiufeng-* 备份恢复）"
  exit 0
fi

say "玖峰投研工作台 · macOS 安装（源: ${REPO}）"
[ "$DRY" = 1 ] && say "[预演模式] 不改动任何文件"

# ---------- 1. 插件层 ----------
say "[1/4] 安装插件"
if [ "$DRY" = 0 ]; then
  mkdir -p "$PLUGIN_STORE"
  for p in "${PLUGINS[@]}"; do
    rm -rf "$PLUGIN_STORE/$p"
    # 只复制运行所需（lib/client/package.json/cordis.patch.yml + 侧边栏的 runtime 与数据文件）
    mkdir -p "$PLUGIN_STORE/$p"
    (cd "$REPO/$p" && tar cf - package.json cordis.patch.yml lib client runtime skills-data.json expert-prompts.json inputschema-inventory.json skill-placeholders.json README.md 2>/dev/null) | (cd "$PLUGIN_STORE/$p" && tar xf -) || true
    [ -f "$PLUGIN_STORE/$p/lib/index.js" ] || die "插件 $p 复制不完整"
    ok "已安装 $p"
  done

  # profile package.json：dependencies + bundles（幂等：内容没变就不写不备份）
  python3 - "$PROFILE_DIR/package.json" "$PLUGIN_STORE" "${PLUGINS[@]}" <<'EOF'
import json, sys, os, shutil, datetime
p, store = sys.argv[1], sys.argv[2]; names = sys.argv[3:]
d = json.load(open(p))
orig = json.dumps(d, sort_keys=True)
deps = d.setdefault('dependencies', {})
prof = d.setdefault('dsh', {}).setdefault('profile', {})
bundles = prof.setdefault('bundles', [])
for n in names:
    want = 'file:' + os.path.join(store, n)
    if deps.get(n) != want: deps[n] = want
    if n not in bundles: bundles.append(n)
if json.dumps(d, sort_keys=True) != orig:
    shutil.copy(p, p + '.bak-jiufeng-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
    with open(p, 'w') as f: json.dump(d, f, indent=2, ensure_ascii=False)
    print('    OK  profile package.json 已更新（含备份）')
else:
    print('    OK  profile 配置已是最新')
EOF

  # node_modules 软链（macOS 用 symlink，无需特权；Windows 版的 junction 等价物）
  mkdir -p "$PROFILE_DIR/node_modules"
  for p in "${PLUGINS[@]}"; do
    link="$PROFILE_DIR/node_modules/$p"
    rm -rf "$link"
    ln -s "$PLUGIN_STORE/$p" "$link"
    ok "已链接 $p"
  done
else
  for p in "${PLUGINS[@]}"; do info "[预演] $REPO/$p -> $PLUGIN_STORE/$p + 软链"; done
fi

# ---------- 2. 预设层 ----------
say "[2/4] 安装投研 Agent 预设（89 技能）"
PRESET_DST="$DSH_HOME/.agent-presets/$PRESET_ID"
if [ "$DRY" = 0 ]; then
  mkdir -p "$DSH_HOME/.agent-presets"
  rm -rf "$PRESET_DST"
  cp -R "$REPO/agent-preset/$PRESET_ID" "$PRESET_DST"
  N=$(find "$PRESET_DST/skills" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
  [ "$N" -ge 80 ] || die "技能数异常: $N"
  ok "已安装 $N 个技能 -> $PRESET_DST"
else
  info "[预演] agent-preset/$PRESET_ID -> $PRESET_DST"
fi

# ---------- 3. 配置层 ----------
say "[3/4] 默认 Agent 预设 + profile 收窄"
SETTINGS="$DSH_HOME/settings.yaml"
if [ "$DRY" = 0 ]; then
  python3 - "$SETTINGS" "$PRESET_ID" <<'EOF'
import sys, os, re, shutil, datetime
path, pid = sys.argv[1], sys.argv[2]
if not os.path.exists(path):
    with open(path, 'w') as f:
        f.write(f"agent-presets:\n  default: {pid}\n")
    print(f'    OK  已创建 settings.yaml 并设 default: {pid}')
    sys.exit(0)
raw = open(path, encoding='utf-8').read()
m = re.search(r"(?m)^agent-presets:[ \t]*\n((?:[ \t]+[^\n]*\n?)*)", raw)
if m:
    block = m.group(1)
    if re.search(r"(?m)^[ \t]+default:", block):
        if re.search(rf"(?m)^[ \t]+default:[ \t]*{re.escape(pid)}[ \t]*$", block):
            print('    OK  默认预设已是 ai-finance'); sys.exit(0)
        new = re.sub(r"(?m)^([ \t]+)default:[^\n]*", rf"\g<1>default: {pid}", block)
    else:
        new = block.rstrip('\n') + f'\n  default: {pid}\n'
    raw = raw[:m.start(1)] + new + raw[m.end(1):]
else:
    raw = raw.rstrip('\n') + f'\n\nagent-presets:\n  default: {pid}\n'
shutil.copy(path, path + '.bak-jiufeng-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
open(path, 'w', encoding='utf-8').write(raw)
print(f'    OK  settings.yaml 已设 default: {pid}（含备份）')
EOF

  # profile cordis.patch.yml：合并 6 条与投研无关的 host 插件禁用项（幂等，按 id 判重）
  python3 - "$PROFILE_DIR/cordis.patch.yml" <<'EOF'
import sys, os, re
path = sys.argv[1]
entries = [
    ('session-telemetry-otel', '# 遥测（OTel）：停用与投研无关的上报'),
    ('message-feedback',       '# 消息反馈（赞/踩浮层）'),
    ('command-feedback',       '# /feedback 斜杠命令'),
    ('open-in-app',            # '会话头部 Open In... host 半边'
     '# 会话头部「Open In...」按钮 host 半边'),
    ('ui-open-in-app',         '# 同一按钮的浏览器半边'),
    ('code-runtime',           '# PTC 专用运行时，未用到'),
]
raw = open(path, encoding='utf-8').read() if os.path.exists(path) else ''
added = 0
for eid, note in entries:
    if re.search(rf"(?m)^[ \t]*-[ \t]*id:[ \t]*{re.escape(eid)}[ \t]*$", raw):
        continue
    raw = raw.rstrip('\n') + f'\n\n{note}\n- id: {eid}\n  disabled: true\n'
    added += 1
if added:
    import shutil, datetime
    if os.path.exists(path):
        shutil.copy(path, path + '.bak-jiufeng-' + datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
    open(path, 'w', encoding='utf-8').write(raw)
print(f'    OK  cordis.patch.yml 新增 {added} 条禁用项' if added else '    OK  禁用项已齐')
EOF
else
  info "[预演] settings.yaml 设 agent-presets.default: $PRESET_ID"
  info "[预演] cordis.patch.yml 合并 6 条禁用项"
fi

# ---------- 4. 图标层（仅用户目录，不动 .app） ----------
say "[4/4] 品牌图标（用户目录层）"
ICONS_SRC="$SELF/brand"; [ -d "$ICONS_SRC" ] || ICONS_SRC="$HOME/Documents/mac-env-handle/jiufeng-invest-macos/brand"
if [ "$DRY" = 0 ]; then
  if [ -d "$ICONS_SRC" ]; then
    mkdir -p "$DSH_HOME/icons"
    cp -f "$ICONS_SRC"/*.png "$ICONS_SRC"/*.ico "$DSH_HOME/icons/" 2>/dev/null || true
    ok "图标已铺 -> $DSH_HOME/icons"
  else
    warn "找不到图标源目录，跳过（不影响功能）"
  fi
else
  info "[预演] icons/* -> $DSH_HOME/icons"
fi

echo
say "安装完成。启动 DSH Desktop 即见投研工作台。"
say "模型 Key 需自备：DSH 设置里填 DeepSeek/通义/智谱 Key。"
