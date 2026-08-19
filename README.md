# 今日时间线 · Today Timeline

A lightweight macOS menu bar app that turns your local Calendar events into a **live countdown timeline** — on the menu bar, in a dropdown panel, on a floating desktop widget, and persistently on the **Touch Bar**.

Native Swift + SwiftUI. Zero third-party dependencies. A single binary (~700 KB).

## Features

- **Menu bar**: icon + full event name + live countdown, in one line. Countdown color is configurable: light / dark / the event's calendar color.
- **Dropdown panel**: a "now / next" status card with progress bar, plus a full timeline of today's events (past events greyed out, all-day events grouped).
- **Floating widget** (optional): a draggable, translucent always-on-top card showing the current event and countdown.
- **Touch Bar (persistent)**: uses the same system-modal presentation technique as [LyricsX](https://github.com/ddddxxx/LyricsX), so the schedule stays on the Touch Bar no matter which app is frontmost. Card-style UI with progress bar, "next event" card, an `esc` button, and center/left alignment options.
- **Reminders**: system notification 5/10/15/30 minutes before an event starts.
- **Calendar filtering** with native calendar colors; click an event to reveal it in Apple Calendar.
- Auto refresh, dark/light mode, launch at login, click Touch Bar cards to open the floating widget.

## Requirements

- macOS 14+ (Touch Bar features require a MacBook Pro with Touch Bar)
- Xcode Command Line Tools (`xcode-select --install`) — no full Xcode needed

## Build

```bash
./build.sh
```

Produces `build/今日时间线.app`. Drag it to `/Applications` to install.

## Permissions

- **Calendar**: the app asks for calendar access on first launch (required to read your events).
- **Accessibility** (optional): only needed if you press the `esc` button on the Touch Bar — macOS requires it for apps that synthesize keyboard events.

## Notes

- The persistent Touch Bar relies on private system-modal APIs, exactly like LyricsX. All private calls are guarded with `respondsToSelector`/`dlsym` checks — if a future macOS removes them, the app degrades gracefully and everything else keeps working.
- The menu bar label uses `NSStatusItem` + `NSHostingView` instead of SwiftUI's `MenuBarExtra`, because `MenuBarExtra` cannot reliably display wide dynamic text (full event name + countdown).

## Credits

The Touch Bar system-modal wrappers under `Sources/Shim/` follow the approach of
[dddddxxx/TouchBarHelper](https://github.com/ddddxxx/TouchBarHelper) and [dddddxxx/LyricsX](https://github.com/ddddxxx/LyricsX) (both MPL-2.0). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## License

MIT — see [LICENSE](LICENSE). Files under `Sources/Shim/` are MPL-2.0.

---

## 中文说明

「今日时间线」是一个 macOS 菜单栏应用：读取系统日历，在菜单栏显示「图标 + 日程名称 + 实时倒计时」，下拉面板展示今日时间线，并可让日程信息（含进度条）**常驻 Touch Bar**（与歌词应用 LyricsX 相同的系统级实现）。

- 构建：安装 Xcode 命令行工具后执行 `./build.sh`，产物为 `build/今日时间线.app`，拖入「应用程序」即可。
- 首次运行需允许日历访问；Touch Bar 上的 esc 按钮首次使用需允许辅助功能权限。
- 完整使用说明见 [使用说明.md](使用说明.md)。
- 许可证：MIT（`Sources/Shim/` 下两个文件为 MPL-2.0，出处见 THIRD_PARTY_NOTICES.md）。
