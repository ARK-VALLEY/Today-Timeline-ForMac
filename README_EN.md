# Today Timeline · 今日时间线

[![中文](https://img.shields.io/badge/中文-切换-555555)](README.md)
[![English](https://img.shields.io/badge/English-✓Current-FF9F0A)](README_EN.md)

> **Today Timeline** is a **native macOS schedule countdown plugin**. It automatically reads your daily events from the system calendar and shows live countdowns on the **menu bar**, a **floating widget**, and the **Touch Bar**.

Native Swift + SwiftUI. Zero third-party dependencies. A single binary (~700 KB).

## 📦 Download & Install

[![Download latest](https://img.shields.io/badge/Download-latest-FF9F0A)](https://github.com/ARK-VALLEY/today-timeline/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/ARK-VALLEY/today-timeline/total)](https://github.com/ARK-VALLEY/today-timeline/releases)

1. Download the latest `TodayTimeline-*.zip` from the [Releases page](https://github.com/ARK-VALLEY/today-timeline/releases);
2. Unzip and drag 今日时间线 into `/Applications`, then open it;
3. **First launch may be blocked** (the app is locally built and not notarized by Apple): right-click the app → Open → Open again; or run
   `xattr -dr com.apple.quarantine /Applications/今日时间线.app`;
4. Allow Calendar access on first launch.

> Requirements: macOS 14+; Touch Bar features require a MacBook Pro with Touch Bar. Apple Silicon runs via Rosetta 2. You can also build it yourself: `./build.sh`.

## ✨ Features

- **Menu bar**: icon + full event name + live countdown, in one line. Countdown color is configurable: light / dark / the event's calendar color.
- **Dropdown panel**: a "now / next" status card with a progress bar, plus a full timeline of today's events (past events greyed out, all-day events grouped).
- **Floating widget** (optional): a draggable, translucent always-on-top card showing the current event and countdown.
- **Touch Bar (persistent)**: uses the same system-modal presentation technique as [LyricsX](https://github.com/ddddxxx/LyricsX), so the schedule stays on the Touch Bar no matter which app is frontmost. Card-style UI with a progress bar, a "next event" card, an `esc` button, and center/left alignment options.
- **Reminders**: system notification 5 / 10 / 15 / 30 minutes before an event starts.
- **Calendar filtering** with native calendar colors; click an event to reveal it in Apple Calendar.
- Auto refresh, dark/light mode, launch at login, click Touch Bar cards to open the floating widget.

## 📋 Requirements

- macOS 14+ (Touch Bar features require a MacBook Pro with Touch Bar)
- Xcode Command Line Tools (`xcode-select --install`) — no full Xcode needed

## 🔨 Build

```bash
./build.sh
```

Produces `build/今日时间线.app`. Drag it to `/Applications` to install.

## 🔐 Permissions

- **Calendar**: the app asks for calendar access on first launch (required to read your events).
- **Accessibility** (optional): only needed if you press the `esc` button on the Touch Bar — macOS requires it for apps that synthesize keyboard events.

## ⚠️ Notes

- The persistent Touch Bar relies on private system-modal APIs, exactly like LyricsX. All private calls are guarded with `respondsToSelector` / `dlsym` checks — if a future macOS removes them, the app degrades gracefully and everything else keeps working.
- The menu bar label uses `NSStatusItem` + `NSHostingView` instead of SwiftUI's `MenuBarExtra`, because `MenuBarExtra` cannot reliably display wide dynamic text (full event name + countdown).

## 🙏 Credits

The Touch Bar system-modal wrappers under `Sources/Shim/` follow the approach of [dddddxxx/TouchBarHelper](https://github.com/ddddxxx/TouchBarHelper) and [dddddxxx/LyricsX](https://github.com/ddddxxx/LyricsX) (both MPL-2.0). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## 📄 License

MIT — see [LICENSE](LICENSE). Files under `Sources/Shim/` are MPL-2.0.

## 📖 Docs

Full user manual (Chinese): [使用说明.md](使用说明.md).
