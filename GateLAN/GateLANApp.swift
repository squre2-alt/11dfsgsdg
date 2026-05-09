import SwiftUI

@main
struct GateLANApp: App {
    @StateObject private var store = DeviceStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
