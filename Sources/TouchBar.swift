import SwiftUI

/// Touch Bar 常驻内容：两张卡片（当前日程 / 下一项日程），点击打开桌面浮窗
struct TouchBarStatusView: View {
    @EnvironmentObject var model: CalendarModel
    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        let s = model.status(at: now)
        let centered = TouchBarManager.alignment == 0

        Group {
            if !TouchBarManager.showCurrent && !TouchBarManager.showNext {
                Text("Touch Bar 显示已关闭")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            } else if let c = s.current, TouchBarManager.showCurrent {
                HStack(spacing: 8) {
                    // 当前日程卡优先：占满名称所需的完整宽度
                    currentCard(c)
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                    // 下一项日程卡：吃剩余空间，空间不足时优先被压缩
                    if TouchBarManager.showNext, let n = s.next {
                        nextCard(n)
                            .frame(maxWidth: 620)
                    }
                }
            } else if let n = s.next, TouchBarManager.showNext {
                HStack(spacing: 8) {
                    nextCard(n)
                        .frame(maxWidth: 620)
                }
            } else {
                Text("今日无日程")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: 720, maxHeight: 30, alignment: centered ? .center : .leading)
        .onReceive(timer) { now = $0 }
    }

    /// 当前日程卡片：标签 + 颜色点 + 名称 + 进度条 + 倒计时
    private func currentCard(_ e: TimelineEvent) -> some View {
        let total = e.end.timeIntervalSince(e.start)
        let progress = total > 0 ? min(1, max(0, now.timeIntervalSince(e.start) / total)) : 1
        return Button(action: { openFloating() }) {
            HStack(spacing: 5) {
                Text("当前日程")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Circle().fill(e.color).frame(width: 6, height: 6)
                Text(e.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.18))
                    Capsule().fill(e.color).frame(width: max(2, 52 * progress))
                }
                .frame(width: 52, height: 4)
                Text(Countdown.string(from: now, to: e.end))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(e.color.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(e.color.opacity(0.5), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    /// 下一项日程卡片：标签 + 颜色点 + 名称 + 开始时间
    private func nextCard(_ e: TimelineEvent) -> some View {
        Button(action: { openFloating() }) {
            HStack(spacing: 5) {
                Text("下一项日程")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                Circle().fill(e.color).frame(width: 6, height: 6)
                Text(e.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(hhmm(e.start))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
            }
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(e.color.opacity(0.10))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(e.color.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func openFloating() {
        UserDefaults.standard.set(true, forKey: CalendarModel.Keys.floatingEnabled)
        FloatingWindow.shared.setVisible(true)
    }
}
