import SwiftUI
import WebKit

/// A SwiftUI view that loads the Kagi login page and extracts the `kagi_session` cookie after login.
struct LoginWebView: UIViewRepresentable {
    /// Called with the token if login is successful, or nil if cancelled.
    var onComplete: (String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onComplete: onComplete)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        let url = URL(string: "https://kagi.com/signin")!
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    class Coordinator: NSObject, WKNavigationDelegate {
        let onComplete: (String?) -> Void

        init(onComplete: @escaping (String?) -> Void) {
            self.onComplete = onComplete
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            // Try to extract the kagi_session cookie after each navigation event.
            webView.configuration.websiteDataStore.httpCookieStore.getAllCookies { cookies in
                if let cookie = cookies.first(where: { $0.name == "kagi_session" }) {
                    self.onComplete(cookie.value)
                }
            }
        }
    }
}
