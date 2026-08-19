# 今日时间线 · Today Timeline

[![中文](https://img.shields.io/badge/中文-✓当前-FF9F0A)](README.md)
[![English](https://img.shields.io/badge/English-切换-555555)](README_EN.md)

> 「今日时间线」是一个 **macOS 原生的日程倒计时插件**，可自动读取系统日历的每日日程信息，在**菜单栏**、**悬浮窗**及 **Touch Bar** 上实时显示日程倒计时。

纯 Swift + SwiftUI 原生实现，零第三方依赖，单一二进制文件（约 700 KB）。

## ✨ 功能

- **菜单栏**：一行显示「图标 + 日程名称全称 + 实时倒计时」；倒计时颜色可选浅色 / 深色 / 日程所属日历的颜色
- **下拉面板**：「当前 / 下一项」状态卡（含进度条）+ 今日完整时间线（已结束日程灰显、全天日程分组）
- **悬浮窗**（可选）：可拖动的半透明置顶小卡片，实时显示进行中日程与倒计时
- **Touch Bar（常驻）**：与 [LyricsX](https://github.com/ddddxxx/LyricsX) 相同的系统级实现，无论前台是哪个应用，日程卡片（当前日程含进度条、下一项日程、esc 键）始终常驻 Touch Bar
- **开始前提醒**：系统通知（提前 5 / 10 / 15 / 30 分钟可选）
- **日历筛选**：按账户 / 日历勾选，颜色与系统「日历」App 一致；点击日程可直接在日历 App 中定位该事件
- 深浅色自动适配、自动刷新、登录自启、点击 Touch Bar 卡片打开悬浮窗

## 📋 环境要求

- macOS 14+（Touch Bar 功能需要带 Touch Bar 的 MacBook Pro）
- Xcode 命令行工具（`xcode-select --install`），无需完整 Xcode

## 🔨 构建

```bash
./build.sh
```

产物为 `build/今日时间线.app`，拖入「应用程序」即可安装。

## 🔐 权限说明

- **日历**：首次启动需允许访问日历（用于读取日程）。
- **辅助功能**（可选）：仅当使用 Touch Bar 上的 esc 按钮时需要（macOS 要求模拟按键的应用获得该授权）。

## ⚠️ 注意事项

- Touch Bar 常驻依赖与 LyricsX 相同的私有系统级接口；所有私有调用均有 `respondsToSelector` / `dlsym` 防护，若未来 macOS 移除相关接口，应用会自动降级，其余功能不受影响。
- 菜单栏标签使用 `NSStatusItem` + `NSHostingView` 而非 SwiftUI 的 `MenuBarExtra`——后者无法可靠承载「完整日程名 + 倒计时」这类宽动态文本。

## 🙏 致谢

`Sources/Shim/` 下的 Touch Bar 封装参考了 [dddddxxx/TouchBarHelper](https://github.com/ddddxxx/TouchBarHelper) 与 [dddddxxx/LyricsX](https://github.com/ddddxxx/LyricsX)（均为 MPL-2.0），详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

## 📄 许可证

MIT —— 见 [LICENSE](LICENSE)。`Sources/Shim/` 下两个文件为 MPL-2.0。

## 📖 更多

完整使用说明见 [使用说明.md](使用说明.md)。
