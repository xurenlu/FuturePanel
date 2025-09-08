import Foundation
import Combine

struct ServerMachine: Identifiable, Hashable, Codable {
    let id: String
    var name: String
    var baseURL: URL
    var enabled: Bool

    init(id: String = UUID().uuidString, name: String, baseURL: URL, enabled: Bool) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.enabled = enabled
    }

    enum CodingKeys: String, CodingKey { case id, name, baseURL, enabled }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        let urlString = try c.decode(String.self, forKey: .baseURL)
        guard let u = URL(string: urlString) else { throw DecodingError.dataCorruptedError(forKey: .baseURL, in: c, debugDescription: "invalid url") }
        baseURL = u
        enabled = try c.decode(Bool.self, forKey: .enabled)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(baseURL.absoluteString, forKey: .baseURL)
        try c.encode(enabled, forKey: .enabled)
    }
}

struct ChannelEntry: Identifiable, Hashable, Codable {
    let id: String
    var path: String
    var enabled: Bool

    init(id: String = UUID().uuidString, path: String, enabled: Bool) {
        self.id = id
        self.path = path
        self.enabled = enabled
    }
}

struct LogMeta: Decodable {
    let id: String
    let ts: String?
    let unixNs: Int64?
    let originNodeId: String?
    let channel: String?
}

struct LogEnvelope: Decodable {
    let _meta: LogMeta?
}

struct LogMessage: Identifiable {
    let id: String
    let unixNs: Int64
    let channel: String
    let raw: String
    let timeString: String
}

final class LogAggregator: ObservableObject {
    @Published private(set) var messages: [LogMessage] = []
    @Published var renderedLines: [String] = []

    private var seen: [String: Int64] = [:]
    private let queue = DispatchQueue(label: "LogAggregator.queue")
    private let maxEntries: Int = 100_000
    private let ttlNs: Int64 = 10 * 60 * 1_000_000_000 // 10 minutes

    func add(rawString: String) {
        guard let data = rawString.data(using: .utf8) else { return }
        var id: String = ""
        var unixNs: Int64 = Int64(Date().timeIntervalSince1970 * 1_000_000_000)
        var channel: String = ""
        if let env = try? JSONDecoder().decode(LogEnvelope.self, from: data), let meta = env._meta {
            id = meta.id
            unixNs = meta.unixNs ?? unixNs
            channel = meta.channel ?? ""
        }
        if id.isEmpty {
            id = UUID().uuidString
        }
        let timeString: String = {
            let seconds = TimeInterval(Double(unixNs) / 1_000_000_000.0)
            let date = Date(timeIntervalSince1970: seconds)
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd HH:mm:ss"
            return df.string(from: date)
        }()

        queue.async { [weak self] in
            guard let self else { return }
            // dedup
            if self.seen[id] != nil { return }
            self.seen[id] = unixNs
            // prune seen
            if self.seen.count > self.maxEntries {
                let cutoff = unixNs - self.ttlNs
                self.seen = self.seen.filter { $0.value >= cutoff }
            }
            let item = LogMessage(id: id, unixNs: unixNs, channel: channel, raw: rawString, timeString: timeString)
            // insert ordered by unixNs (ascending)
            var newMessages = self.messages
            let insertIndex = newMessages.binarySearch { $0.unixNs < item.unixNs }
            newMessages.insert(item, at: insertIndex)
            // bound memory for messages as well
            if newMessages.count > 50_000 {
                newMessages.removeFirst(newMessages.count - 50_000)
            }
            DispatchQueue.main.async {
                self.messages = newMessages
                NotificationCenter.default.post(name: .logAggregatorNewMessage, object: nil)
            }
        }
    }
}

extension Array {
    // Returns index where to insert to keep array ordered with given comparator
    fileprivate func binarySearch(_ isOrderedBefore: (Element) -> Bool) -> Int {
        var low = 0
        var high = count
        while low < high {
            let mid = (low + high) / 2
            if isOrderedBefore(self[mid]) {
                low = mid + 1
            } else {
                high = mid
            }
        }
        return low
    }
}

extension Notification.Name {
    static let logAggregatorNewMessage = Notification.Name("logAggregatorNewMessage")
}


