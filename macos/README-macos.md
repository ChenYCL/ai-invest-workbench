# AI投研工作台 · macOS 版（本地化改造版）

Windows 官方只有 `Jiufeng-Invest-Setup-*.exe`。本目录把它移植到 macOS：
基座用官方 **DSH Desktop 2.0.13 universal DMG**（Notarized，SHA256 已对官方
`SHA256SUMS.txt` 核验），内容用 jiufeng-invest 仓库 v1.1.11 源码（已安全审计），
安装器复刻官方 `install.ps1` 的四层 playbook。

## 本地化改造（2026-10-29，改在仓库源 `~/Documents/mac-env-handle/jiufeng-invest`）

| 项 | 改动 |
|---|---|
| 品牌 | logo 换成自绘机器猫（PIL，`brand/`），「玖峰投研工作台」→「AI投研工作台」，全部文件零「玖峰」残留 |
| 遥测 | `JF_CONFIG.apiBase` 置空 → 使用上报 / 更新检查 / 强更弹窗在代码层短路（`no-endpoint` 分支） |
| 反馈上传 | 「设置→用户反馈」上传页整块移除（原本会把文字+截图 POST 到 report365） |
| 保留 | 东财/腾讯/雪球/新浪/凤凰行情接口（功能必需，只读公开数据）；股票搜索 JSONP |

实测：安装树 grep `玖峰|report365` = 0；DSH 运行时对 report365 连接数 = 0。
注意：改的是 client.js（生成产物）；若上游跑 `gen-client.mjs` 重新生成会被覆盖，需重打补丁。

## 已在本机完成

| 层 | 落点 | 状态 |
|---|---|---|
| 基座 | `/Applications/DSH Desktop.app` 2.0.13（Harness 0.1.5-rc.2，与插件 peer 匹配） | ✅ 签名+公证验证通过 |
| 1 插件 | `~/.dsh/jiufeng-plugins/` + profile `package.json` + `node_modules` 软链 | ✅ 零错误加载 |
| 2 预设 | `~/.dsh/.agent-presets/ai-finance`（105 个技能目录） | ✅ |
| 3 配置 | `settings.yaml` 默认预设 + `cordis.patch.yml` 6 条收窄 | ✅ |
| 4 图标 | `~/.dsh/icons`（仅用户目录） | ✅ |

界面已验证：侧边栏「玖峰投研工作台」7 工作流 + 专业工具分类，Agent =「AI金融投研」。

## 与 Windows 版的差异（刻意为之）

1. **不 patch .app 包**（Windows 版第 4 层的图标/品牌文案/splash/更新守卫）。
   macOS 改 .app 会破坏 notarized 签名 → Gatekeeper 直接拒启。
   更新防护改由 `harden-macos.sh`（hosts 黑洞）实现，见下。
2. **遥测默认关**：官方遥测默认开且会把旧版的手动关闭迁回开启；
   加强层直接把 `report365.com.cn` 黑洞化，上报/更新检查/反馈上传全部失效
   （代码里 fetch 失败均被 catch，不影响使用）。行情接口不受影响。
3. 旧版 `~/.dsh` 里 482 个指向已删除 npx 缓存的悬空软链，DSH 2.0.13 启动时已自愈。

## 文件

- `install-macos.sh` —— 安装器（幂等，`--dry-run` 预演，`--uninstall` 卸载；改动均带 `.bak-jiufeng-*` 备份）
- `harden-macos.sh` —— 安全加强（`sudo` 运行；`--undo` 撤销）：
  ① hosts 黑洞 `report365.com.cn`（等价 Windows 的受控更新守卫 + 关遥测）
  ② 校验 DSH 签名完整性
- `dl/` —— 官方 DMG（2.0.13 / 2.0.18）与校验文件、官方 plugin-only 包（v1.1.0，仅参考）

## 使用

1. 打开 DSH Desktop → 设置里填自己的模型 Key（DeepSeek/通义/智谱；本机已配 ai-oops 网关可跳过）
2. 建议跑一次：`sudo ./harden-macos.sh`
3. 联网搜索是可选增强：需要一把有余额的 DeepSeek Key 配进 DSH 设置

## 版本红线

- 基座必须停在 **2.0.13**（Harness 0.1.5-rc.2）。2.0.14+ 换 Harness 后插件 peer
  不匹配（2.0.18 = 0.2.1-rc.2，已实测 bundles 解析失败）；Beta 通道用 `~/.dsh-beta` 独立目录，勿装。
- 升级基座前先跑 `install-macos.sh --uninstall`，升级后重跑安装器。
- 官方 releases 已宣布 stable 通道将由 NEXT 取代 —— 冻结在 2.0.13 是当前的正确姿势。
