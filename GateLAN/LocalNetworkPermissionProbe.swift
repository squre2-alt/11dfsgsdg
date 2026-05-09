import Foundation
import Network

@MainActor
final class LocalNetworkPermissionProbe: ObservableObject {
    private var browser: NWBrowser?

    func request() {
        browser?.cancel()

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
}
