//
//  TiptapReadOnlyView.swift
//  CapsuleAI
//
//  WebView en lecture seule avec scroll interne — pas de callback height (évite boucles infinies).
//

import SwiftUI
import WebKit

struct TiptapReadOnlyView: UIViewRepresentable {
    let contentJson: Data?

    func makeCoordinator() -> Coordinator {
        Coordinator(contentJson: contentJson)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        if let url = Bundle.main.url(forResource: "tiptap-readonly", withExtension: "html")
            ?? Bundle.main.url(forResource: "tiptap-readonly", withExtension: "html", subdirectory: "Resources") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        guard context.coordinator.pageLoaded else {
            context.coordinator.contentJson = contentJson
            return
        }
        if context.coordinator.contentJson != contentJson {
            context.coordinator.contentJson = contentJson
            context.coordinator.injectContent(into: webView)
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var contentJson: Data?
        var pageLoaded = false

        init(contentJson: Data?) {
            self.contentJson = contentJson
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            pageLoaded = true
            injectContent(into: webView)
        }

        func injectContent(into webView: WKWebView) {
            guard let json = contentJson else { return }
            let b64 = json.base64EncodedString()
            let script = """
                if(window.setTiptapReadOnlyContent){
                    try{
                        var dec=(window.decodeBase64Utf8||function(b){return atob(b)})('\(b64)');
                        var j=JSON.parse(dec);
                        window.setTiptapReadOnlyContent(j);
                    }catch(e){}
                }
                """
            webView.evaluateJavaScript(script)
        }
    }
}
