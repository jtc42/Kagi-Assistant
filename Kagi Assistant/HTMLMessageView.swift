//
//  HTMLMessageView.swift
//  Kagi Assistant
//

import UIKit
import SwiftUI
import WebKit

struct HTMLMessageView: UIViewRepresentable {
    let html: String
    @Binding var dynamicHeight: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.suppressesIncrementalRendering = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false

        context.coordinator.webView = webView

        let shell = Self.shellHTML()
        webView.loadHTMLString(shell, baseURL: nil)

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.updateContent(html)
    }

    /// The page shell — loaded once. Contains the height observer
    /// and a `setContent()` JS function for incremental updates.
    /// Styles are loaded from bundled CSS files.
    static func shellHTML() -> String {
        let css = ["message", "codehilite"]
            .compactMap { name in
                guard let url = Bundle.main.url(forResource: name, withExtension: "css"),
                      let contents = try? String(contentsOf: url, encoding: .utf8) else {
                    return nil
                }
                return contents
            }
            .joined(separator: "\n\n")

        return """
        <!DOCTYPE html>
        <html>
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>\(css)</style>
        </head>
        <body>
        <div id="content"></div>
        <script>
            function notifyHeight() {
                requestAnimationFrame(() => {
                    const content = document.getElementById('content');
                    const h = Math.ceil(content.getBoundingClientRect().bottom);
                    window.webkit.messageHandlers.heightChanged.postMessage(h);
                });
            }

            function updateCopyButton(button, copied) {
                button.textContent = copied ? 'Copied' : 'Copy';
                button.dataset.copied = copied ? 'true' : 'false';
            }

            function requestCopy(button, getText) {
                const text = getText();
                if (!text) return;

                window.webkit.messageHandlers.copyToClipboard.postMessage(text);
                updateCopyButton(button, true);

                if (button._copyTimer) {
                    clearTimeout(button._copyTimer);
                }
                button._copyTimer = setTimeout(() => updateCopyButton(button, false), 1500);
            }

            function createCopyButton(getText) {
                const button = document.createElement('button');
                button.type = 'button';
                button.className = 'copy-button';
                updateCopyButton(button, false);
                button.addEventListener('click', (event) => {
                    event.preventDefault();
                    event.stopPropagation();
                    requestCopy(button, getText);
                });
                return button;
            }


            function createCodeBlockHeader(label, getText) {
                const header = document.createElement('div');
                header.className = 'code-block-header';

                const title = document.createElement('span');
                title.className = 'code-block-title';
                title.textContent = label || 'Code';

                header.appendChild(title);
                header.appendChild(createCopyButton(getText));
                return header;
            }

            function codeHiliteLabel(pre) {
                const container = pre.parentElement;
                if (!container || !container.classList.contains('codehilite')) return '';

                const filename = Array.from(container.children).find((child) => child.classList && child.classList.contains('filename'));
                if (!filename) return '';

                const label = (filename.innerText || '').trim();
                filename.remove();
                return label;
            }

            function enhanceCodeBlocks() {
                document.querySelectorAll('pre').forEach((pre) => {
                    if (pre.dataset.copyEnhanced === 'true') return;

                    const code = pre.querySelector('code');
                    const target = code || pre;
                    const text = (target.innerText || '').trim();
                    if (!text) return;

                    let container = pre.parentElement;
                    const hasLanguage = container && container.classList.contains('codehilite');

                    if (!hasLanguage) {
                        // Plain code block — wrap in styled container but no header
                        container = document.createElement('div');
                        container.className = 'code-block';
                        pre.parentNode.insertBefore(container, pre);
                        container.appendChild(pre);
                    } else {
                        const label = codeHiliteLabel(pre);
                        container.classList.add('code-block');

                        const hasHeader = Array.from(container.children).some((child) => child.classList && child.classList.contains('code-block-header'));
                        if (!hasHeader) {
                            container.insertBefore(
                                createCodeBlockHeader(label, () => (target.innerText || '').trim()),
                                container.firstChild
                            );
                        }
                    }

                    pre.dataset.copyEnhanced = 'true';
                    pre.classList.add('copyable-pre');
                });

            }

            const observer = new MutationObserver(notifyHeight);
            observer.observe(document.body, { childList: true, subtree: true, characterData: true });
            window.addEventListener('load', notifyHeight);

            function enhanceTables() {
                document.querySelectorAll('table').forEach((table) => {
                    if (table.parentElement && table.parentElement.classList.contains('table-wrapper')) return;
                    const wrapper = document.createElement('div');
                    wrapper.className = 'table-wrapper';
                    table.parentNode.insertBefore(wrapper, table);
                    wrapper.appendChild(table);
                });
            }

            function setContent(html) {
                document.getElementById('content').innerHTML = html;
                enhanceCodeBlocks();
                enhanceTables();
                notifyHeight();
            }
        </script>
        </body>
        </html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: HTMLMessageView
        private var pageReady = false
        private var pendingHTML: String?

        weak var webView: WKWebView? {
            didSet {
                webView?.configuration.userContentController.add(self, name: "heightChanged")
                webView?.configuration.userContentController.add(self, name: "copyToClipboard")
            }
        }

        init(_ parent: HTMLMessageView) {
            self.parent = parent
        }

        deinit {
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "heightChanged")
            webView?.configuration.userContentController.removeScriptMessageHandler(forName: "copyToClipboard")
        }

        func updateContent(_ html: String) {
            if pageReady {
                injectHTML(html)
            } else {
                pendingHTML = html
            }
        }

        private func injectHTML(_ html: String) {
            guard let webView else { return }
            // Escape for JS string literal
            let escaped = html
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "${", with: "\\${")
            webView.evaluateJavaScript("setContent(`\(escaped)`)") { _, _ in }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageReady = true
            // Inject any content that arrived before the page was ready
            if let pending = pendingHTML {
                pendingHTML = nil
                injectHTML(pending)
            } else {
                injectHTML(parent.html)
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            if navigationAction.navigationType == .linkActivated, let url = navigationAction.request.url {
                UIApplication.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "heightChanged":
                guard let height = message.body as? CGFloat, height > 0 else { return }
                DispatchQueue.main.async {
                    self.parent.dynamicHeight = height
                }
            case "copyToClipboard":
                guard let text = message.body as? String else { return }
                UIPasteboard.general.string = text
            default:
                break
            }
        }
    }
}
