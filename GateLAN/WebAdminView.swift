import SwiftUI
import WebKit

struct WebAdminView: View {
    let device: BarrierDevice

    var body: some View {
        WebView(url: device.adminURL)
            .navigationTitle(device.name)
            .navigationBarTitleDisplayMode(.inline)
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
