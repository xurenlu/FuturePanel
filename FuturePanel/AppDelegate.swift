import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    weak var mainWindow: NSWindow?
    weak var settingsStore: SettingsStore?
    private var mouseMonitor: Any?
    private var unreadCount: Int = 0 {
        didSet { updateStatusTitle() }
    }
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Status bar item
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let btn = item.button {
            btn.image = NSImage(systemSymbolName: "rectangle.and.text.magnifyingglass", accessibilityDescription: "FuturePanel")
            btn.image?.isTemplate = true
            btn.title = "LogHUD"
        }
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "打开面板", action: #selector(openMain), keyEquivalent: "")
        openItem.target = self
        let settingsItem = NSMenuItem(title: "设置…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        let quitItem = NSMenuItem(title: "退出", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(openItem)
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(quitItem)
        item.menu = menu
        self.statusItem = item

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            self?.updatePassThrough()
        }

        NotificationCenter.default.addObserver(self, selector: #selector(onNewMessage), name: .logAggregatorNewMessage, object: nil)
    }

    @objc private func openMain() {
        NSApp.activate(ignoringOtherApps: true)
        mainWindow?.makeKeyAndOrderFront(nil)
        unreadCount = 0
    }

    @objc private func openSettings() {
        guard let store = settingsStore else { return }
        if settingsWindow == nil {
            let vc = NSHostingController(rootView: SettingsView(store: store))
            let win = NSWindow(contentViewController: vc)
            win.styleMask = [NSWindow.StyleMask.titled,
                             NSWindow.StyleMask.closable,
                             NSWindow.StyleMask.miniaturizable,
                             NSWindow.StyleMask.resizable]
            win.title = "设置"
            win.setContentSize(NSSize(width: 840, height: 560))
            win.level = NSWindow.Level.modalPanel
            win.center()
            settingsWindow = win
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func updatePassThrough() {
        guard let window = mainWindow, let settings = settingsStore?.settings else { return }
        guard settings.passThroughWhenNotHovered else {
            window.ignoresMouseEvents = false
            return
        }
        let mouseScreenPoint = NSEvent.mouseLocation
        let windowFrame = window.frame
        let inside = windowFrame.contains(mouseScreenPoint)
        // 仅当不在窗口内且没有键盘焦点时忽略鼠标事件，防止输入框无法输入
        let hasFirstResponder = (window.firstResponder != nil)
        window.ignoresMouseEvents = (!inside && !hasFirstResponder)
    }

    @objc private func onNewMessage() {
        guard let window = mainWindow else { return }
        if !window.isKeyWindow || !window.isVisible {
            unreadCount += 1
        }
    }

    private func updateStatusTitle() {
        if unreadCount > 0 {
            statusItem?.button?.title = "LogHUD (\(unreadCount))"
        } else {
            statusItem?.button?.title = "LogHUD"
        }
    }
}


