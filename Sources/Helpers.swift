import Foundation

enum Fmt {
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "HH:mm"
        return f
    }()

    static let dateHeader: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEEE"
        return f
    }()
}

func hhmm(_ d: Date) -> String {
    Fmt.time.string(from: d)
}

enum Countdown {
    /// 把剩余秒数格式化成 "12:34" 或 "1:02:34"
    static func string(from: Date, to: Date) -> String {
        let s = max(0, Int(to.timeIntervalSince(from).rounded()))
        let h = s / 3600
        let m = (s % 3600) / 60
        let sec = s % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, sec) }
        return String(format: "%02d:%02d", m, sec)
    }
}

func durationText(_ start: Date, _ end: Date) -> String {
    let m = Int(end.timeIntervalSince(start) / 60)
    if m <= 0 { return "" }
    if m < 60 { return "\(m) 分钟" }
    if m % 60 == 0 { return "\(m / 60) 小时" }
    return "\(m / 60) 小时 \(m % 60) 分钟"
}
