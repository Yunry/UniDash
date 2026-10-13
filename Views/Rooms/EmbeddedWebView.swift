//
//  EmbeddedWebView.swift
//  UniDash
//
//  Cross-platform WebKit view wrapper for in-app Anny study room bookings & LMU Raumfinder (iOS & macOS).
//

import SwiftUI
import WebKit

enum RaumfinderJSBridge {
    static func locatorScript(roomKey: String?, query: String?) -> String {
        let safeKey = (roomKey ?? "").replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        let safeQuery = (query ?? "").replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        return """
        (function() {
            var targetKey = '\(safeKey)';
            var targetQuery = '\(safeQuery)';
            function tryLocate() {
                try {
                    var el = document.querySelector('.map') || document.body;
                    var scope = angular.element(el).scope();
                    if (!scope || typeof scope.mapViaRoom !== 'function') return false;

                    if (targetKey && targetKey.length > 0) {
                        scope.mapViaRoom(targetKey);
                        return true;
                    }

                    var ctrlEl = document.querySelector('[ng-controller*="mapCtrl"]') || el;
                    var ctrl = angular.element(ctrlEl).controller();
                    if (ctrl && ctrl.rooms && ctrl.rooms.data) {
                        var clean = targetQuery.replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
                        if (!clean) return false;
                        for (var rCode in ctrl.rooms.data) {
                            var room = ctrl.rooms.data[rCode];
                            var rName = (room.rName || '').replace(/[^a-zA-Z0-9]/g, '').toLowerCase();
                            if (rName === clean || rName.indexOf(clean) !== -1 || rCode.toLowerCase().indexOf(clean) !== -1) {
                                scope.mapViaRoom(rCode);
                                return true;
                            }
                        }
                    }
                } catch(e) {}
                return false;
            }
            if (!tryLocate()) {
                var count = 0;
                var timer = setInterval(function() {
                    count++;
                    if (tryLocate() || count > 14) {
                        clearInterval(timer);
                    }
                }, 250);
            }
        })();
        """
    }
}

#if canImport(UIKit)
import UIKit

struct EmbeddedWebView: UIViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var targetRoomKey: String? = nil
    var targetRoomQuery: String? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        let request = URLRequest(url: url)
        webView.load(request)
        context.coordinator.currentURL = url
        context.coordinator.lastRoomKey = targetRoomKey
        context.coordinator.lastRoomQuery = targetRoomQuery
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let urlChanged = context.coordinator.currentURL != url
        let roomChanged = context.coordinator.lastRoomKey != targetRoomKey || context.coordinator.lastRoomQuery != targetRoomQuery

        if urlChanged {
            let oldURL = context.coordinator.currentURL
            context.coordinator.currentURL = url
            context.coordinator.lastRoomKey = targetRoomKey
            context.coordinator.lastRoomQuery = targetRoomQuery

            if let old = oldURL, old.host == url.host && old.path == url.path {
                let script = """
                (function() {
                    var newURL = "\(url.absoluteString)";
                    var hashIdx = newURL.indexOf('#');
                    if (hashIdx !== -1) {
                        var newHash = newURL.substring(hashIdx);
                        if (window.location.hash !== newHash) {
                            window.location.hash = newHash;
                        }
                    }
                })();
                """
                uiView.evaluateJavaScript(script) { _, _ in
                    if self.targetRoomKey != nil || self.targetRoomQuery != nil {
                        uiView.evaluateJavaScript(RaumfinderJSBridge.locatorScript(roomKey: self.targetRoomKey, query: self.targetRoomQuery), completionHandler: nil)
                    }
                }
            } else {
                let request = URLRequest(url: url)
                uiView.load(request)
            }
        } else if roomChanged {
            context.coordinator.lastRoomKey = targetRoomKey
            context.coordinator.lastRoomQuery = targetRoomQuery
            if targetRoomKey != nil || targetRoomQuery != nil {
                uiView.evaluateJavaScript(RaumfinderJSBridge.locatorScript(roomKey: targetRoomKey, query: targetRoomQuery), completionHandler: nil)
            }
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: EmbeddedWebView
        var currentURL: URL?
        var lastRoomKey: String?
        var lastRoomQuery: String?

        init(_ parent: EmbeddedWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                self.parent.isLoading = false
            }
            if self.parent.targetRoomKey != nil || self.parent.targetRoomQuery != nil || self.parent.url.absoluteString.contains("room=") {
                let script = RaumfinderJSBridge.locatorScript(roomKey: self.parent.targetRoomKey, query: self.parent.targetRoomQuery)
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                self.parent.isLoading = false
            }
        }
    }
}

#elseif canImport(AppKit)
import AppKit

struct EmbeddedWebView: NSViewRepresentable {
    let url: URL
    @Binding var isLoading: Bool
    var targetRoomKey: String? = nil
    var targetRoomQuery: String? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        let request = URLRequest(url: url)
        webView.load(request)
        context.coordinator.currentURL = url
        context.coordinator.lastRoomKey = targetRoomKey
        context.coordinator.lastRoomQuery = targetRoomQuery
        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        let urlChanged = context.coordinator.currentURL != url
        let roomChanged = context.coordinator.lastRoomKey != targetRoomKey || context.coordinator.lastRoomQuery != targetRoomQuery

        if urlChanged {
            let oldURL = context.coordinator.currentURL
            context.coordinator.currentURL = url
            context.coordinator.lastRoomKey = targetRoomKey
            context.coordinator.lastRoomQuery = targetRoomQuery

            if let old = oldURL, old.host == url.host && old.path == url.path {
                let script = """
                (function() {
                    var newURL = "\(url.absoluteString)";
                    var hashIdx = newURL.indexOf('#');
                    if (hashIdx !== -1) {
                        var newHash = newURL.substring(hashIdx);
                        if (window.location.hash !== newHash) {
                            window.location.hash = newHash;
                        }
                    }
                })();
                """
                nsView.evaluateJavaScript(script) { _, _ in
                    if self.targetRoomKey != nil || self.targetRoomQuery != nil {
                        nsView.evaluateJavaScript(RaumfinderJSBridge.locatorScript(roomKey: self.targetRoomKey, query: self.targetRoomQuery), completionHandler: nil)
                    }
                }
            } else {
                let request = URLRequest(url: url)
                nsView.load(request)
            }
        } else if roomChanged {
            context.coordinator.lastRoomKey = targetRoomKey
            context.coordinator.lastRoomQuery = targetRoomQuery
            if targetRoomKey != nil || targetRoomQuery != nil {
                nsView.evaluateJavaScript(RaumfinderJSBridge.locatorScript(roomKey: targetRoomKey, query: targetRoomQuery), completionHandler: nil)
            }
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        var parent: EmbeddedWebView
        var currentURL: URL?
        var lastRoomKey: String?
        var lastRoomQuery: String?

        init(_ parent: EmbeddedWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                self.parent.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                self.parent.isLoading = false
            }
            if self.parent.targetRoomKey != nil || self.parent.targetRoomQuery != nil || self.parent.url.absoluteString.contains("room=") {
                let script = RaumfinderJSBridge.locatorScript(roomKey: self.parent.targetRoomKey, query: self.parent.targetRoomQuery)
                webView.evaluateJavaScript(script, completionHandler: nil)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                self.parent.isLoading = false
            }
        }
    }
}
#endif

