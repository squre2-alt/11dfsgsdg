import Foundation
import Network

enum ConnectivityChecker {
    static func check(host: String, port: Int, timeout: TimeInterval = 4) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: .tcp)
            let queue = DispatchQueue(label: "ConnectivityChecker")
            var didFinish = false

            func finish(_ online: Bool) {
                guard !didFinish else { return }
                didFinish = true
                connection.cancel()
                continuation.resume(returning: online)
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed, .cancelled:
                    finish(false)
                default:
                    break
                }
            }

            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + timeout) {
                finish(false)
            }
        }
    }
}
