import Foundation

struct AppSettings: Codable {
    var servers: [ServerMachine]
    var channels: [ChannelEntry]
    var theme: String
    var fontSize: Double
    var fontFamily: String
    var defaultTemplate: String
    var windowOpacity: Double
    var alwaysOnTop: Bool
    var passThroughWhenNotHovered: Bool
    // Background preset
    var background: String // BackgroundPreset rawValue
    // Theme color overrides: role(rawValue) -> hex color (e.g., #RRGGBBAA)
    var themeOverrides: [String: String]

    init(
        servers: [ServerMachine],
        channels: [ChannelEntry],
        theme: String,
        fontSize: Double,
        fontFamily: String,
        defaultTemplate: String,
        windowOpacity: Double,
        alwaysOnTop: Bool,
        passThroughWhenNotHovered: Bool,
        background: String,
        themeOverrides: [String: String]
    ) {
        self.servers = servers
        self.channels = channels
        self.theme = theme
        self.fontSize = fontSize
        self.fontFamily = fontFamily
        self.defaultTemplate = defaultTemplate
        self.windowOpacity = windowOpacity
        self.alwaysOnTop = alwaysOnTop
        self.passThroughWhenNotHovered = passThroughWhenNotHovered
        self.background = background
        self.themeOverrides = themeOverrides
    }

    static let `default` = AppSettings(
        servers: [ServerMachine(name: "Local Dev", baseURL: URL(string: "http://localhost:8080")!, enabled: true)],
        channels: [ChannelEntry(path: "/events/app1", enabled: true)],
        theme: ThemeName.oneDark.rawValue,
        fontSize: 12,
        fontFamily: "SF Mono",
        defaultTemplate: "second($DTIME) primary(${.title}) normal(max(${.message},120)) debug($LAST6)",
        windowOpacity: 0.88,
        alwaysOnTop: true,
        passThroughWhenNotHovered: true,
        background: BackgroundPreset.graphiteBlack.rawValue,
        themeOverrides: [:]
    )

    enum CodingKeys: String, CodingKey {
        case servers, channels, theme, fontSize, fontFamily, defaultTemplate, windowOpacity, alwaysOnTop, passThroughWhenNotHovered, background, themeOverrides
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        servers = (try? c.decode([ServerMachine].self, forKey: .servers)) ?? AppSettings.default.servers
        channels = (try? c.decode([ChannelEntry].self, forKey: .channels)) ?? AppSettings.default.channels
        theme = (try? c.decode(String.self, forKey: .theme)) ?? AppSettings.default.theme
        fontSize = (try? c.decode(Double.self, forKey: .fontSize)) ?? AppSettings.default.fontSize
        fontFamily = (try? c.decode(String.self, forKey: .fontFamily)) ?? AppSettings.default.fontFamily
        defaultTemplate = (try? c.decode(String.self, forKey: .defaultTemplate)) ?? AppSettings.default.defaultTemplate
        windowOpacity = (try? c.decode(Double.self, forKey: .windowOpacity)) ?? AppSettings.default.windowOpacity
        alwaysOnTop = (try? c.decode(Bool.self, forKey: .alwaysOnTop)) ?? AppSettings.default.alwaysOnTop
        passThroughWhenNotHovered = (try? c.decode(Bool.self, forKey: .passThroughWhenNotHovered)) ?? AppSettings.default.passThroughWhenNotHovered
        background = (try? c.decode(String.self, forKey: .background)) ?? AppSettings.default.background
        themeOverrides = (try? c.decode([String: String].self, forKey: .themeOverrides)) ?? [:]
    }
}

final class SettingsStore: ObservableObject {
    @Published var settings: AppSettings

    init() {
        self.settings = Self.load()
    }

    func save() {
        do {
            let url = Self.fileURL()
            let data = try JSONEncoder().encode(settings)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        } catch {
            print("settings save error", error)
        }
    }

    static func load() -> AppSettings {
        do {
            let url = fileURL()
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            return .default
        }
    }

    private static func fileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("FuturePanel/config.json")
    }
}


