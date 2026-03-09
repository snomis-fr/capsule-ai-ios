//
//  TiptapWebView.swift
//  CapsuleAI
//

import SwiftUI
import WebKit

struct TiptapWebView: UIViewRepresentable {
    @Binding var contentJson: Data?
    @Binding var contentPlain: String
    var initialHtml: String? = nil
    var editorId: UUID? = nil
    var onContentChange: ((Data?, String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.userContentController.add(context.coordinator, name: "tiptapBridge")
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        context.coordinator.startObservingCommands()
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        context.coordinator.webView = webView
        if let url = Bundle.main.url(forResource: "tiptap-editor", withExtension: "html", subdirectory: nil)
            ?? Bundle.main.url(forResource: "tiptap-editor", withExtension: "html", subdirectory: "Resources") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        } else if let path = Bundle.main.path(forResource: "tiptap-editor", ofType: "html") {
            webView.load(URLRequest(url: URL(fileURLWithPath: path)))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.trySetContent(contentJson)
    }

    class Coordinator: NSObject, WKScriptMessageHandler {
        weak var webView: WKWebView?
        var parent: TiptapWebView
        var didSetInitialContent = false
        var hasReceivedReady = false

        private var observer: NSObjectProtocol?
        private var injectImageObserver: NSObjectProtocol?
        private var injectImageUrlObserver: NSObjectProtocol?
        private var injectYoutubeObserver: NSObjectProtocol?
        private var contentRequestObserver: NSObjectProtocol?
        private var injectHtmlObserver: NSObjectProtocol?

        init(_ parent: TiptapWebView) {
            self.parent = parent
        }

        deinit {
            if let o = observer { NotificationCenter.default.removeObserver(o) }
            if let o = injectImageObserver { NotificationCenter.default.removeObserver(o) }
            if let o = injectImageUrlObserver { NotificationCenter.default.removeObserver(o) }
            if let o = injectYoutubeObserver { NotificationCenter.default.removeObserver(o) }
            if let o = contentRequestObserver { NotificationCenter.default.removeObserver(o) }
            if let o = injectHtmlObserver { NotificationCenter.default.removeObserver(o) }
        }

        func startObservingCommands() {
            observer = NotificationCenter.default.addObserver(forName: .tiptapCommand, object: nil, queue: .main) { [weak self] notif in
                guard let (fn, arg) = notif.object as? (String, String?) else { return }
                let script: String
                if let a = arg {
                    let escaped = a.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
                    script = "if(window.\(fn)) window.\(fn)('\(escaped)');"
                } else {
                    script = "if(window.\(fn)) window.\(fn)();"
                }
                self?.webView?.evaluateJavaScript(script)
            }
            injectImageObserver = NotificationCenter.default.addObserver(forName: .tiptapInjectImage, object: nil, queue: .main) { [weak self] _ in
                guard let url = TiptapBridge.pendingImageDataUrl else { return }
                TiptapBridge.pendingImageDataUrl = nil
                let escaped = url.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
                let script = "if(window.tiptapImage) window.tiptapImage('\(escaped)');"
                self?.webView?.evaluateJavaScript(script)
            }
            injectImageUrlObserver = NotificationCenter.default.addObserver(forName: .tiptapInjectImageUrl, object: nil, queue: .main) { [weak self] notif in
                guard let url = notif.object as? String else { return }
                let escaped = url.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
                self?.webView?.evaluateJavaScript("if(window.setImageUrlFromBridge) window.setImageUrlFromBridge('\(escaped)');")
            }
            injectYoutubeObserver = NotificationCenter.default.addObserver(forName: .tiptapInjectYoutubeUrl, object: nil, queue: .main) { [weak self] notif in
                guard let url = notif.object as? String else { return }
                let escaped = url.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
                self?.webView?.evaluateJavaScript("if(window.setYoutubeFromBridge) window.setYoutubeFromBridge('\(escaped)');")
            }
            injectHtmlObserver = NotificationCenter.default.addObserver(forName: .tiptapInjectHTML, object: nil, queue: .main) { [weak self] notif in
                guard let html = notif.object as? String, let wv = self?.webView else { return }
                let b64 = Data(html.utf8).base64EncodedString()
                wv.evaluateJavaScript("if(window.insertHTMLFromBase64) window.insertHTMLFromBase64('\(b64)');")
            }
            contentRequestObserver = NotificationCenter.default.addObserver(forName: .tiptapContentRequest, object: nil, queue: .main) { [weak self] notif in
                let requestedId = notif.object as? UUID
                let myId = self?.parent.editorId
                if let rid = requestedId, let mid = myId, rid != mid {
                    return
                }
                guard let wv = self?.webView else {
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .tiptapContentReady, object: TiptapContentPayload(json: nil, plain: "", editorId: myId))
                    }
                    return
                }
                wv.evaluateJavaScript("JSON.stringify(window.getTiptapContent ? window.getTiptapContent() : {json:{type:'doc',content:[]},text:''})") { result, _ in
                    var jsonData: Data?
                    var plainText = ""
                    if let jsonStr = result as? String,
                       let data = jsonStr.data(using: .utf8),
                       let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let jsonObj = parsed["json"] {
                            jsonData = try? JSONSerialization.data(withJSONObject: jsonObj)
                        }
                        plainText = (parsed["text"] as? String) ?? ""
                    }
                    DispatchQueue.main.async {
                        self?.parent.onContentChange?(jsonData, plainText)
                        NotificationCenter.default.post(name: .tiptapContentReady, object: TiptapContentPayload(json: jsonData, plain: plainText, editorId: myId))
                    }
                }
            }
        }

        /// Tente d'injecter le contenu quand il devient disponible (ex. après loadNote).
        /// Appelé depuis updateUIView pour gérer le cas où "ready" arrive avant contentJson.
        func trySetContent(_ jsonData: Data?) {
            guard hasReceivedReady else { return }
            setContent(jsonData)
        }

        func setContent(_ jsonData: Data?) {
            guard let wv = webView, !didSetInitialContent else { return }
            if let html = parent.initialHtml, !html.isEmpty {
                didSetInitialContent = true
                let b64 = Data(html.utf8).base64EncodedString()
                wv.evaluateJavaScript("if(window.setContentHTMLFromBase64) window.setContentHTMLFromBase64('\(b64)');")
                return
            }
            guard let json = jsonData else { return }
            didSetInitialContent = true
            let b64 = json.base64EncodedString()
            wv.evaluateJavaScript("""
                if(window.setTiptapContent){
                    try{
                        var dec=(window.decodeBase64Utf8||function(b){return atob(b)})('\(b64)');
                        var j=JSON.parse(dec);
                        window.setTiptapContent(j);
                    }catch(e){}
                }
                """)
        }

        func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "tiptapBridge", let body = message.body as? String,
                  let data = body.data(using: .utf8),
                  let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let type = parsed["type"] as? String else { return }
            if type == "ready" {
                hasReceivedReady = true
                setContent(parent.contentJson)
            } else if type == "content" {
                let json = (parsed["json"] as? [String: Any]).flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                let text = parsed["text"] as? String ?? ""
                DispatchQueue.main.async {
                    self.parent.onContentChange?(json, text)
                }
            } else if type == "ai_action", let action = parsed["action"] as? String {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .tiptapAIAction, object: action)
                }
            } else if type == "request_image_gallery" {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .tiptapRequestImageGallery, object: nil)
                }
            } else if type == "request_image_url" {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .tiptapRequestImageUrl, object: nil)
                }
            } else if type == "request_youtube_url" {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .tiptapRequestYoutubeUrl, object: nil)
                }
            }
        }
    }
}
