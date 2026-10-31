//
//  WebViewContainer.swift
//  MacOSMediaCenter
//

import SwiftUI
import WebKit

struct WebViewContainer: NSViewRepresentable {
    let url: URL
    @Binding var canGoBack: Bool
    let playbackController: WebViewPlaybackController
    
    // Critical desktop Safari User-Agent for FairPlay/DRM streaming playback
    private let safariUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Safari/605.1.15"

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // 1. Persistent Cookie/Storage Store (Preserves logins across app restarts)
        configuration.websiteDataStore = WKWebsiteDataStore.default()
        
        // 2. AirPlay & Autoplay permissions
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // 3. HTML5 Fullscreen support
        let preferences = WKPreferences()
        preferences.isElementFullscreenEnabled = true
        configuration.preferences = preferences

        let webView = KeyboardEnabledWebView(frame: .zero, configuration: configuration)
        playbackController.attach(webView)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = safariUserAgent
        webView.allowsBackForwardNavigationGestures = true

        let request = URLRequest(url: url)
        webView.load(request)

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Prevent unwanted reloads
    }

    static func dismantleNSView(_ nsView: WKWebView, coordinator: Coordinator) {
        coordinator.parent.playbackController.stopPlayback(in: nsView)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewContainer

        init(_ parent: WebViewContainer) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.canGoBack = webView.canGoBack
            }
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }

    final class WebViewPlaybackController: ObservableObject {
        private weak var webView: WKWebView?

        func attach(_ webView: WKWebView) {
            self.webView = webView
        }

        func stopPlayback() {
            guard let webView else { return }
            stopPlayback(in: webView)
        }

        fileprivate func stopPlayback(in webView: WKWebView) {
            webView.evaluateJavaScript(Self.stopPlaybackScript) { _, error in
                if let error {
                    print("Unable to pause embedded media during player dismissal: \(error)")
                }
                webView.stopLoading()
            }
            if self.webView === webView {
                self.webView = nil
            }
        }

        static let stopPlaybackScript = """
        (() => {
          const pauseMedia = (root) => {
            root.querySelectorAll('audio, video').forEach((media) => {
              try { media.pause(); } catch (_) {}
            });
            root.querySelectorAll('iframe').forEach((frame) => {
              try {
                if (frame.contentDocument) pauseMedia(frame.contentDocument);
              } catch (_) {}
            });
          };
          pauseMedia(document);
          window.dispatchEvent(new Event('pagehide'));
        })();
        """
    }

    private final class KeyboardEnabledWebView: WKWebView {
        override var acceptsFirstResponder: Bool {
            true
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            window?.makeFirstResponder(self)
            super.mouseDown(with: event)
        }
    }
}
