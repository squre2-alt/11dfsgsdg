import Foundation
import Network

@MainActor
final class DiscoveryService: ObservableObject {
    @Published var services: [DiscoveredService] = []
    @Published var isScanning = false
    @Published var errorMessage: String?

    private var browsers: [NWBrowser] = []

    func start() {
        stop()
        isScanning = true
        errorMessage = nil
        services = []
        browse(type: "_http._tcp", scheme: "http", fallbackPort: 80)
        browse(type: "_https._tcp", scheme: "https", fallbackPort: 443)
    }

    func stop() {
        browsers.forEach { $0.cancel() }
        browsers = []
        isScanning = false
    }

    private func browse(type: String, scheme: String, fallbackPort: Int) {
        let descriptor = NWBrowser.Descriptor.bonjour(type: type, domain: nil)
        let browser = NWBrowser(for: descriptor, using: .tcp)

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .failed(let error):
                    self.errorMessage = error.localizedDescription
                    self.isScanning = false
                case .ready:
                    self.isScanning = true
                case .cancelled:
                    self.isScanning = false
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                guard let self else { return }
                let mapped = results.map { result in
                    let name = Self.serviceName(from: result.endpoint)
                    return DiscoveredService(
                        name: name,
                        type: type,
                        endpointDescription: "\(result.endpoint)",
                        scheme: scheme,
                        port: fallbackPort
                    )
                }
                self.merge(mapped)
            }
        }

        browsers.append(browser)
        browser.start(queue: .global(qos: .userInitiated))
    }

    private func merge(_ incoming: [DiscoveredService]) {
        var combined = services
        for service in incoming where !combined.contains(where: { $0.endpointDescription == service.endpointDescription }) {
            combined.append(service)
        }
        services = combined.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }
    }

    private static func serviceName(from endpoint: NWEndpoint) -> String {
        if case let .service(name, _, _, _) = endpoint {
            return name
        }
        return "\(endpoint)"
    }
}
