//
//  BookmarkWebView.swift
//  Lystaria
//
//  Created by Asteria Moon on 3/19/26.
//

import SwiftUI
import WebKit

struct BookmarkWebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        
        // Styling to match your glass UI
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        
        // Behavior
        webView.scrollView.keyboardDismissMode = .onDrag
        webView.allowsBackForwardNavigationGestures = true
        
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Prevent reload loop
        if webView.url != url {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
}
