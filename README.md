# AI投研工作台（本地化改造版）

基于 [haiting202-web/jiufeng-invest](https://github.com/haiting202-web/jiufeng-invest) v1.1.11（commit `6ebae0f`）的**去品牌化 + 零遥测**改造，供个人私用。

## 相对上游的改动

| 项 | 说明 |
|---|---|
| 品牌 | logo 换为自绘机器猫（`macos/brand/`），「玖峰投研工作台」→「AI投研工作台」，全仓库零残留 |
| 遥测 | `dsh-ai-invest-sidebar/client/client.js` 的 `JF_CONFIG.apiBase` 置空 → 使用上报 / 更新检查 / 强更弹窗全部代码级短路 |
| 反馈上传 | 移除「设置→用户反馈」上传页注册（原会 POST 文字+截图到 report365.com.cn） |
| 模板同步 | `gen-client.mjs` 的 apiBase 同步置空，防止重新生成 client.js 时补丁回退 |
| macOS 移植 | `macos/` 目录：四层安装器（复刻官方 install.ps1 playbook）+ 安全加强脚本 + Windows 分发包 |

保留：东财/腾讯/雪球/新浪/凤凰公开行情接口（功能必需，只读）。

## 使用

- **macOS**：见 [`macos/README-macos.md`](./macos/README-macos.md)（基座 DSH Desktop 2.0.13，`macos/install-macos.sh`）
- **Windows**：`macos/dist/AI-Invest-Workbench-win-1.0.0.zip`，解压双击 `install.bat`

## 版本红线

基座必须冻结在 **DSH Desktop 2.0.10 ~ 2.0.13**（Harness 0.1.5-rc.2）；2.0.14+ / Beta / NEXT 不兼容，勿点应用内更新。

## 许可

MIT（上游同款）；上游版权归 haiting202-web，本仓库改动仅限个人使用。
