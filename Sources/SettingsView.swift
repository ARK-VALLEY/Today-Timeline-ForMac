import SwiftUI
import AppKit
import EventKit
import ServiceManagement

struct SettingsView: View {
    @EnvironmentObject var model: CalendarModel
    let onBack: () -> Void

    @State private var floatingOn = UserDefaults.standard.bool(forKey: CalendarModel.Keys.floatingEnabled)
    @State private var launchOn = SMAppService.mainApp.status == .enabled
    @State private var launchHint = false
    @State private var touchBarOn = TouchBarManager.enabled
    @State private var touchBarCurrent = TouchBarManager.showCurrent
    @State private var touchBarNext = TouchBarManager.showNext
    @State private var touchBarAlign = TouchBarManager.alignment

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)
                Text("设置")
                    .font(.headline)
                Spacer()
            }
            .padding(14)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    section("菜单栏显示") {
                        Picker("", selection: $model.menuBarMode) {
                            Text("仅图标").tag(0)
                            Text("仅倒计时").tag(1)
                            Text("图标 + 倒计时").tag(2)
                            Text("图标+名称+倒计时").tag(3)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()

                        VStack(alignment: .leading, spacing: 6) {
                            Text("倒计时颜色")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Picker("", selection: $model.countdownColorMode) {
                                Text("浅色").tag(0)
                                Text("深色").tag(1)
                                Text("日历颜色").tag(2)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                    }

                    section("日程提醒") {
                        Picker("", selection: $model.reminderMinutes) {
                            Text("关闭").tag(0)
                            Text("提前 5 分钟").tag(5)
                            Text("提前 10 分钟").tag(10)
                            Text("提前 15 分钟").tag(15)
                            Text("提前 30 分钟").tag(30)
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    section("桌面浮窗") {
                        Toggle("显示进行中日程浮窗", isOn: Binding(
                            get: { floatingOn },
                            set: { v in
                                floatingOn = v
                                UserDefaults.standard.set(v, forKey: CalendarModel.Keys.floatingEnabled)
                                FloatingWindow.shared.setVisible(v)
                            }
                        ))
                    }

                    section("Touch Bar") {
                        Toggle("在 Touch Bar 常驻显示日程", isOn: touchBarBinding(
                            TouchBarManager.Keys.enabled,
                            Binding(get: { touchBarOn }, set: { touchBarOn = $0 }),
                            syncOnChange: true
                        ))
                        Toggle("显示进行中日程", isOn: touchBarBinding(
                            TouchBarManager.Keys.showCurrent,
                            Binding(get: { touchBarCurrent }, set: { touchBarCurrent = $0 }),
                            syncOnChange: false
                        ))
                        .disabled(!touchBarOn)
                        Toggle("显示下一项日程", isOn: touchBarBinding(
                            TouchBarManager.Keys.showNext,
                            Binding(get: { touchBarNext }, set: { touchBarNext = $0 }),
                            syncOnChange: false
                        ))
                        .disabled(!touchBarOn)
                        Picker("", selection: Binding(
                            get: { touchBarAlign },
                            set: { v in
                                touchBarAlign = v
                                UserDefaults.standard.set(v, forKey: TouchBarManager.Keys.alignment)
                            }
                        )) {
                            Text("卡片居中").tag(0)
                            Text("卡片靠左").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .disabled(!touchBarOn)
                        Text("点击卡片可在桌面打开浮窗；常驻会替换其他应用的 Touch Bar 内容，Esc 由栏内最左侧的 esc 按钮提供（首次使用需允许辅助功能权限），点按 Control Strip 中的应用图标可收起或重新显示。")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    section("日历筛选") {
                        ForEach(model.calendars, id: \.calendarIdentifier) { cal in
                            Toggle(isOn: Binding(
                                get: { model.visibleCalendarIDs.contains(cal.calendarIdentifier) },
                                set: { v in model.setVisible(cal, v) }
                            )) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(Color(cgColor: cal.cgColor))
                                        .frame(width: 8, height: 8)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(cal.title).font(.callout)
                                        Text(cal.source?.title ?? "")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                        if model.calendars.isEmpty {
                            Text("暂无可用日历")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }

                    section("通用") {
                        Toggle("登录时自动启动", isOn: Binding(
                            get: { launchOn },
                            set: { v in
                                launchOn = v
                                do {
                                    if v {
                                        try SMAppService.mainApp.register()
                                    } else {
                                        try SMAppService.mainApp.unregister()
                                    }
                                    launchHint = v && SMAppService.mainApp.status == .requiresApproval
                                } catch {
                                    launchOn = SMAppService.mainApp.status == .enabled
                                    launchHint = false
                                }
                            }
                        ))
                        if launchHint {
                            Text("请在「系统设置 → 通用 → 登录项」中允许本应用")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Divider()

                    HStack {
                        Spacer()
                        Button("退出应用") { NSApp.terminate(nil) }
                            .buttonStyle(.plain)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.bottom, 8)
                }
                .padding(14)
            }
            .frame(maxHeight: 520)
        }
    }

    private func touchBarBinding(_ key: String, _ state: Binding<Bool>, syncOnChange: Bool) -> Binding<Bool> {
        Binding(
            get: { state.wrappedValue },
            set: { v in
                state.wrappedValue = v
                UserDefaults.standard.set(v, forKey: key)
                if syncOnChange { TouchBarManager.shared.sync() }
            }
        )
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}
