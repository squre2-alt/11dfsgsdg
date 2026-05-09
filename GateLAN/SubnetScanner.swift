import Foundation
import Network

struct SubnetScanResult: Identifiable, Hashable {
    let id = UUID()
    let host: String
    let openPorts: [Int]

    var address: String {
        "\(host):\(openPorts.map(String.init).joined(separator: ","))"
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
                        return SubnetScanResult(host: host, openPorts: openPorts)
                    }
                }

                for await result in group {
                    if Task.isCancelled { break }
                    await MainActor.run {
                        self.scannedCount += 1
                        if let result {
                            self.results.append(result)
                            self.results.sort { $0.host.localizedStandardCompare($1.host) == .orderedAscending }
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
}
