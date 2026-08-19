import AppKit
import SwiftUI

/// 桌面置顶浮窗：显示当前进行中日程与倒计时
final class FloatingWindow {
    static let shared = FloatingWindow()
    private var panel: NSPanel?
    private var model: CalendarModel?
    private var attached = false

    private init() {}

    func attach(model: CalendarModel) {
        self.model = model
        guard !attached else { return }
        attached = true

        let card = FloatingCardView().environmentObject(model)
        let hosting = DraggableHostingView(rootView: card)
        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 190),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.isMovableByWindowBackground = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        p.hidesOnDeactivate = false
        p.contentView = hosting
        panel = p

        if UserDefaults.standard.bool(forKey: CalendarModel.Keys.floatingEnabled) {
            positionAndShow()
        }
    }

    func setVisible(_ visible: Bool) {
        guard let panel else { return }
        if visible {
            positionAndShow()
        } else {
            panel.orderOut(nil)
        }
    }

    private func positionAndShow() {
        guard let panel, let screen = NSScreen.main else { return }
        let vis = screen.visibleFrame
        panel.setFrameOrigin(
            NSPoint(x: vis.maxX - panel.frame.width - 24,
                    y: vis.maxY - panel.frame.height - 24)
        )
        panel.orderFrontRegardless()
    }
}

/// 让整个浮窗背景可以拖动窗口
final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }
}

struct FloatingCardView: View {
    @EnvironmentObject var model: CalendarModel
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let s = model.status(at: now)
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                if let c = s.current {
                    Label("进行中", systemImage: "clock.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(c.color)
                } else if let n = s.next {
                    Label("下一项", systemImage: "hourglass")
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(n.color)
                } else {
                    Label("空闲", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    UserDefaults.standard.set(false, forKey: CalendarModel.Keys.floatingEnabled)
                    FloatingWindow.shared.setVisible(false)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }

            if let c = s.current {
                Text(c.title)
                    .font(.headline)
                    .lineLimit(2)
                Text(Countdown.string(from: now, to: c.end))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                ProgressView(value: min(1, max(0, now.timeIntervalSince(c.start) / max(1, c.end.timeIntervalSince(c.start)))))
                    .tint(c.color)
            } else if let n = s.next {
                Text(n.title)
                    .font(.headline)
                    .lineLimit(2)
                (Text(Countdown.string(from: now, to: n.start))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .monospacedDigit()
                 + Text(" 后开始")
                    .font(.caption)
                    .foregroundStyle(.secondary))
            } else {
                Text("今日日程已全部结束")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(width: 320)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.1))
        )
        .onReceive(timer) { now = $0 }
    }
}
