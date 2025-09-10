import Foundation
import Combine

final class LogService: ObservableObject {
    @Published var aggregator = LogAggregator()
    var currentTemplate: String = ""

    private var clients: [String: WebSocketClient] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // 转发 aggregator 的变更，驱动 SwiftUI 刷新
        aggregator.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    func configureAndConnect(channels: [ChannelEntry]) {
        // close existing
        for (_, c) in clients { c.close() }
        clients.removeAll()

        // 固定内置服务器域名（使用 wss 连接）
        let builtInServers: [URL] = [
            URL(string: "https://future.some.im")!,
            URL(string: "https://future.wxside.com")!
        ]
        let enabledChannels = channels.filter { $0.enabled }
        for base in builtInServers {
            for ch in enabledChannels {
                guard var comps = URLComponents(url: base, resolvingAgainstBaseURL: false) else { continue }
                comps.scheme = (comps.scheme == "http") ? "ws" : (comps.scheme == "https" ? "wss" : comps.scheme)
                comps.path = ch.path.hasPrefix("/") ? ch.path : "/" + ch.path
                guard let url = comps.url else { continue }
                let key = base.absoluteString + "|" + ch.id
                let client = WebSocketClient(url: url) { [weak self] text in
                    guard let self else { return }
                    self.aggregator.add(rawString: text)
                }
                clients[key] = client
                client.connect()
            }
        }
    }
}


