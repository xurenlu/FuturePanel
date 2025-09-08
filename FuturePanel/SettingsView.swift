import SwiftUI
#if os(macOS)
import AppKit
#endif

struct SettingsView: View {
    @ObservedObject var store: SettingsStore
    @State private var selection: Int = 0
    @State private var sidebarWidth: CGFloat = 200

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar (controls selection) - resizable width
            List {
                SidebarRow(title: "数据来源", systemImage: "tray.full", index: 0, selection: $selection)
                SidebarRow(title: "DSL 模板", systemImage: "chevron.left.forwardslash.chevron.right", index: 1, selection: $selection)
                SidebarRow(title: "显示", systemImage: "textformat.size", index: 2, selection: $selection)
            }
            .frame(minWidth: 160, idealWidth: sidebarWidth, maxWidth: 320)
            .listStyle(.sidebar)

            Divider()

            // Content - driven by sidebar "selection"
            Group {
                if selection == 0 {
                    // 数据来源：服务器 + 频道
                    Form {
                        Section(header: Text("Servers").font(.headline)) {
                            ForEach($store.settings.servers) { $s in
                                HStack {
                                    Toggle("", isOn: $s.enabled).labelsHidden()
                                    TextField("Name", text: $s.name)
                                    TextField("Base URL", text: Binding(
                                        get: { s.baseURL.absoluteString },
                                        set: { s.baseURL = URL(string: $0) ?? s.baseURL }
                                    ))
                                }
                            }
                            HStack {
                                Button("添加服务器") {
                                    store.settings.servers.append(ServerMachine(name: "New Server", baseURL: URL(string: "http://localhost:8080")!, enabled: false))
                                }
                                Spacer()
                            }
                        }
                        Section(header: Text("Channels").font(.headline)) {
                            ForEach($store.settings.channels) { $c in
                                HStack {
                                    Toggle("", isOn: $c.enabled).labelsHidden()
                                    TextField("/path", text: $c.path)
                                }
                            }
                            HStack {
                                Button("添加频道") {
                                    store.settings.channels.append(ChannelEntry(path: "/events/new", enabled: false))
                                }
                                Spacer()
                            }
                        }
                    }
                } else if selection == 1 {
                    // DSL 模板
                    Form {
                        Section(header: Text("默认模板 (DSL)").font(.headline)) {
                            TextEditor(text: $store.settings.defaultTemplate)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 220)
                            GroupBox("实时预览（使用当前模板）") {
                                Text(livePreview)
                                    .font(.custom(store.settings.fontFamily, size: store.settings.fontSize))
                                    .padding(6)
                            }
                            GroupBox("示例预览（固定示例 DSL）") {
                                Text(examplePreview)
                                    .font(.custom(store.settings.fontFamily, size: store.settings.fontSize))
                                    .padding(6)
                            }
                        }
                        Section(header: Text("DSL 参考（主要变量与函数）").font(.headline)) {
                            ScrollView {
                                VStack(alignment: .leading, spacing: 8) {
                                    GroupBox("变量") {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("$DTIME：日期+时间 (yyyy-MM-dd HH:mm:ss)")
                                            Text("$DATE：日期 (yyyy-MM-dd)")
                                            Text("$TIME：时间 (HH:mm:ss)")
                                            Text("$UUID：消息ID")
                                            Text("$LAST6：消息ID后6位（也兼容旧 $UUID_LAST6）")
                                            Text("${.field}：JSON 字段，支持 KeyPath，如 ${.body.level}")
                                        }
                                        .font(.system(.caption, design: .monospaced))
                                    }
                                    GroupBox("样式（由主题决定颜色，仅包装文本，不改变内容）") {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("primary(x), second(x), notice(x), warning(x), error(x), debug(x), normal(x)")
                                            Text("示例：primary(${.title})  second($DTIME)  debug($LAST6)")
                                        }
                                        .font(.system(.caption, design: .monospaced))
                                    }
                                    GroupBox("文本函数（已实现）") {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("max(str, len, \"extra\")：超出 len 时截断并追加 extra（extra 可选，默认 ..）")
                                            Text("default(x, \"fallback\")：x 为空或缺失时使用 fallback")
                                            Text("支持与变量/字段组合，如 normal(max(${.message}, 120, \"...\"))")
                                        }
                                        .font(.system(.caption, design: .monospaced))
                                    }
                                    GroupBox("注意事项") {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text("1. 计算顺序：先计算函数（max/default），再去掉样式包装，最后输出文本")
                                            Text("2. ${.field} 读取顶层或 KeyPath 字段，缺失时返回空字符串")
                                            Text("3. $DTIME/$DATE/$TIME 源自消息 _meta.ts")
                                        }
                                        .font(.system(.caption, design: .monospaced))
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                } else if selection == 2 {
                    // 显示：背景 + 主题 + 字体 + 预览
                    DisplaySettingsView(store: store)
                } else {
                    EmptyView()
                }
            }
        }
        .frame(minWidth: 860, minHeight: 560)
        .overlay(alignment: .leading) {
            // draggable handle to resize sidebar
            Rectangle()
                .fill(Color.clear)
                .frame(width: 6)
                .gesture(DragGesture()
                    .onChanged { v in
                        sidebarWidth = max(160, min(320, sidebarWidth + v.translation.width))
                    }
                )
        }
        .onDisappear { store.save() }
    }
}

private struct SidebarRow: View {
    let title: String
    let systemImage: String
    let index: Int
    @Binding var selection: Int
    var body: some View {
        HStack {
            Image(systemName: systemImage)
            Text(title)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { selection = index }
        .padding(.vertical, 6)
        .background(selection == index ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }
}

struct ThemePreviewView: View {
    @ObservedObject var store: SettingsStore
    var body: some View {
        let theme = ThemeName(rawValue: store.settings.theme) ?? .oneDark
        let pal = ThemePalette.palette(for: theme)
        VStack(alignment: .leading, spacing: 16) {
            Form {
                Section(header: Text("主题与透明度").font(.headline)) {
                    Picker("Theme", selection: Binding(
                        get: { ThemeName(rawValue: store.settings.theme) ?? .oneDark },
                        set: { store.settings.theme = $0.rawValue }
                    )) {
                        ForEach(ThemeName.allCases) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    HStack {
                        Text("透明度")
                        Slider(value: $store.settings.windowOpacity, in: 0.4...1.0, step: 0.01)
                    }
                    Toggle("始终置顶", isOn: $store.settings.alwaysOnTop)
                    Toggle("非悬停时点击穿透", isOn: $store.settings.passThroughWhenNotHovered)
                }
            }

            GroupBox("示例预览") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(previewLine)
                        .font(.custom(store.settings.fontFamily, size: store.settings.fontSize))
                        .foregroundColor(pal.colors[.primary]!)
                }
                .padding(8)
            }
        }
        .padding()
    }

    private var previewLine: String {
        let sampleJSON = "{\"title\":\"Hello\",\"message\":\"This is a demo line for preview\",\"level\":\"info\"}"
        let now = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return TemplateEngine.render(
            template: store.settings.defaultTemplate,
            jsonString: sampleJSON,
            metaTimeString: df.string(from: now),
            id: UUID().uuidString
        )
    }
}

struct DisplaySettingsView: View {
    @ObservedObject var store: SettingsStore
    private var theme: ThemeName { ThemeName(rawValue: store.settings.theme) ?? .oneDark }
    private var palette: ThemePalette { ThemePalette.palette(for: theme) }
    #if os(macOS)
    private var fontFamilies: [String] { NSFontManager.shared.availableFontFamilies.sorted() }
    #else
    private var fontFamilies: [String] { ["SF Mono", "Menlo", "Courier"] }
    #endif
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Form {
                Section(header: Text("背景与主题").font(.headline)) {
                    Picker("背景色", selection: Binding(
                        get: { BackgroundPreset(rawValue: store.settings.background) ?? .graphiteBlack },
                        set: { store.settings.background = $0.rawValue
                            // auto-adjust theme if not in recommendations
                            let recs = BackgroundRecommendations.recommendedThemes(for: $0)
                            if !recs.contains(ThemeName(rawValue: store.settings.theme) ?? .oneDark) {
                                store.settings.theme = recs.first?.rawValue ?? ThemeName.oneDark.rawValue
                            }
                        }
                    )) {
                        ForEach(BackgroundPreset.allCases) { b in
                            Text(b.rawValue).tag(b)
                        }
                    }
                    Picker("主题", selection: Binding(
                        get: { ThemeName(rawValue: store.settings.theme) ?? .oneDark },
                        set: { store.settings.theme = $0.rawValue }
                    )) {
                        let bg = BackgroundPreset(rawValue: store.settings.background) ?? .graphiteBlack
                        let recs = BackgroundRecommendations.recommendedThemes(for: bg)
                        ForEach(recs) { t in
                            Text(t.rawValue).tag(t)
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("样式色板")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        PaletteGrid(palette: palette)
                    }
                    HStack {
                        Text("透明度")
                        Slider(value: $store.settings.windowOpacity, in: 0.4...1.0, step: 0.01)
                    }
                    Toggle("始终置顶", isOn: $store.settings.alwaysOnTop)
                    Toggle("非悬停时点击穿透", isOn: $store.settings.passThroughWhenNotHovered)
                }
                // 回滚：移除主窗背景设置
                Section(header: Text("字体").font(.headline)) {
                    Picker("字体族", selection: $store.settings.fontFamily) {
                        ForEach(fontFamilies, id: \.self) { family in
                            Text(family).tag(family)
                        }
                    }
                    Stepper(value: $store.settings.fontSize, in: 10...24, step: 1) {
                        Text("字号：\(Int(store.settings.fontSize))")
                    }
                }
            }

            GroupBox("示例预览") {
                ZStack(alignment: .topLeading) {
                    let bg = BackgroundPreset(rawValue: store.settings.background) ?? .graphiteBlack
                    bg.color
                    Text(previewLine)
                        .font(.custom(store.settings.fontFamily, size: store.settings.fontSize))
                        .foregroundColor(
                            adaptiveOnBackground(
                                foreground: palette.colors[.primary]!,
                                background: bg.color
                            )
                        )
                        .padding(8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding()
    }

    private var previewLine: String {
        let sampleJSON = "{\"title\":\"Hello\",\"message\":\"This is a demo line for preview\",\"level\":\"info\"}"
        let now = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return TemplateEngine.render(
            template: store.settings.defaultTemplate,
            jsonString: sampleJSON,
            metaTimeString: df.string(from: now),
            id: UUID().uuidString
        )
    }
}

private extension SettingsView {
    var livePreview: String {
        let sampleJSON = "{\"title\":\"Hello\",\"message\":\"This is a demo line for preview\",\"level\":\"info\"}"
        let now = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return TemplateEngine.render(
            template: store.settings.defaultTemplate,
            jsonString: sampleJSON,
            metaTimeString: df.string(from: now),
            id: UUID().uuidString
        )
    }

    var examplePreview: String {
        // [ primary($TIME) ] second("title") warn("warn") success("succ") gray($LAST6)
        let dsl = "[ primary($TIME) ] second(\"title\") warn(\"warn\") success(\"succ\") gray($LAST6)"
        let sampleJSON = "{\"title\":\"Hello\",\"message\":\"...\",\"level\":\"info\"}"
        let now = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return TemplateEngine.render(
            template: dsl,
            jsonString: sampleJSON,
            metaTimeString: df.string(from: now),
            id: UUID().uuidString
        )
    }
}

// MARK: - Palette Grid Subviews
private struct PaletteGrid: View {
    let palette: ThemePalette
    private let roles: [(SemanticRole, String)] = [
        (.primary, "primary"),
        (.second, "second"),
        (.notice, "notice (info)"),
        (.warning, "warning"),
        (.error, "error"),
        (.debug, "debug"),
        (.normal, "normal"),
    ]
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
            ForEach(roles, id: \.1) { item in
                let color = palette.colors[item.0] ?? Color.white
                ColorSwatch(color: color, label: item.1)
            }
        }
    }
}

private struct ColorSwatch: View {
    let color: Color
    let label: String
    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(color)
            .frame(height: 28)
            .overlay(
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(adaptiveOnBackground(foreground: .white, background: color))
                    Spacer()
                    Text(color.toHex(true))
                        .font(.caption2)
                        .foregroundColor(adaptiveOnBackground(foreground: .white, background: color).opacity(0.85))
                }
                .padding(.horizontal, 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}

