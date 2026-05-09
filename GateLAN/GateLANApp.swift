import SwiftUI

@main
struct GateLANApp: App {
    @StateObject private var store = DeviceStore()
    @StateObject private var localNetworkProbe = LocalNetworkPermissionProbe()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(localNetworkProbe)
        }
    }
}
