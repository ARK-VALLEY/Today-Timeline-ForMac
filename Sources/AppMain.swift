import SwiftUI
import AppKit
import Combine

@main
struct TodayTimelineApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings { EmptyView() }
    }
}

/// 用 NSStatusItem + NSHostingView 承载菜单栏标签（宽度完全可控，
/// 保证「图标 + 名称全称 + 倒计时」完整显示），下拉面板用 NSPopover 呈现。
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: CalendarModel!
    private var statusItem: NSStatusItem!
    private var labelHost: NSHostingView<AnyView>!
    private var popover: NSPopover!
    private var sizeTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastLabelWidth: CGFloat = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = CalendarModel()
        FloatingWindow.shared.attach(model: model)
        TouchBarManager.shared.attach(model: model)

        // 菜单栏条目
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            let label = MenuBarLabel { [weak self] in self?.togglePopover() }
                .environmentObject(model)
            labelHost = NSHostingView(rootView: AnyView(label))
            labelHost.frame = NSRect(x: 0, y: 0, width: 120, height: button.bounds.height)
            labelHost.autoresizingMask = [.width, .height]
            button.addSubview(labelHost)
            refreshLabelSize()
        }

        // 显示模式变化时，等内容重绘完成后再刷新宽度，避免读到旧内容宽度
        model.$menuBarMode
            .sink { [weak self] _ in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self?.refreshLabelSize() }
            }
            .store(in: &cancellables)

        // 下拉面板
        let pop = NSPopover()
        pop.behavior = .transient
        let controller = NSHostingController(rootView: PanelView().environmentObject(model))
        controller.sizingOptions = .preferredContentSize
        pop.contentViewController = controller
        popover = pop

        // 每秒按内容理想宽度检查一次（倒计时跨格式时宽度会变化）
        sizeTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.refreshLabelSize() }
        }
    }

    /// 测量前先把视图放宽，确保拿到内容的真实理想宽度（防止被上一次的窄边框锁死）；
    /// 仅在宽度真正变化时才更新条目长度——避免每秒触发整个菜单栏重排（卡顿来源）。
    private func refreshLabelSize() {
        guard let button = statusItem.button else { return }
        let h = button.bounds.height > 0 ? button.bounds.height : 22
        labelHost.frame = NSRect(x: 0, y: 0, width: 2000, height: h)
        let ideal = labelHost.fittingSize
        let width = min(max(ideal.width, 30), 600)
        labelHost.frame = NSRect(x: 0, y: 0, width: width, height: h)
        if abs(width - lastLabelWidth) > 0.5 {
            lastLabelWidth = width
            statusItem.length = width
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}

/// 菜单栏常驻内容：图标 / 倒计时 / 名称 按设置组合
struct MenuBarLabel: View {
    @EnvironmentObject var model: CalendarModel
    var onTap: (() -> Void)? = nil
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            switch model.menuBarMode {
            case 1:
                Text(model.menuBarText(now: now))
                    .monospacedDigit()
                    .foregroundStyle(countdownColor)
            case 2:
                HStack(spacing: 4) {
                    Image(systemName: "calendar.day.timeline.left")
                    Text(model.menuBarText(now: now))
                        .monospacedDigit()
                        .foregroundStyle(countdownColor)
                }
            case 3:
                HStack(spacing: 5) {
                    Image(systemName: "calendar.day.timeline.left")
                        .fixedSize()
                    let title = model.menuBarTitle(now: now)
                    if !title.isEmpty {
                        Text(title)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    Text(model.menuBarText(now: now))
                        .monospacedDigit()
                        .foregroundStyle(countdownColor)
                        .fixedSize()
                        .layoutPriority(1)
                }
            default:
                Image(systemName: "calendar.day.timeline.left")
            }
        }
        .onReceive(timer) { now = $0 }
        .contentShape(Rectangle())
        .onTapGesture { onTap?() }
    }

    /// 倒计时颜色：浅色 / 深色 / 日程所属日历颜色
    /// 使用固定灰阶（不依赖系统语义色），避免在菜单栏宿主视图中被反向解析
    private var countdownColor: AnyShapeStyle {
        switch model.countdownColorMode {
        case 1:
            return AnyShapeStyle(Color(white: 0.18))   // 深色
        case 2:
            let (current, next) = model.status(at: now)
            if let c = current { return AnyShapeStyle(c.color) }
            if let n = next { return AnyShapeStyle(n.color) }
            return AnyShapeStyle(Color(white: 0.18))
        default:
            return AnyShapeStyle(Color(white: 0.62))   // 浅色
        }
    }
}
