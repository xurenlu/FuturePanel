import Foundation

final class LogService: ObservableObject {
    @Published var aggregator = LogAggregator()
    var currentTemplate: String = ""

    private var clients: [String: WebSocketClient] = [:]

    func configureAndConnect(servers: [ServerMachine], channels: [ChannelEntry]) {
        // close existing
        for (_, c) in clients { c.close() }
        clients.removeAll()

        let enabledServers = servers.filter { $0.enabled }
        let enabledChannels = channels.filter { $0.enabled }
        for s in enabledServers {
            for ch in enabledChannels {
                guard var comps = URLComponents(url: s.baseURL, resolvingAgainstBaseURL: false) else { continue }
                comps.scheme = (comps.scheme == "http") ? "ws" : (comps.scheme == "https" ? "wss" : comps.scheme)
                comps.path = ch.path.hasPrefix("/") ? ch.path : "/" + ch.path
                guard let url = comps.url else { continue }
                let key = s.id + "|" + ch.id
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


