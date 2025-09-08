//
//  FuturePanelApp.swift
//  FuturePanel
//
//  Created by rocky on 2025/9/8.
//

import SwiftUI

@main
struct FuturePanelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settingsStore = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settingsStore)
                .background(TransparentBackgroundView(opacity: settingsStore.settings.windowOpacity))
                .windowLevel(alwaysOnTop: settingsStore.settings.alwaysOnTop)
                .onAppear { appDelegate.settingsStore = settingsStore }
        }
        Settings {
            SettingsView(store: settingsStore)
                .background(SettingsWindowLevelHelper())
        }
    }
}

// Helpers for macOS window customization
import AppKit

struct TransparentBackgroundView: NSViewRepresentable {
    let opacity: Double
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.blendingMode = .behindWindow
        v.material = .underWindowBackground
        v.state = .active
        v.alphaValue = CGFloat(opacity)
        v.isEmphasized = true
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.alphaValue = CGFloat(opacity)
    }
}

extension View {
    func windowLevel(alwaysOnTop: Bool) -> some View {
        self.background(WindowConfigurator(alwaysOnTop: alwaysOnTop))
    }
}

// Transparent draggable area to move window (for borderless windows)
struct DraggableAreaView: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) {
            self.window?.performDrag(with: event)
        }
    }
    func makeNSView(context: Context) -> NSView {
        let v = DragView()
        v.wantsLayer = true
        v.layer?.backgroundColor = NSColor.clear.cgColor
        return v
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
struct SettingsWindowLevelHelper: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let win = view.window {
                win.level = .modalPanel
                win.isMovableByWindowBackground = true
                win.makeKeyAndOrderFront(nil)
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct WindowConfigurator: NSViewRepresentable {
    let alwaysOnTop: Bool
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            if let window = view.window {
                window.level = alwaysOnTop ? .floating : .normal
                window.isOpaque = false
                window.backgroundColor = .clear
                window.titleVisibility = .hidden
                window.titlebarAppearsTransparent = true
                window.styleMask = [.borderless, .fullSizeContentView, .resizable]
                window.isMovableByWindowBackground = true
                window.ignoresMouseEvents = false
                if let d = NSApp.delegate as? AppDelegate { d.mainWindow = window }
            }
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {
        if let window = nsView.window {
            window.level = alwaysOnTop ? .floating : .normal
        }
    }
}
