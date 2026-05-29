import AppKit
import SwiftUI
import Combine
import Shared

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    let usageService = UsageService()
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        buildMainMenu()
        buildStatusItem()
        buildPopover()
        bindMenuBarText()
        NotificationCenter.default.addObserver(self, selector: #selector(openSettings),
                                               name: .openSettings, object: nil)
    }

    private func buildMainMenu() {
        let menu = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit ClaudeMeter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu
        menu.addItem(appItem)

        // Edit menu — necessario per Cut/Copy/Paste/SelectAll
        let editItem = NSMenuItem()
        editItem.title = "Edit"
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Cut",        action: #selector(NSText.cut(_:)),       keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",       action: #selector(NSText.copy(_:)),      keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",      action: #selector(NSText.paste(_:)),     keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = editMenu
        menu.addItem(editItem)

        NSApp.mainMenu = menu
    }

    // MARK: - Status bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let btn = statusItem.button else { return }
        btn.image = NSImage(systemSymbolName: "speedometer", accessibilityDescription: "ClaudeMeter")
        btn.imagePosition = .imageLeft
        btn.title = "  --"
        btn.imageHugsTitle = true
        btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        btn.action = #selector(handleClick(_:))
        btn.target = self
    }

    private func buildPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 380)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: PopoverView().environmentObject(usageService)
        )
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePopover()
        }
    }

    private func bindMenuBarText() {
        usageService.$limits
            .receive(on: DispatchQueue.main)
            .sink { [weak self] limits in
                guard let self else { return }
                self.statusItem.button?.image = self.drawBars(limits)
                let text = limits.isEmpty ? "  --" : "  \(limits.map { String(format: "%.0f%%", $0.percent) }.joined(separator: " · "))"
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .semibold),
                    .foregroundColor: NSColor.labelColor
                ]
                self.statusItem.button?.attributedTitle = NSAttributedString(string: text, attributes: attrs)
            }
            .store(in: &cancellables)
    }

    private func drawBars(_ limits: [UsageLimit]) -> NSImage {
        let cells    = 10
        let cellW: CGFloat = 5
        let cellH: CGFloat = 5
        let cellGap: CGFloat = 1.5
        let rowGap: CGFloat  = 3
        let rows   = max(min(limits.count, 2), 1)
        let totalW = CGFloat(cells) * cellW + CGFloat(cells - 1) * cellGap
        let totalH = CGFloat(rows) * cellH + CGFloat(rows - 1) * rowGap

        let img = NSImage(size: NSSize(width: totalW, height: totalH), flipped: false) { _ in
            for (row, limit) in Array(limits.prefix(2)).enumerated() {
                let fullCells = Int(limit.percent / 10.0)
                let partial   = (limit.percent / 10.0) - Double(fullCells)
                let y = totalH - cellH - CGFloat(row) * (cellH + rowGap)
                let color = self.segmentColor(limit.percent)
                // celle vuote: labelColor adattivo (bianco su dark, nero su light)
                // alpha 0.30 = struttura visibile anche quando la menu bar è dimmed
                let emptyColor = NSColor.labelColor.withAlphaComponent(0.30)

                for col in 0..<cells {
                    let x = CGFloat(col) * (cellW + cellGap)
                    let rect = NSRect(x: x, y: y, width: cellW, height: cellH)
                    let path = NSBezierPath(roundedRect: rect, xRadius: 1, yRadius: 1)

                    if col < fullCells {
                        color.setFill()
                        path.fill()
                    } else if col == fullCells && partial > 0.05 {
                        // cella parziale: sfondo vuoto + fill proporzionale alla larghezza
                        emptyColor.setFill(); path.fill()
                        let fillW = max(1, cellW * CGFloat(partial))
                        let fillRect = NSRect(x: x, y: y, width: fillW, height: cellH)
                        let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 1, yRadius: 1)
                        color.setFill(); fillPath.fill()
                    } else {
                        emptyColor.setFill()
                        path.fill()
                    }
                }
            }
            return true
        }
        img.isTemplate = false  // mantiene i colori
        return img
    }

    private func segmentColor(_ pct: Double) -> NSColor {
        let c = SegmentedBar.color(for: pct)
        return NSColor(cgColor: c.cgColor!) ?? .systemOrange
    }

    // MARK: - Settings window

    @objc func openSettings() {
        closePopover()

        // Passa a .regular così il paste funziona su macOS 12
        NSApp.setActivationPolicy(.regular)

        if let w = settingsWindow, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let view = SettingsView().environmentObject(usageService)
        let hosting = NSHostingController(rootView: view)

        let window = NSWindow(contentViewController: hosting)
        window.title = "ClaudeMeter Settings"
        window.styleMask = [.titled, .closable]
        window.setContentSize(NSSize(width: 420, height: 360))
        window.center()
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        window.delegate = self
        settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Actions

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            showContextMenu(sender)
        } else {
            if popover.isShown { closePopover() } else { openPopover(sender) }
        }
    }

    private func showContextMenu(_ sender: NSStatusBarButton) {
        closePopover()
        let menu = NSMenu()
        menu.addItem(withTitle: "Open Claude", action: #selector(openClaude), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Refresh", action: #selector(refreshAction), keyEquivalent: "r")
        menu.addItem(withTitle: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit ClaudeMeter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items { item.target = self }
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func refreshAction() {
        usageService.refresh()
    }

    @objc private func openClaude() {
        let appURL = URL(fileURLWithPath: "/Applications/Claude.app")
        if FileManager.default.fileExists(atPath: appURL.path) {
            NSWorkspace.shared.open(appURL)
        } else {
            NSWorkspace.shared.open(URL(string: "https://claude.ai")!)
        }
    }

    private func openPopover(_ sender: NSStatusBarButton) {
        popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func closePopover() {
        popover.performClose(nil)
    }
}

extension AppDelegate: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        // Torna ad accessory (niente icona nel Dock) quando la finestra si chiude
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
