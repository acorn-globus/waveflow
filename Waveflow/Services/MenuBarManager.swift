import SwiftUI
import AppKit

class MenuBarManager: ObservableObject {
    private var statusItem: NSStatusItem?
    @Published var createNewNoteCount = 0
    
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
            button.image = NSImage(named: "menuBarIcon")
            button.image?.isTemplate = true
        }
        
        setupMenu()
    }
    
    private func setupMenu() {
        let menu = NSMenu()
        
        // Start/Stop Recording Menu Item
        let createNewItem = NSMenuItem(
            title: "Create a New Note",
            action: #selector(createNewNote),
            keyEquivalent: "n"
        )
        createNewItem.target = self
        menu.addItem(createNewItem)
        
        // Separator
        menu.addItem(NSMenuItem.separator())
        
        // Show/Hide Window
        let showWindowItem = NSMenuItem(
            title: "Show All Notes",
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
    
    @objc private func createNewNote() {
        DispatchQueue.main.async {
            self.createNewNoteCount += 1
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
