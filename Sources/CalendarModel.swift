import Foundation
import EventKit
import Combine
import SwiftUI
import AppKit

struct TimelineEvent: Identifiable {
    let id: String
    let event: EKEvent
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let location: String?
    let color: Color
    let calendarName: String
}

/// 按账户来源分组的日历列表
struct CalendarGroup: Identifiable {
    let id: String          // 来源标识（账户）
    let title: String       // 账户名称
    let typeLabel: String   // 账户类型：iCloud / Google / Exchange…
    let icon: String        // 类型图标（SF Symbol）
    let calendars: [EKCalendar]
}

final class CalendarModel: ObservableObject {
    @Published var accessDetermined = false
    @Published var accessGranted = false
    @Published var events: [TimelineEvent] = []
    @Published var calendars: [EKCalendar] = []
    @Published var calendarGroups: [CalendarGroup] = []
    @Published var visibleCalendarIDs: Set<String> = []
    /// 用户显式关闭的日历（用「隐藏列表」而非「可见列表」，新增日历默认自动显示）
    private var hiddenCalendarIDs: Set<String> = []
    @Published var reminderMinutes: Int = 10 {
        didSet {
            UserDefaults.standard.set(reminderMinutes, forKey: Keys.reminderMinutes)
            rescheduleReminders()
        }
    }
    @Published var menuBarMode: Int = 2 {
        didSet { UserDefaults.standard.set(menuBarMode, forKey: Keys.menuBarMode) }
    }
    /// 菜单栏倒计时颜色：0 浅色，1 深色，2 日历颜色
    @Published var countdownColorMode: Int = 0 {
        didSet { UserDefaults.standard.set(countdownColorMode, forKey: Keys.countdownColorMode) }
    }

    let store = EKEventStore()
    private var cancellables = Set<AnyCancellable>()

    enum Keys {
        static let visible = "visibleCalendarIDs"
        static let hidden = "hiddenCalendarIDs"
        static let reminderMinutes = "reminderMinutes"
        static let menuBarMode = "menuBarMode"
        static let menuBarModeMigrated = "menuBarModeMigrated"
        static let floatingEnabled = "floatingEnabled"
        static let countdownColorMode = "countdownColorMode"
    }

    init() {
        reminderMinutes = UserDefaults.standard.object(forKey: Keys.reminderMinutes) as? Int ?? 10
        // 旧版本默认是「图标 + 倒计时」(2)，新版本默认升级为「图标 + 名称 + 倒计时」(3)，迁移一次
        if let stored = UserDefaults.standard.object(forKey: Keys.menuBarMode) as? Int {
            if stored == 2 && !UserDefaults.standard.bool(forKey: Keys.menuBarModeMigrated) {
                menuBarMode = 3
                UserDefaults.standard.set(true, forKey: Keys.menuBarModeMigrated)
            } else {
                menuBarMode = stored
            }
        } else {
            menuBarMode = 3
        }
        countdownColorMode = UserDefaults.standard.object(forKey: Keys.countdownColorMode) as? Int ?? 0

        // 每 60 秒自动刷新一次（同时重载账户列表，覆盖账户改名等变化）
        Timer.publish(every: 60, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in
                self?.loadCalendars()
                self?.refresh()
            }
            .store(in: &cancellables)

        // 日历数据库变化（增删日程、账户增删改名等）时立即重载列表并刷新
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadCalendars()
                self?.refresh()
            }
            .store(in: &cancellables)

        requestAccess()
    }

    func requestAccess() {
        if #available(macOS 14.0, *) {
            store.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.handleAccess(granted: granted)
                }
            }
        } else {
            store.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.handleAccess(granted: granted)
                }
            }
        }
    }

    private func handleAccess(granted: Bool) {
        accessDetermined = true
        accessGranted = granted
        if granted {
            loadCalendars()
            refresh()
            ReminderCenter.shared.requestAuthorization()
        }
    }

    /// 重载日历账户列表（实时同步：账户增删、改名、新增日历都会反映在这里），
    /// 并按账户来源分组（iCloud / Google / Exchange / 我的 Mac / 生日 / 订阅）。
    func loadCalendars() {
        store.refreshSourcesIfNecessary()
        let cals = store.calendars(for: .event)
        calendars = cals
        let ids = Set(cals.map(\.calendarIdentifier))

        // 一次性迁移：旧的「可见列表」转成「隐藏列表」
        if UserDefaults.standard.object(forKey: Keys.hidden) == nil,
           let savedVisible = UserDefaults.standard.array(forKey: Keys.visible) as? [String] {
            hiddenCalendarIDs = ids.subtracting(Set(savedVisible))
        } else {
            hiddenCalendarIDs = Set(UserDefaults.standard.stringArray(forKey: Keys.hidden) ?? [])
        }
        // 清理已不存在的日历 id；新增日历不在隐藏列表中 → 默认自动显示
        hiddenCalendarIDs = hiddenCalendarIDs.intersection(ids)
        persistHidden()
        visibleCalendarIDs = ids.subtracting(hiddenCalendarIDs)

        // 按来源（账户）分组
        var bySource: [String: [EKCalendar]] = [:]
        var sources: [EKSource] = []
        var seenSources = Set<String>()
        for cal in cals {
            if let src = cal.source {
                if !seenSources.contains(src.sourceIdentifier) {
                    seenSources.insert(src.sourceIdentifier)
                    sources.append(src)
                }
                bySource[src.sourceIdentifier, default: []].append(cal)
            } else {
                bySource["__none__", default: []].append(cal)
            }
        }
        var groups: [CalendarGroup] = sources.map { src in
            let info = typeInfo(for: src)
            return CalendarGroup(
                id: src.sourceIdentifier,
                title: src.title,
                typeLabel: info.label,
                icon: info.icon,
                calendars: (bySource[src.sourceIdentifier] ?? [])
                    .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
            )
        }
        groups.sort {
            if $0.typeLabel == $1.typeLabel {
                return $0.title.localizedCompare($1.title) == .orderedAscending
            }
            return $0.typeLabel.localizedCompare($1.typeLabel) == .orderedAscending
        }
        if let extra = bySource["__none__"], !extra.isEmpty {
            groups.append(CalendarGroup(id: "__none__", title: "其他", typeLabel: "其他", icon: "calendar", calendars: extra))
        }
        calendarGroups = groups
    }

    func setVisible(_ calendar: EKCalendar, _ on: Bool) {
        if on {
            hiddenCalendarIDs.remove(calendar.calendarIdentifier)
        } else {
            hiddenCalendarIDs.insert(calendar.calendarIdentifier)
        }
        visibleCalendarIDs = Set(calendars.map(\.calendarIdentifier)).subtracting(hiddenCalendarIDs)
        persistHidden()
        refresh()
    }

    /// 账户类型标签与图标（按来源类型 + 名称推断）
    private func typeInfo(for source: EKSource) -> (label: String, icon: String) {
        switch source.sourceType {
        case .exchange:
            return ("Exchange", "envelope.fill")
        case .local:
            return ("我的 Mac", "desktopcomputer")
        case .birthdays:
            return ("生日", "birthday.cake.fill")
        case .subscribed:
            return ("订阅", "link")
        case .mobileMe:
            return ("iCloud", "cloud.fill")
        case .calDAV:
            let t = source.title.lowercased()
            if t.contains("icloud") { return ("iCloud", "cloud.fill") }
            if t.contains("google") || t.contains("gmail") { return ("Google", "g.circle.fill") }
            return ("CalDAV", "calendar")
        default:
            return ("其他", "calendar")
        }
    }

    private func persistHidden() {
        let existing = UserDefaults.standard.stringArray(forKey: Keys.hidden) ?? []
        if Set(existing) != hiddenCalendarIDs {
            UserDefaults.standard.set(Array(hiddenCalendarIDs), forKey: Keys.hidden)
        }
    }

    func refresh() {
        guard accessGranted else { return }
        store.refreshSourcesIfNecessary()

        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        guard let dayEnd = cal.date(byAdding: .day, value: 1, to: todayStart),
              let from = cal.date(byAdding: .day, value: -1, to: todayStart),
              let to = cal.date(byAdding: .day, value: 2, to: todayStart) else { return }

        let cals = store.calendars(for: .event)
            .filter { visibleCalendarIDs.contains($0.calendarIdentifier) }
        let predicate = store.predicateForEvents(withStart: from, end: to, calendars: cals)
        let fetched = store.events(matching: predicate)

        events = fetched
            .filter { $0.startDate < dayEnd && $0.endDate > todayStart }
            .map { e in
                TimelineEvent(
                    id: "\(e.eventIdentifier ?? UUID().uuidString)-\(Int(e.startDate.timeIntervalSince1970))",
                    event: e,
                    title: (e.title?.isEmpty == false) ? e.title! : "（无标题）",
                    start: e.startDate,
                    end: e.endDate,
                    isAllDay: e.isAllDay,
                    location: (e.location?.isEmpty == false) ? e.location : nil,
                    color: Color(cgColor: e.calendar.cgColor),
                    calendarName: e.calendar.title
                )
            }
            .sorted { $0.start < $1.start }

        rescheduleReminders()
    }

    /// 当前进行中的日程，与下一项日程
    func status(at now: Date) -> (current: TimelineEvent?, next: TimelineEvent?) {
        var current: TimelineEvent?
        for e in events where !e.isAllDay && e.start <= now && now < e.end {
            current = e
        }
        var next: TimelineEvent?
        for e in events where !e.isAllDay && e.start > now {
            next = e
            break
        }
        return (current, next)
    }

    /// 菜单栏文字：进行中显示剩余时间，空闲显示距离下一项的时间
    func menuBarText(now: Date) -> String {
        let (current, next) = status(at: now)
        if let c = current { return Countdown.string(from: now, to: c.end) }
        if let n = next { return "-" + Countdown.string(from: now, to: n.start) }
        return ""
    }

    /// 菜单栏日程名称：进行中日程优先，其次下一项
    func menuBarTitle(now: Date) -> String {
        let (current, next) = status(at: now)
        if let c = current { return c.title }
        if let n = next { return n.title }
        return ""
    }

    /// 在系统「日历」App 中打开某个日程。
    /// 全部操作在后台线程执行，绝不阻塞界面：
    /// 协议直达 → 立即打开日历 App → 后台脚本尽力定位到日程日期（限时 8 秒）
    func openInCalendar(_ e: TimelineEvent) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            // 1) 系统注册了协议时，直达具体日程
            if let id = e.event.eventIdentifier,
               let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
               let url = URL(string: "x-apple-calevent://" + encoded),
               NSWorkspace.shared.urlForApplication(toOpen: url) != nil {
                NSWorkspace.shared.open(url)
                return
            }
            // 2) 立即打开「日历」App（非阻塞，界面立刻有响应）
            self.openCalendarApp()
            // 3) 后台尽力定位到日程所在日期（最多等 8 秒，失败不影响）
            _ = self.openCalendarViewing(e.start)
        }
    }

    /// 用 AppleScript 让日历跳转到日程所在日期。
    /// 限时等待，防止日历冷启动 / 权限弹窗长时间拖住后台任务。
    private func openCalendarViewing(_ date: Date) -> Bool {
        let delta = Int(date.timeIntervalSinceNow)
        let script = "tell application \"Calendar\" to view calendar at ((current date) + \(delta))"
        let task = Process()
        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
        } catch {
            return false
        }
        let deadline = Date().addingTimeInterval(8)
        while task.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if task.isRunning {
            task.terminate()
            return false
        }
        return task.terminationStatus == 0
    }

    /// 通过 bundle id 直接启动「日历」App
    private func openCalendarApp() {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") else { return }
        let config = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, _ in }
    }

    private func rescheduleReminders() {
        ReminderCenter.shared.reschedule(events: events, minutes: reminderMinutes)
    }
}
