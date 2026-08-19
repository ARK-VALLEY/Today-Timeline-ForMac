import SwiftUI
import AppKit

struct PanelView: View {
    @EnvironmentObject var model: CalendarModel
    @State private var now = Date()
    @State private var showSettings = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if showSettings {
                SettingsView(onBack: { showSettings = false })
                    .environmentObject(model)
            } else {
                main
            }
        }
        .frame(width: 384)
        .onReceive(timer) { now = $0 }
    }

    private var main: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if !model.accessDetermined {
                statusBox(text: "正在等待日历授权…")
            } else if !model.accessGranted {
                deniedView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        NowCard(now: now)
                        if !allDayEvents.isEmpty {
                            AllDaySection(events: allDayEvents)
                        }
                        timelineSection
                    }
                    .padding(14)
                }
                .frame(maxHeight: 560)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Fmt.dateHeader.string(from: Date()))
                    .font(.headline)
                Text("今日时间线")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("刷新")
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .help("设置")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func statusBox(text: String) -> some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.small)
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }

    private var deniedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
            Text("未获得日历访问权限")
                .font(.headline)
            Text("请在系统设置中允许本应用访问日历")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("打开系统设置") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            Button("重新检查") { model.requestAccess() }
                .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity)
        .padding(30)
    }

    private var allDayEvents: [TimelineEvent] {
        model.events.filter { $0.isAllDay }
    }

    private var timedEvents: [TimelineEvent] {
        model.events.filter { !$0.isAllDay }
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("今日时间线")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(timedEvents.count) 项")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.bottom, 8)

            if timedEvents.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal")
                        .foregroundStyle(.secondary)
                    Text("今天没有日程安排")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
            } else {
                ForEach(timedEvents) { e in
                    EventRow(event: e, now: now)
                }
            }
        }
    }
}

/// 顶部「进行中 / 下一项 / 空闲」状态卡片
struct NowCard: View {
    @EnvironmentObject var model: CalendarModel
    let now: Date

    var body: some View {
        let s = model.status(at: now)
        if let current = s.current {
            currentCard(current, next: s.next)
        } else if let next = s.next {
            nextCard(next)
        } else {
            idleCard()
        }
    }

    private func currentCard(_ e: TimelineEvent, next: TimelineEvent?) -> some View {
        let total = e.end.timeIntervalSince(e.start)
        let progress = total > 0 ? min(1, max(0, now.timeIntervalSince(e.start) / total)) : 1
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("进行中", systemImage: "clock.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(e.color)
                Spacer()
                Text("\(hhmm(e.start)) – \(hhmm(e.end))")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text(e.title)
                .font(.headline)
                .lineLimit(2)
            if let loc = e.location, !loc.isEmpty {
                Label(loc, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Countdown.string(from: now, to: e.end))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("剩余")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .tint(e.color)
            if let n = next {
                Divider().opacity(0.6)
                HStack(spacing: 6) {
                    Label("下一项", systemImage: "hourglass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 4)
                    Text(n.title)
                        .font(.caption)
                        .lineLimit(1)
                    Text(Countdown.string(from: now, to: n.start))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(e.color.opacity(0.14))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(e.color)
                .frame(width: 4)
                .padding(.vertical, 12)
        }
    }

    private func nextCard(_ e: TimelineEvent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("下一项", systemImage: "hourglass")
                    .font(.system(size: 11, weight: .semibold))
                    .textCase(.uppercase)
                    .foregroundStyle(e.color)
                Spacer()
                Text(hhmm(e.start))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Text(e.title)
                .font(.headline)
                .lineLimit(2)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Countdown.string(from: now, to: e.start))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("后开始")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(e.color.opacity(0.10))
        )
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(e.color)
                .frame(width: 4)
                .padding(.vertical, 12)
        }
    }

    private func idleCard() -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("今日日程已全部结束")
                    .font(.callout.weight(.medium))
                Text("好好休息，或为明天做准备")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.quaternary.opacity(0.5))
        )
    }
}

/// 时间线中的一行日程
struct EventRow: View {
    @EnvironmentObject var model: CalendarModel
    let event: TimelineEvent
    let now: Date

    private var isCurrent: Bool {
        !event.isAllDay && event.start <= now && now < event.end
    }
    private var isPast: Bool {
        event.end <= now
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .trailing, spacing: 3) {
                Text(hhmm(event.start))
                    .font(.system(size: 11, weight: isCurrent ? .bold : .regular, design: .monospaced))
                    .foregroundStyle(isCurrent ? event.color : .secondary)
                Text(hhmm(event.end))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 44, alignment: .trailing)

            ZStack(alignment: .top) {
                Rectangle()
                    .fill(.quaternary.opacity(0.6))
                    .frame(width: 2)
                Circle()
                    .fill((isPast && !isCurrent) ? Color.secondary.opacity(0.45) : event.color)
                    .frame(width: 8, height: 8)
                    .offset(y: 4)
            }
            .frame(width: 10)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.callout.weight(isCurrent ? .semibold : .regular))
                        .foregroundStyle(isPast && !isCurrent ? .secondary : .primary)
                        .strikethrough(isPast && !isCurrent, color: .secondary)
                    if isCurrent {
                        Text("进行中")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(event.color.opacity(0.2))
                            .foregroundStyle(event.color)
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 8) {
                    if let loc = event.location {
                        Label(loc, systemImage: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Text(durationText(event.start, event.end))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
        .onTapGesture { model.openInCalendar(event) }
        .contextMenu {
            Button("在「日历」中打开") { model.openInCalendar(event) }
        }
    }
}

/// 全天日程
struct AllDaySection: View {
    let events: [TimelineEvent]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("全天")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ForEach(events) { e in
                HStack(spacing: 6) {
                    Circle().fill(e.color).frame(width: 6, height: 6)
                    Text(e.title).font(.callout)
                    Spacer()
                }
            }
        }
    }
}
