//
//  HtmlContentView.swift
//  CapsuleAI
//

import SwiftUI
import WebKit

/// Affiche du HTML avec un rendu riche (titres, listes, gras, etc.)
struct HtmlContentView: UIViewRepresentable {
    let html: String

    private static let baseStyle = """
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
            body { margin: 0; padding: 16px; font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 16px; line-height: 1.5; color: #1d1d1f; }
            h2 { font-size: 1.25rem; font-weight: 600; margin: 1em 0 0.5em; color: #1d1d1f; }
            h3 { font-size: 1.1rem; font-weight: 600; margin: 0.9em 0 0.4em; color: #1d1d1f; }
            h4 { font-size: 1rem; font-weight: 600; margin: 0.8em 0 0.3em; }
            p { margin: 0.5em 0; }
            ul, ol { margin: 0.5em 0; padding-left: 1.5em; }
            li { margin: 0.25em 0; }
            strong { font-weight: 600; }
            blockquote { border-left: 4px solid #e2e8f0; padding-left: 16px; margin: 0.75em 0; color: #64748b; }
            a { color: #3B82F6; text-decoration: underline; }
        </style>
        """

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.dataDetectorTypes = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let wrapped = html.trimmingCharacters(in: .whitespaces).hasPrefix("<")
            ? html
            : "<p>\(html.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;").replacingOccurrences(of: "\n", with: "<br>"))</p>"
        let fullHtml = """
            <!DOCTYPE html><html><head>\(Self.baseStyle)</head><body>\(wrapped)</body></html>
            """
        webView.loadHTMLString(fullHtml, baseURL: nil)
    }
}
