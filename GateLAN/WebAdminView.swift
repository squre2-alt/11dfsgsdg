import SwiftUI
import WebKit

struct WebAdminView: View {
    @EnvironmentObject private var store: DeviceStore
    let device: BarrierDevice
    @State private var showingSaved = false

    var body: some View {
        WebView(url: device.adminURL)
            .navigationTitle(device.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isSaved ? "已保存" : "保存") {
                        save()
                        showingSaved = true
                    }
                    .disabled(isSaved)
                }
            }
            .alert("已保存", isPresented: $showingSaved) {
                Button("知道了", role: .cancel) { }
            } message: {
                Text("这个后台已经加入“我的设备”。")
            }
    }

    private var isSaved: Bool {
        store.devices.contains {
            $0.host == device.host &&
            $0.port == device.port &&
            $0.scheme == device.scheme
        }
    }

    private func save() {
        guard !isSaved else { return }
        store.add(device, credential: nil)
    }
}

struct WebView: UIViewRepresentable {
    let url: URL?

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let url else { return }
        webView.load(URLRequest(url: url))
    }
}
