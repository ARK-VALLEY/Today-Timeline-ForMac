#!/bin/bash
# 一键构建「今日时间线.app」
set -euo pipefail
cd "$(dirname "$0")"

APP="build/今日时间线.app"
BIN="$APP/Contents/MacOS/TodayTimeline"

rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" build/modulecache build/tmp

# 把编译缓存与临时目录重定向到项目内，避免系统临时目录的写入限制
export TMPDIR="$PWD/build/tmp"

echo "==> 编译 ObjC shim（Touch Bar 私有 API 封装）…"
xcrun clang -fobjc-arc -fmodules -fmodules-cache-path="$PWD/build/modulecache" \
  -mmacosx-version-min=14.0 \
  -c Sources/Shim/DFRShim.m -o build/DFRShim.o

echo "==> 编译主程序…"
swiftc -O -parse-as-library -swift-version 5 \
  -module-cache-path "$PWD/build/modulecache" \
  -target "$(uname -m)-apple-macosx14.0" \
  -import-objc-header Sources/Shim/DFRShim.h \
  Sources/AppMain.swift \
  Sources/CalendarModel.swift \
  Sources/Helpers.swift \
  Sources/PanelView.swift \
  Sources/SettingsView.swift \
  Sources/FloatingWindow.swift \
  Sources/Reminders.swift \
  Sources/TouchBar.swift \
  Sources/TouchBarManager.swift \
  build/DFRShim.o \
  -framework AppKit \
  -framework SwiftUI \
  -framework EventKit \
  -framework UserNotifications \
  -framework ServiceManagement \
  -framework ApplicationServices \
  -o "$BIN"

echo "==> 生成应用图标…"
swiftc -O -module-cache-path "$PWD/build/modulecache" IconGen/main.swift -o build/icongen
build/icongen build/icon_cream_1024.png cream
build/icongen build/icon_dark_1024.png dark

# 默认使用奶油色（Claude 风格）；深色版作为备选预览
mkdir -p "图标预览"
cp build/icon_cream_1024.png "图标预览/奶油色-Claude风格.png"
cp build/icon_dark_1024.png "图标预览/深空黑-macOS风格.png"

mkdir -p build/icons.iconset
for s in 16 32 128 256 512; do
  sips -z "$s" "$s" build/icon_cream_1024.png --out "build/icons.iconset/icon_${s}x${s}.png" >/dev/null
  d=$((s * 2))
  sips -z "$d" "$d" build/icon_cream_1024.png --out "build/icons.iconset/icon_${s}x${s}@2x.png" >/dev/null
done
iconutil -c icns build/icons.iconset -o "$APP/Contents/Resources/AppIcon.icns"

echo "==> 打包与签名…"
cp Info.plist "$APP/Contents/Info.plist"
xattr -cr "$APP" 2>/dev/null || true
# 签名失败（残留扩展属性）时清理后重试一次
codesign --force --sign - "$APP" 2>/dev/null || {
  xattr -cr "$APP" 2>/dev/null || true
  codesign --force --sign - "$APP"
}

echo "==> 完成：$APP"
