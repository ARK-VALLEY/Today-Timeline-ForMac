import AppKit
import SwiftUI
import ApplicationServices

/// Touch Bar 常驻管理：采用与 LyricsX 相同的系统级模态方案，
/// 让日程信息在 Touch Bar 上常驻显示，不受前台应用切换影响。
final class TouchBarManager {
    static let shared = TouchBarManager()

    private var model: CalendarModel?
    private var attached = false

    private var touchBar: NSTouchBar?
    private var mainItem: NSCustomTouchBarItem?
    private var trayItem: NSCustomTouchBarItem?
    private var trayAdded = false
    private(set) var presented = false

    enum Keys {
        static let enabled = "touchBarEnabled"
        static let showCurrent = "touchBarShowCurrent"
        static let showNext = "touchBarShowNext"
        static let alignment = "touchBarAlignment"   // 0 居中，1 靠左
    }

    /// 默认开启的开关项
    static var enabled: Bool { defaultTrue(Keys.enabled) }
    static var showCurrent: Bool { defaultTrue(Keys.showCurrent) }
    static var showNext: Bool { defaultTrue(Keys.showNext) }
    static var alignment: Int {
        UserDefaults.standard.object(forKey: Keys.alignment) as? Int ?? 0
    }

    private static func defaultTrue(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) == nil
            ? true
            : UserDefaults.standard.bool(forKey: key)
    }

    private init() {}

    func attach(model: CalendarModel) {
        self.model = model
        guard !attached else { return }
        attached = true
        build()
        sync()
    }

    private func build() {
        guard let model else { return }

        // 主内容：进行中 / 下一项日程卡片
        let mainID = NSTouchBarItem.Identifier("tt.touchbar.main")
        let main = NSCustomTouchBarItem(identifier: mainID)
        let host = NSHostingView(rootView: TouchBarStatusView().environmentObject(model))
        host.frame = NSRect(x: 0, y: 0, width: 720, height: 30)
        main.view = host
        mainItem = main

        // esc 键：点击向系统发送真实 Esc 键事件
        let escID = NSTouchBarItem.Identifier("tt.touchbar.esc")
        let esc = NSCustomTouchBarItem(identifier: escID)
        let escButton = NSButton(title: "esc", target: self, action: #selector(escapeTapped))
        escButton.bezelStyle = .texturedRounded
        esc.view = escButton
        esc.visibilityPriority = .high

        // 系统托盘按钮：点击收起 / 重新显示
        let trayID = NSTouchBarItem.Identifier("tt.touchbar.tray")
        let tray = NSCustomTouchBarItem(identifier: trayID)
        let button = NSButton(
            image: NSImage(systemSymbolName: "calendar.day.timeline.left", accessibilityDescription: "今日时间线") ?? NSImage(),
            target: self,
            action: #selector(trayTapped)
        )
        tray.view = button
        trayItem = tray

        let bar = NSTouchBar()
        bar.defaultItemIdentifiers = [escID, .fixedSpaceSmall, mainID, .flexibleSpace]
        bar.principalItemIdentifier = mainID
        bar.templateItems = [main, esc]
        touchBar = bar
    }

    @objc private func escapeTapped() {
        // 需要辅助功能权限才能向系统发送键盘事件；未授权时先弹出系统授权框
        if !AXIsProcessTrusted() {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        }
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 53, keyDown: true)   // kVK_Escape
        let up = CGEvent(keyboardEventSource: src, virtualKey: 53, keyDown: false)
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    @objc private func trayTapped() {
        if presented {
            minimize()
        } else {
            present()
        }
    }

    /// 根据设置同步呈现状态
    func sync() {
        if Self.enabled {
            present()
        } else {
            dismiss()
        }
    }

    func present() {
        guard let touchBar, let trayItem else { return }
        if !trayAdded {
            trayItem.addToSystemTray()
            trayAdded = true
        }
        trayItem.setControlStripPresence(true)
        NSTouchBar.ttSetSystemModalShowsCloseBox(whenFrontMost: false)
        touchBar.ttPresentAsSystemModal(forItemIdentifier: trayItem.identifier.rawValue)
        presented = true
    }

    func minimize() {
        guard let touchBar else { return }
        touchBar.ttMinimizeSystemModal()
        presented = false
    }

    func dismiss() {
        guard let touchBar, let trayItem else { return }
        touchBar.ttDismissSystemModal()
        if trayAdded {
            trayItem.setControlStripPresence(false)
            trayItem.removeFromSystemTray()
            trayAdded = false
        }
        presented = false
    }
}
