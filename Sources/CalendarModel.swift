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

final class CalendarModel: ObservableObject {
    @Published var accessDetermined = false
    @Published var accessGranted = false
    @Published var events: [TimelineEvent] = []
    @Published var calendars: [EKCalendar] = []
    @Published var visibleCalendarIDs: Set<String> = []
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

        // 每 60 秒自动刷新一次
        Timer.publish(every: 60, on: .main, in: .common).autoconnect()
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        // 日历发生变化（如在「日历」App 中增删日程）时自动刷新
        NotificationCenter.default.publisher(for: .EKEventStoreChanged)
            .debounce(for: .seconds(1.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
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

    func loadCalendars() {
        calendars = store.calendars(for: .event)
            .sorted { ($0.source?.title ?? "") < ($1.source?.title ?? "") }
        let ids = Set(calendars.map(\.calendarIdentifier))
        if let saved = UserDefaults.standard.array(forKey: Keys.visible) as? [String] {
            visibleCalendarIDs = Set(saved).intersection(ids)
            if visibleCalendarIDs.isEmpty { visibleCalendarIDs = ids }
        } else {
            visibleCalendarIDs = ids
        }
    }

    func setVisible(_ calendar: EKCalendar, _ on: Bool) {
        if on {
            visibleCalendarIDs.insert(calendar.calendarIdentifier)
        } else {
            visibleCalendarIDs.remove(calendar.calendarIdentifier)
        }
        UserDefaults.standard.set(Array(visibleCalendarIDs), forKey: Keys.visible)
        refresh()
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

    /// 在系统「日历」App 中打开某个日程
    func openInCalendar(_ e: TimelineEvent) {
        if let id = e.event.eventIdentifier,
           let encoded = id.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
           let url = URL(string: "x-apple-calevent://" + encoded),
           NSWorkspace.shared.open(url) {
            return
        }
        if let url = URL(string: "x-apple-calendar://") {
            NSWorkspace.shared.open(url)
        }
    }

    private func rescheduleReminders() {
        ReminderCenter.shared.reschedule(events: events, minutes: reminderMinutes)
    }
}
