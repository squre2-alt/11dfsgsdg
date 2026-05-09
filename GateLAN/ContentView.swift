import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: DeviceStore
    @StateObject private var discovery = DiscoveryService()
    @StateObject private var subnetScanner = SubnetScanner()

    @State private var showingAdd = false
    @State private var editingDevice: BarrierDevice?
    @State private var checkingIDs: Set<UUID> = []
    @State private var subnetPrefix = "192.168.1"
    @State private var detectedSubnetText = "尚未识别当前 Wi-Fi 网段"

    var body: some View {
        NavigationSplitView {
            List {
                Section {
                    Button {
                        showingAdd = true
                    } label: {
                        Label("手动添加设备", systemImage: "plus.circle.fill")
                    }

                    Button {
                        discovery.isScanning ? discovery.stop() : discovery.start()
                    } label: {
                        Label(discovery.isScanning ? "停止发现" : "发现局域网服务", systemImage: "dot.radiowaves.left.and.right")
                    }

                    StatusLine(text: discovery.statusText, isActive: discovery.isScanning)

                    if let error = discovery.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section("IP 网段扫描") {
                    TextField("网段，例如 192.168.1", text: $subnetPrefix)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.numbersAndPunctuation)

                    Button {
                        detectSubnet()
                    } label: {
                        Label("使用当前 Wi-Fi 网段", systemImage: "wifi")
                    }

                    Text(detectedSubnetText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button {
                        subnetScanner.isScanning ? subnetScanner.stop() : subnetScanner.scan(prefix: subnetPrefix)
                    } label: {
                        Label(subnetScanner.isScanning ? "停止扫描" : "扫描常见后台端口", systemImage: "network")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        if subnetScanner.isScanning {
                            ProgressView(value: Double(subnetScanner.scannedCount), total: 254)
                        }
                        Text(subnetScanner.statusText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(subnetScanner.results) { result in
                        let device = device(from: result)
                        NavigationLink {
                            WebAdminView(device: device)
                        } label: {
                            ScanResultRow(
                                title: result.host,
                                subtitle: "开放端口：\(result.openPorts.map(String.init).joined(separator: ", "))"
                            )
                        }
                        .swipeActions {
                            Button("保存") {
                                store.add(device, credential: nil)
                            }
                            .tint(.green)
                        }
                    }
                }

                if !discovery.services.isEmpty {
                    Section("Bonjour/mDNS 发现") {
                        ForEach(discovery.services) { service in
                            let device = device(from: service)
                            NavigationLink {
                                WebAdminView(device: device)
                            } label: {
                                ScanResultRow(
                                    title: service.name,
                                    subtitle: service.endpointDescription
                                )
                            }
                            .swipeActions {
                                Button("保存") {
                                    store.add(device, credential: nil)
                                }
                                .tint(.green)
                            }
                        }
                    }
                }

                Section("我的设备") {
                    if store.devices.isEmpty {
                        EmptyStateView(title: "暂无设备", systemImage: "rectangle.connected.to.line.below", message: "保存常用后台后会显示在这里。")
                    } else {
                        ForEach(store.devices) { device in
                            NavigationLink(value: device) {
                                DeviceRow(device: device, isChecking: checkingIDs.contains(device.id))
                            }
                            .swipeActions(edge: .leading) {
                                Button("检测") {
                                    check(device)
                                }
                                .tint(.blue)
                            }
                            .swipeActions {
                                Button("编辑") {
                                    editingDevice = device
                                }
                                .tint(.orange)
                            }
                        }
                        .onDelete(perform: store.delete)
                    }
                }
            }
            .navigationTitle("道闸管家")
            .navigationDestination(for: BarrierDevice.self) { device in
                DeviceDetailView(device: device, isChecking: checkingIDs.contains(device.id)) {
                    check(device)
                }
            }
            .sheet(isPresented: $showingAdd) {
                DeviceEditorView(existing: nil)
            }
            .sheet(item: $editingDevice) { device in
                DeviceEditorView(existing: device)
            }
            .onAppear {
                detectSubnet()
            }
        } detail: {
            EmptyStateView(title: "选择一个设备", systemImage: "rectangle.connected.to.line.below", message: "扫描或选择设备后打开后台。")
        }
    }

    private func device(from service: DiscoveredService) -> BarrierDevice {
        BarrierDevice(
            name: service.name,
            brandID: "custom",
            host: service.name.replacingOccurrences(of: " ", with: "-") + ".local",
            port: service.port,
            scheme: service.scheme,
            path: "/",
            note: "来自 Bonjour/mDNS 发现：\(service.endpointDescription)"
        )
    }

    private func device(from result: SubnetScanResult) -> BarrierDevice {
        let preferredPort = result.openPorts.first ?? 80
        return BarrierDevice(
            name: "局域网设备 \(result.host)",
            brandID: "custom",
            host: result.host,
            port: preferredPort,
            scheme: preferredPort == 443 ? "https" : "http",
            path: "/",
            note: "来自 IP 网段扫描，开放端口：\(result.openPorts.map(String.init).joined(separator: ", "))"
        )
    }

    private func detectSubnet() {
        if let prefix = NetworkInfo.currentIPv4Prefix() {
            subnetPrefix = prefix
            detectedSubnetText = "当前 Wi-Fi 网段：\(prefix).1-254"
        } else {
            detectedSubnetText = "未识别到 Wi-Fi IPv4 地址，可手动填写前三段 IP"
        }
    }

    private func check(_ device: BarrierDevice) {
        checkingIDs.insert(device.id)
        Task {
            let online = await ConnectivityChecker.check(host: device.host, port: device.port)
            await MainActor.run {
                store.mark(device.id, online: online)
                checkingIDs.remove(device.id)
            }
        }
    }
}

struct StatusLine: View {
    let text: String
    let isActive: Bool

    var body: some View {
        HStack {
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            if isActive {
                Spacer()
                ProgressView()
            }
        }
    }
}

struct ScanResultRow: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 42))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 120)
        .padding()
    }
}

struct DeviceRow: View {
    let device: BarrierDevice
    let isChecking: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: statusIcon)
                .foregroundStyle(statusColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(device.name)
                    .font(.headline)
                Text("\(device.brand.name) · \(device.host):\(device.port)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var statusIcon: String {
        if isChecking { return "clock.arrow.circlepath" }
        switch device.isOnline {
        case true: return "checkmark.circle.fill"
        case false: return "xmark.circle.fill"
        default: return "questionmark.circle"
        }
    }

    private var statusColor: Color {
        if isChecking { return .blue }
        switch device.isOnline {
        case true: return .green
        case false: return .red
        default: return .secondary
        }
    }
}

struct DeviceDetailView: View {
    @EnvironmentObject private var store: DeviceStore
    let device: BarrierDevice
    let isChecking: Bool
    let onCheck: () -> Void

    @State private var showingCredential = false

    var body: some View {
        List {
            Section("后台") {
                LabeledContent("品牌", value: device.brand.name)
                LabeledContent("地址", value: device.displayAddress)
                if let lastCheckedAt = device.lastCheckedAt {
                    LabeledContent("上次检测", value: lastCheckedAt.formatted(date: .abbreviated, time: .shortened))
                }
                Button {
                    onCheck()
                } label: {
                    Label(isChecking ? "检测中" : "检测在线状态", systemImage: "network")
                }
                .disabled(isChecking)
                NavigationLink {
                    WebAdminView(device: device)
                } label: {
                    Label("打开后台", systemImage: "safari")
                }
            }

            Section("授权凭据") {
                if let credential = store.credential(for: device.id) {
                    LabeledContent("账号", value: credential.username)
                    Button {
                        showingCredential.toggle()
                    } label: {
                        Label(showingCredential ? "隐藏密码" : "显示密码", systemImage: showingCredential ? "eye.slash" : "eye")
                    }
                    if showingCredential {
                        Text(credential.password)
                            .font(.system(.body, design: .monospaced))
                    }
                } else {
                    Text("未保存账号")
                        .foregroundStyle(.secondary)
                }
            }

            if !device.note.isEmpty {
                Section("备注") {
                    Text(device.note)
                }
            }
        }
        .navigationTitle(device.name)
    }
}
