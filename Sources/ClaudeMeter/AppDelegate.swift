import AppKit
import ServiceManagement
import ClaudeMeterCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let client = UsageClient()
    private var timer: Timer?
    private var lastUsage: Usage?
    private var lastError: UsageError?

    /// User-selectable refresh cadence, persisted in UserDefaults.
    private var interval: TimeInterval {
        get { let v = UserDefaults.standard.double(forKey: "refreshInterval"); return v > 0 ? v : 300 }
        set { UserDefaults.standard.set(newValue, forKey: "refreshInterval"); restartTimer() }
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "gauge.with.dots.needle.50percent",
                                   accessibilityDescription: "Claude usage")
            button.imagePosition = .imageLeading
            button.title = " …"
        }
        statusItem.menu = buildMenu()
        refresh()
        restartTimer()
    }

    // MARK: - Refresh

    private func restartTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    @objc private func refresh() {
        client.fetch { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let usage): self.lastUsage = usage; self.lastError = nil
            case .failure(let err): self.lastError = err
            }
            self.render()
        }
    }

    // MARK: - Rendering

    private func render() {
        guard let button = statusItem.button else { return }
        if let usage = lastUsage {
            button.title = " " + Formatting.menuBarTitle(session: usage.session, week: usage.week)
            button.contentTintColor = color(for: Formatting.peakLevel(usage))
        } else if let err = lastError {
            button.title = " ⚠"
            button.contentTintColor = .systemRed
            button.toolTip = err.description
        }
        statusItem.menu = buildMenu()
    }

    private func color(for level: Formatting.Level) -> NSColor? {
        switch level {
        case .normal: return nil               // default menu-bar tint
        case .warning: return .systemOrange
        case .critical: return .systemRed
        }
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let now = Date()

        if let usage = lastUsage {
            addWindow(to: menu, label: "Session (5h)", window: usage.session, now: now)
            addWindow(to: menu, label: "Week (7d)", window: usage.week, now: now)
            if usage.weekSonnet != nil { addWindow(to: menu, label: "Week · Sonnet", window: usage.weekSonnet, now: now) }
            if usage.weekOpus != nil { addWindow(to: menu, label: "Week · Opus", window: usage.weekOpus, now: now) }
            if let extra = usage.extra, extra.isEnabled, let u = extra.utilization {
                menu.addItem(.separator())
                menu.addItem(disabledItem("Extra usage: \(Formatting.percent(u))"))
            }
            menu.addItem(.separator())
            menu.addItem(disabledItem("Updated \(Formatting.relativeAge(usage.fetchedAt, now: now))"))
        } else if let err = lastError {
            menu.addItem(disabledItem(err.description))
        } else {
            menu.addItem(disabledItem("Loading…"))
        }

        menu.addItem(.separator())
        menu.addItem(item("Refresh now", action: #selector(refresh), key: "r"))
        menu.addItem(intervalSubmenu())
        menu.addItem(launchAtLoginItem())
        menu.addItem(.separator())
        menu.addItem(item("Quit Claude Meter", action: #selector(quit), key: "q"))
        return menu
    }

    private func addWindow(to menu: NSMenu, label: String, window: UsageWindow?, now: Date) {
        guard let window else { return }
        var title = "\(label):  \(Formatting.gauge(window.utilization))  \(Formatting.percent(window.utilization))"
        if let resets = Formatting.resetsIn(window.resetsAt, now: now) { title += "  · resets \(resets)" }
        let it = disabledItem(title)
        it.attributedTitle = NSAttributedString(string: title, attributes: [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        ])
        menu.addItem(it)
    }

    private func intervalSubmenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Refresh every", action: nil, keyEquivalent: "")
        let sub = NSMenu()
        for (label, secs) in [("1 min", 60.0), ("5 min", 300.0), ("15 min", 900.0)] {
            let it = NSMenuItem(title: label, action: #selector(setInterval(_:)), keyEquivalent: "")
            it.target = self
            it.representedObject = secs
            it.state = (abs(secs - interval) < 1) ? .on : .off
            sub.addItem(it)
        }
        parent.submenu = sub
        return parent
    }

    @objc private func setInterval(_ sender: NSMenuItem) {
        if let secs = sender.representedObject as? Double { interval = secs }
    }

    // MARK: - Launch at login

    private func launchAtLoginItem() -> NSMenuItem {
        let it = item("Launch at Login", action: #selector(toggleLaunchAtLogin), key: "")
        it.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        return it
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change Login Items"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        statusItem.menu = buildMenu()
    }

    // MARK: - Helpers

    private func item(_ title: String, action: Selector, key: String) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.target = self
        return it
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        it.isEnabled = false
        return it
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
