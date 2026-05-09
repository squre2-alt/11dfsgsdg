import Foundation
import Network

struct SubnetScanResult: Identifiable, Hashable {
    let id = UUID()
    let host: String
    let openPorts: [Int]
    let title: String?

    var address: String {
        "\(host):\(openPorts.map(String.init).joined(separator: ","))"
    }

    var preferredPort: Int {
        openPorts.sorted { Self.portPriority($0) < Self.portPriority($1) }.first ?? 80
    }

    var preferredScheme: String {
        preferredPort == 443 ? "https" : "http"
    }

    var displayName: String {
        if let title, !title.isEmpty {
            return title
        }
        return host
    }

    static func portPriority(_ port: Int) -> Int {
        switch port {
        case 80: return 0
        case 443: return 1
        case 8080: return 2
        case 8000: return 3
        case 8888: return 4
        default: return 99
        }
    }
}

@MainActor
final class SubnetScanner: ObservableObject {
    @Published var results: [SubnetScanResult] = []
    @Published var isScanning = false
    @Published var scannedCount = 0
    @Published var statusText = "未扫描"

    private var scanTask: Task<Void, Never>?
    private let commonPorts = [80, 443, 8080, 8000, 8888]

    func scan(prefix: String) {
        stop()

        let cleanPrefix = prefix
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))

        guard cleanPrefix.split(separator: ".").count == 3 else {
            statusText = "请输入前三段 IP，例如 192.168.1"
            return
        }

        results = []
        scannedCount = 0
        isScanning = true
        statusText = "正在扫描 \(cleanPrefix).1-254"

        scanTask = Task { [weak self] in
            guard let self else { return }
            await withTaskGroup(of: SubnetScanResult?.self) { group in
                for lastOctet in 1...254 {
                    let host = "\(cleanPrefix).\(lastOctet)"
                    group.addTask {
                        let openPorts = await Self.openPorts(host: host, ports: self.commonPorts)
                        guard !openPorts.isEmpty else { return nil }
                        let title = await Self.fetchTitle(host: host, ports: openPorts)
                        return SubnetScanResult(host: host, openPorts: openPorts, title: title)
                    }
                }

                for await result in group {
                    if Task.isCancelled { break }
                    await MainActor.run {
                        self.scannedCount += 1
                        if let result {
                            self.results.append(result)
                            self.sortResults()
                        }
                        self.statusText = "已扫描 \(self.scannedCount)/254，发现 \(self.results.count) 台"
                    }
                }
            }

            await MainActor.run {
                self.isScanning = false
                self.statusText = "扫描完成，发现 \(self.results.count) 台可能有后台的设备"
            }
        }
    }

    func stop() {
        scanTask?.cancel()
        scanTask = nil
        if isScanning {
            statusText = "已停止"
        }
        isScanning = false
    }

    private func sortResults() {
        results.sort { left, right in
            let leftPriority = SubnetScanResult.portPriority(left.preferredPort)
            let rightPriority = SubnetScanResult.portPriority(right.preferredPort)
            if leftPriority != rightPriority {
                return leftPriority < rightPriority
            }
            return left.host.localizedStandardCompare(right.host) == .orderedAscending
        }
    }

    private static func openPorts(host: String, ports: [Int]) async -> [Int] {
        var openPorts: [Int] = []
        for port in ports {
            if await canConnect(host: host, port: port, timeout: 0.75) {
                openPorts.append(port)
            }
        }
        return openPorts
    }

    private static func canConnect(host: String, port: Int, timeout: TimeInterval) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: UInt16(port)),
                using: .tcp
            )
            let queue = DispatchQueue(label: "SubnetScanner.\(host).\(port)")
            var didFinish = false

            func finish(_ value: Bool) {
                guard !didFinish else { return }
                didFinish = true
                connection.cancel()
                continuation.resume(returning: value)
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

    private static func fetchTitle(host: String, ports: [Int]) async -> String? {
        let sortedPorts = ports.sorted { portPriority($0) < portPriority($1) }
        for port in sortedPorts {
            let scheme = port == 443 ? "https" : "http"
            guard let url = URL(string: "\(scheme)://\(host):\(port)/") else { continue }
            if let title = await fetchTitle(url: url) {
                return title
            }
        }
        return nil
    }

    private static func fetchTitle(url: URL) async -> String? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 1.5
        request.httpMethod = "GET"

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let limitedData = data.prefix(64 * 1024)
            guard let html = String(data: limitedData, encoding: .utf8)
                ?? String(data: limitedData, encoding: .isoLatin1) else {
                return nil
            }
            return extractTitle(from: html)
        } catch {
            return nil
        }
    }

    private static func extractTitle(from html: String) -> String? {
        guard let startRange = html.range(of: "<title", options: [.caseInsensitive]),
              let startClose = html[startRange.upperBound...].firstIndex(of: ">"),
              let endRange = html[startClose...].range(of: "</title>", options: [.caseInsensitive]) else {
            return nil
        }

        let rawTitle = String(html[html.index(after: startClose)..<endRange.lowerBound])
        let cleaned = rawTitle
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return cleaned.isEmpty ? nil : cleaned
    }
}
