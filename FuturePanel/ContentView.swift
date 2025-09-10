//
//  ContentView.swift
//  FuturePanel
//
//  Created by rocky on 2025/9/8.
//

import SwiftUI
#if os(macOS)
import AppKit
#endif
import Combine
// import SwiftData

struct DemoConfig {
    static let channels: [ChannelEntry] = [
        .init(id: "events", path: "/events/app1", enabled: true)
    ]
}

struct ContentView: View {
    @EnvironmentObject private var settingsStore: SettingsStore

    @StateObject private var service = LogService()
    @State private var hoverToolbar: Bool = false
    @State private var keyword: String = ""
    @State private var filterMode: Bool = false // false提醒，true过滤
    @State private var lastNotifyAt: Date = .distantPast
    @State private var miniMode: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            // 顶部独立拖拽区域 + 关闭按钮
            HeaderBar(fontSize: settingsStore.settings.fontSize) {
                #if os(macOS)
                NSApp.hide(nil)
                #endif
            }
            .zIndex(8)

            let theme = ThemeName(rawValue: settingsStore.settings.theme) ?? .oneDark
            ZStack {
                let bgPreset = BackgroundPreset(rawValue: settingsStore.settings.background) ?? .graphiteBlack
                bgPreset.color
                ScrollViewReader { proxy in
                    List(filteredMessages()) { msg in
                    VStack(alignment: .leading, spacing: 4) {
                        // 仅使用 DSL 渲染，不再加默认前缀
                        let segments = TemplateEngine.renderSegments(
                            template: settingsStore.settings.defaultTemplate,
                            jsonString: msg.raw,
                            metaTimeString: msg.timeString,
                            id: msg.id,
                            path: msg.channel
                        )
                        styledText(from: segments, palette: ThemePalette.palette(for: theme, overrides: settingsStore.settings.themeOverrides), keyword: keyword)
                            .font(.custom(settingsStore.settings.fontFamily, size: settingsStore.settings.fontSize))
                            .textSelection(.enabled)
                    }
                    .listRowSeparator(.hidden)
                    .id(msg.id)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .onReceive(NotificationCenter.default.publisher(for: .logAggregatorNewMessage)) { _ in
                        let items = filteredMessages()
                        if let last = items.last {
                            DispatchQueue.main.async {
                                withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                            }
                        }
                    }
                }
            }
            // Keyword toolbar pinned to bottom-left
            .overlay(alignment: .bottomLeading) {
                if hoverToolbar {
                    HStack(spacing: 8) {
                        TextField("关键字…", text: $keyword)
                            .textFieldStyle(.plain)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 6)
                            .background(Color.clear)
                            .cornerRadius(6)
                            .frame(width: 260)
                        Toggle("过滤模式", isOn: $filterMode)
                        Image(systemName: "xmark.circle")
                            .onTapGesture { keyword = "" }
                    }
                    .padding(10)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .cornerRadius(10)
                    .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
                    .padding(.leading, 10)
                    .padding(.bottom, 10)
                    .zIndex(8)
                }
            }
        }
        .onAppear {
            // Auto connect using settings
            service.configureAndConnect(channels: settingsStore.settings.channels)
        }
        .onHover { hovering in hoverToolbar = hovering }
        .frame(minHeight: miniMode ? (settingsStore.settings.fontSize * 3 + 36) : nil)
    }

    private func filteredMessages() -> [LogMessage] {
        guard !keyword.isEmpty else { return service.aggregator.messages }
        if filterMode {
            return service.aggregator.messages.filter { $0.raw.localizedCaseInsensitiveContains(keyword) }
        } else {
            maybeNotify()
            return service.aggregator.messages
        }
    }

    private func maybeNotify() {
        let now = Date()
        if now.timeIntervalSince(lastNotifyAt) < 3 { return }
        if let last = service.aggregator.messages.last, last.raw.localizedCaseInsensitiveContains(keyword) {
            lastNotifyAt = now
            pushNotification(title: "关键词命中", body: keyword)
        }
    }

    private func pushNotification(title: String, body: String) {
        #if os(macOS)
        let n = NSUserNotification()
        n.title = title
        n.informativeText = body
        NSUserNotificationCenter.default.deliver(n)
        #endif
    }

    @ViewBuilder
    private func highlightedText(_ line: String) -> some View {
        if !keyword.isEmpty {
            Highlighter.highlight(text: line, keyword: keyword)
        } else {
            Text(line)
        }
    }

    private func styledText(from segments: [TemplateEngine.StyledSegment], palette: ThemePalette, keyword: String) -> Text {
        var result = Text("")
        for seg in segments {
            let color = colorForRoleName(seg.roleName, palette: palette)
            let piece: Text
            if keyword.isEmpty {
                piece = Text(seg.text).foregroundColor(color)
            } else {
                piece = Highlighter.highlight(text: seg.text, keyword: keyword).foregroundColor(color)
            }
            result = result + piece
        }
        return result
    }

    private func colorForRoleName(_ name: String?, palette: ThemePalette) -> Color {
        guard let n = name?.lowercased() else { return palette.colors[.primary]! }
        switch n {
        case "primary": return palette.colors[.primary]!
        case "second", "secondary": return palette.colors[.second]!
        case "warning", "warn": return palette.colors[.warning]!
        case "error": return palette.colors[.error]!
        case "notice", "info", "success": return palette.colors[.notice]!
        case "debug": return palette.colors[.debug]!
        case "normal", "gray": return palette.colors[.normal]!
        default: return palette.colors[.primary]!
        }
    }

}

#Preview {
    ContentView()
        .environmentObject(SettingsStore())
}
