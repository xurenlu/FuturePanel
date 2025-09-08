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
// import SwiftData

struct DemoConfig {
    static let servers: [ServerMachine] = [
        .init(id: "dev", name: "Local Dev", baseURL: URL(string: "http://localhost:8080")!, enabled: true)
    ]
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
            let topInset = max(0, settingsStore.settings.fontSize * 2 + 24)
            let theme = ThemeName(rawValue: settingsStore.settings.theme) ?? .oneDark
            ZStack {
                let bgPreset = BackgroundPreset(rawValue: settingsStore.settings.background) ?? .graphiteBlack
                bgPreset.color
                List(filteredMessages()) { msg in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        let pal = ThemePalette.palette(for: theme)
                        Text("[\(msg.channel)]").foregroundColor(pal.colors[.second]!)
                        Text(msg.timeString).foregroundColor(pal.colors[.normal]!)
                        Spacer()
                        Text(String(msg.id.suffix(6))).foregroundColor(pal.colors[.debug]!)
                    }
                    // Render using default DSL template
                    let line = TemplateEngine.render(
                        template: settingsStore.settings.defaultTemplate,
                        jsonString: msg.raw,
                        metaTimeString: msg.timeString,
                        id: msg.id
                    )
                    highlightedText(line)
                        .font(.custom(settingsStore.settings.fontFamily, size: settingsStore.settings.fontSize))
                        .foregroundColor(ThemePalette.palette(for: theme).colors[.primary]!)
                        .textSelection(.enabled)
                }
                .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
            }
            // Draggable transparent area at the very top
            .overlay(alignment: .topLeading) {
                ZStack(alignment: .top) {
                    // subtle visual affordance for draggable area
                    Color(nsColor: .windowBackgroundColor)
                        .opacity(0.12)
                    DraggableAreaView()
                        .background(Color.clear)
                }
                .frame(height: topInset)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .frame(height: 1)
                }
                .zIndex(7)
            }
            // Close icon pinned to top-right
            .overlay(alignment: .topTrailing) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.primary)
                    .padding(6)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.75))
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.6), radius: 4, x: 0, y: 2)
                    .padding(.top, 6)
                    .padding(.trailing, 6)
                    .onTapGesture {
                        #if os(macOS)
                        NSApp.hide(nil)
                        #endif
                    }
                    .zIndex(8)
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
            service.configureAndConnect(servers: settingsStore.settings.servers, channels: settingsStore.settings.channels)
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

    
}

#Preview {
    ContentView()
        .environmentObject(SettingsStore())
}
