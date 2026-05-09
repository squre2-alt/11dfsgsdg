import Foundation
import Network

@MainActor
final class LocalNetworkPermissionProbe: ObservableObject {
    @Published var statusText = "未请求"

    private var browser: NWBrowser?
    private var multicastConnection: NWConnection?
    private var broadcastConnection: NWConnection?

    func request() {
        statusText = "正在请求本地网络权限..."
        browser?.cancel()
        multicastConnection?.cancel()
        broadcastConnection?.cancel()

        startBonjourBrowse()
        sendMulticastProbe()
        sendBroadcastProbe()

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.statusText = "已发送请求。如果系统弹窗出现，请选择允许。"
        }
    }

    private func startBonjourBrowse() {
        let descriptor = NWBrowser.Descriptor.bonjour(type: "_http._tcp", domain: nil)
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true

        let browser = NWBrowser(for: descriptor, using: parameters)
        self.browser = browser

        browser.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self?.browser?.cancel()
                    self?.browser = nil
                }
            }
        }

        browser.start(queue: .global(qos: .userInitiated))
    }

    private func sendMulticastProbe() {
        let connection = makeUDPConnection(host: "224.0.0.251", port: 5353)
        multicastConnection = connection
        sendProbe(on: connection) { [weak self] in
            self?.multicastConnection = nil
        }
    }

    private func sendBroadcastProbe() {
        let connection = makeUDPConnection(host: "255.255.255.255", port: 9)
        broadcastConnection = connection
        sendProbe(on: connection) { [weak self] in
            self?.broadcastConnection = nil
        }
    }

    private func makeUDPConnection(host: String, port: UInt16) -> NWConnection {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = true

        return NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: port),
            using: parameters
        )
    }

    private func sendProbe(on connection: NWConnection, cleanup: @escaping @MainActor () -> Void) {
        connection.stateUpdateHandler = { state in
            if case .ready = state {
                connection.send(content: Data([0x47, 0x4c]), completion: .contentProcessed { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        connection.cancel()
                        cleanup()
                    }
                })
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
    }
}
