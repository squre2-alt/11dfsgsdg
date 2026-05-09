import Foundation
import Network

@MainActor
final class DiscoveryService: ObservableObject {
    @Published var services: [DiscoveredService] = []
    @Published var isScanning = false
    @Published var errorMessage: String?
    @Published var statusText = "未发现"

    private var browsers: [NWBrowser] = []

    func start() {
        stop()
        isScanning = true
        errorMessage = nil
        services = []
        statusText = "正在发现 Bonjour/mDNS 服务..."
        browse(type: "_http._tcp", scheme: "http", fallbackPort: 80)
        browse(type: "_https._tcp", scheme: "https", fallbackPort: 443)
    }

    func stop() {
        browsers.forEach { $0.cancel() }
        browsers = []
        isScanning = false
        if services.isEmpty {
            statusText = "已停止，未发现服务"
        } else {
            statusText = "已停止，发现 \(services.count) 个服务"
        }
    }

    private func browse(type: String, scheme: String, fallbackPort: Int) {
        let descriptor = NWBrowser.Descriptor.bonjour(type: type, domain: nil)
        let browser = NWBrowser(for: descriptor, using: .tcp)

        browser.stateUpdateHandler = { [weak self] state in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch state {
                case .failed(let error):
                    self.errorMessage = error.localizedDescription
                    self.statusText = "发现失败：\(error.localizedDescription)"
                    self.isScanning = false
                case .ready:
                    self.isScanning = true
                    self.statusText = "正在发现 Bonjour/mDNS 服务..."
                case .cancelled:
                    self.isScanning = false
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
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
        statusText = "发现 \(services.count) 个 Bonjour/mDNS 服务"
    }

    private static func serviceName(from endpoint: NWEndpoint) -> String {
        if case let .service(name, _, _, _) = endpoint {
            return name
        }
        return "\(endpoint)"
    }
}
