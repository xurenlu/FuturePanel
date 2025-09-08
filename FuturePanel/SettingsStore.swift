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

    static let `default` = AppSettings(
        servers: [ServerMachine(name: "Local Dev", baseURL: URL(string: "http://localhost:8080")!, enabled: true)],
        channels: [ChannelEntry(path: "/events/app1", enabled: true)],
        theme: ThemeName.oneDark.rawValue,
        fontSize: 12,
        fontFamily: "SF Mono",
        defaultTemplate: "second($DTIME) primary(${.title}) normal(max(${.message},120)) debug($LAST6)",
        windowOpacity: 0.88,
        alwaysOnTop: true,
        passThroughWhenNotHovered: true
    )
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


