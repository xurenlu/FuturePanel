import Foundation

final class WebSocketClient: NSObject, URLSessionWebSocketDelegate {
    private var session: URLSession!
    private var task: URLSessionWebSocketTask?
    private let url: URL
    private let onMessage: (String) -> Void
    private var isClosed = false

    init(url: URL, onMessage: @escaping (String) -> Void) {
        self.url = url
        self.onMessage = onMessage
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }

    func connect() {
        guard task == nil else { return }
        var req = URLRequest(url: url)
        task = session.webSocketTask(with: req)
        task?.resume()
        receiveLoop()
    }

    func close() {
        isClosed = true
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
    }

    private func receiveLoop() {
        task?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure:
                self.reconnect()
            case .success(let message):
                switch message {
                case .string(let text):
                    self.onMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) { self.onMessage(text) }
                @unknown default:
                    break
                }
                self.receiveLoop()
            }
        }
    }

    private func reconnect() {
        guard !isClosed else { return }
        task?.cancel()
        task = nil
        // simple backoff
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.5) {
            self.connect()
        }
    }

    // MARK: URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        // no-op
    }
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        reconnect()
    }
}


