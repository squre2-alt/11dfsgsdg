import Foundation
import SwiftUI

@MainActor
final class DeviceStore: ObservableObject {
    @Published var devices: [BarrierDevice] = [] {
        didSet { saveDevices() }
    }

    private let devicesKey = "barrier.devices.v1"
    private let keychain = KeychainStore(service: "com.local.gatelan.credentials")

    init() {
        loadDevices()
    }

    func add(_ device: BarrierDevice, credential: StoredCredential?) {
        devices.insert(device, at: 0)
        setCredential(credential, for: device.id)
    }

    func update(_ device: BarrierDevice, credential: StoredCredential?) {
        guard let index = devices.firstIndex(where: { $0.id == device.id }) else { return }
        devices[index] = device
        setCredential(credential, for: device.id)
    }

    func delete(at offsets: IndexSet) {
        for index in offsets {
            keychain.delete(account: devices[index].id.uuidString)
        }
        devices.remove(atOffsets: offsets)
    }

    func credential(for id: UUID) -> StoredCredential? {
        guard let data = keychain.read(account: id.uuidString) else { return nil }
        return try? JSONDecoder().decode(StoredCredential.self, from: data)
    }

    func setCredential(_ credential: StoredCredential?, for id: UUID) {
        guard let credential else {
            keychain.delete(account: id.uuidString)
            return
        }
        guard let data = try? JSONEncoder().encode(credential) else { return }
        keychain.save(data, account: id.uuidString)
    }

    func mark(_ id: UUID, online: Bool) {
        guard let index = devices.firstIndex(where: { $0.id == id }) else { return }
        devices[index].isOnline = online
        devices[index].lastCheckedAt = Date()
    }

    private func loadDevices() {
        guard let data = UserDefaults.standard.data(forKey: devicesKey),
              let decoded = try? JSONDecoder().decode([BarrierDevice].self, from: data) else {
            return
        }
        devices = decoded
    }

    private func saveDevices() {
        guard let data = try? JSONEncoder().encode(devices) else { return }
        UserDefaults.standard.set(data, forKey: devicesKey)
    }
}
