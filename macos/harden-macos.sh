#!/bin/bash
# 玖峰投研工作台 · macOS 安全加强
# 需要 sudo（改 /etc/hosts），脚本只追加带标记的行，可一键撤销。
#
# 做两件事（等价于 Windows 版「受控更新守卫」，但不破坏 .app 签名）：
#   1. 黑洞化 report365.com.cn —— 一键切断：
#        · 使用数据上报（默认开启的遥测 → fetch 失败即静默，代码已 catch）
#        · 后台更新检查与 force 强制更新弹窗
#        · 用户反馈上传
#      行情数据（东财/腾讯/雪球/新浪/凤凰）不受影响。
#   2. 校验 DSH Desktop 签名完整性（确认没被 patch 过 .app）
#
# 用法: sudo ./harden-macos.sh          # 加强
#       sudo ./harden-macos.sh --undo   # 撤销
set -euo pipefail
MARK="# jiufeng-invest-harden"
HOSTS=/etc/hosts
DOMAIN="report365.com.cn"
APP="/Applications/DSH Desktop.app"

if [ "$(id -u)" != 0 ]; then echo "请用 sudo 运行"; exit 1; fi

undo() {
  if grep -q "$MARK" "$HOSTS"; then
    cp "$HOSTS" "$HOSTS.bak-jiufeng-$(date +%Y%m%d-%H%M%S)"
    sed -i '' "/$MARK/d;/^127\.0\.0\.1 $DOMAIN$/d" "$HOSTS"
    dscacheutil -flushcache 2>/dev/null || true
    echo "✅ 已撤销黑洞（hosts 已备份）"
  else
    echo "没有本脚本写入的条目，无需撤销"
  fi
  exit 0
}
[ "${1:-}" = "--undo" ] && undo

# 1. hosts 黑洞（幂等）
if grep -q "^127\.0\.0\.1 $DOMAIN$" "$HOSTS"; then
  echo "OK  $DOMAIN 已在黑洞中"
else
  cp "$HOSTS" "$HOSTS.bak-jiufeng-$(date +%Y%m%d-%H%M%S)"
  printf '%s %s\n%s\n' "127.0.0.1" "$DOMAIN" "$MARK 切断遥测/更新（撤销: sudo ./harden-macos.sh --undo）" >> "$HOSTS"
  dscacheutil -flushcache 2>/dev/null || true
  echo "OK  已黑洞化 $DOMAIN（hosts 已备份）"
fi

# 2. 签名完整性
if codesign -v --deep "$APP" 2>/dev/null && spctl -a -qq "$APP" 2>/dev/null; then
  echo "OK  DSH Desktop 签名与公证完整（未被篡改）"
else
  echo "!!  DSH Desktop 签名校验未通过 —— 建议从官方 DMG 重装"
fi

# 3. 生效验证
if [ "$(dscacheutil -q host -a name $DOMAIN | awk '/ip_address/{print $2; exit}')" = "127.0.0.1" ]; then
  echo "OK  DNS 解析已指向 127.0.0.1，遥测/更新通道已切断"
else
  echo "!!  DNS 缓存可能未刷新，重启 DSH 后生效"
fi
