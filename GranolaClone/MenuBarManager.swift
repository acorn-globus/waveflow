import SwiftUI
import AppKit

class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    @Published var isListening: Bool = false
    
    init() {
        // Ensure we're on the main thread
        DispatchQueue.main.async { [weak self] in
            self?.setupMenuBar()
        }
    }
    
    private func setupMenuBar() {
        // Create the status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "mic", accessibilityDescription: "Transcription")
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // Start/Stop Recording Menu Item
        let toggleItem = NSMenuItem(
            title: "Start Listening",
            action: #selector(toggleListening),
            keyEquivalent: "t"
        )
        toggleItem.target = self
        menu.addItem(toggleItem)
        
        // Separator
        menu.addItem(NSMenuItem.separator())
        
        // Show/Hide Window
        let showWindowItem = NSMenuItem(
            title: "Show Transcription Window",
            action: #selector(showMainWindow),
            keyEquivalent: "s"
        )
        showWindowItem.target = self
        menu.addItem(showWindowItem)
        
        // Quit
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(
            title: "Quit",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc private func toggleListening() {
        DispatchQueue.main.async {
            self.isListening.toggle()
            self.updateMenuBar()
        }
    }
    
    private func updateMenuBar() {
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: isListening ? "mic.fill" : "mic",
                accessibilityDescription: "Transcription"
            )
            
            if let toggleItem = statusItem?.menu?.item(at: 0) {
                toggleItem.title = isListening ? "Stop Listening" : "Start Listening"
            }
        }
    }
    
    @objc private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }
    
    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }
}
