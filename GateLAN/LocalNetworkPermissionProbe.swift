import Foundation
import Network

@MainActor
final class LocalNetworkPermissionProbe: ObservableObject {
    private var browser: NWBrowser?
    private var connection: NWConnection?

    func request() {
        browser?.cancel()
        connection?.cancel()

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
        sendMulticastProbe()
    }

    private func sendMulticastProbe() {
        let parameters = NWParameters.udp
        parameters.allowLocalEndpointReuse = true
        parameters.includePeerToPeer = true

        let connection = NWConnection(
            host: NWEndpoint.Host("224.0.0.251"),
            port: NWEndpoint.Port(integerLiteral: 5353),
            using: parameters
        )
        self.connection = connection

        connection.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                let payload = Data([0x00, 0x00, 0x00, 0x00])
                connection.send(content: payload, completion: .contentProcessed { _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self?.connection?.cancel()
                        self?.connection = nil
                    }
                })
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
    }
}
