import Foundation
import UserNotifications

/// 日程开始前 N 分钟的系统通知
final class ReminderCenter {
    static let shared = ReminderCenter()
    private var authorized = false

    private init() {}

    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.authorized = granted
            }
        }
    }

    func reschedule(events: [TimelineEvent], minutes: Int) {
        guard authorized else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        guard minutes > 0 else { return }

        let now = Date()
        let cal = Calendar.current
        for e in events where !e.isAllDay && e.start > now {
            let fire = e.start.addingTimeInterval(-Double(minutes) * 60)
            guard fire > now.addingTimeInterval(30) else { continue }

            let content = UNMutableNotificationContent()
            content.title = e.title
            content.body = "\(Fmt.time.string(from: e.start)) 开始 · \(e.calendarName)"
            content.sound = .default

            var comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            comps.second = 0
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: "tt-\(e.id)", content: content, trigger: trigger)
            center.add(request)
        }
    }
}
