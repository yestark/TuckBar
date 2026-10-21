import AppKit
import ApplicationServices
import TuckBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var state = VisibilityState()
    private var toggleItem: NSStatusItem!
    private var dividerItem: NSStatusItem!
    private var helpWindow: NSWindow?
    private var collapseTimer: Timer?
    private let collection = CollectionPanel()
    private var captureTask: Task<Void, Never>?
    private var panelGeneration = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the toggle first: new items normally appear to its left.
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        toggleItem.autosaveName = "TuckBar.Toggle"
        toggleItem.behavior = []
        if let button = toggleItem.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        dividerItem = NSStatusBar.system.statusItem(withLength: 20)
        dividerItem.autosaveName = "TuckBar.Divider"
        dividerItem.behavior = []
        dividerItem.button?.title = "│"
        dividerItem.button?.toolTip = "按住 ⌘ 拖动：左侧图标会被收起，右侧图标常驻"
        dividerItem.button?.setAccessibilityLabel("TuckBar 隐藏区分隔线")
        dividerItem.button?.target = self
        dividerItem.button?.action = #selector(showHelp)
        NotificationCenter.default.addObserver(
            self, selector: #selector(refresh),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(refresh),
            name: NSWorkspace.didWakeNotification, object: nil
        )
        collection.onArrange = { [weak self] in self?.showHelp() }
        collection.onReload = { [weak self] in self?.showPanel() }
        collection.onPress = { [weak self] entry in self?.useEntry(entry) }
        refresh()
        if !UserDefaults.standard.bool(forKey: "hasShownSetup") {
            showHelp()

        } else {
            // Wait for macOS to restore saved menu bar positions before collapsing.
            collapseTimer = Timer.scheduledTimer(timeInterval: 1, target: self,
                selector: #selector(showPanel), userInfo: nil, repeats: false)
        }
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            addItem("打开收纳面板", action: #selector(showPanel), to: menu)
            addItem("在原菜单栏展开 / 收起", action: #selector(toggle), to: menu)
            addItem("整理图标与使用说明…", action: #selector(showHelp), to: menu)
            menu.addItem(.separator())
            addItem("退出 TuckBar", action: #selector(quit), to: menu)
            if let button = toggleItem.button {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
            }
        } else {
            if collection.window.isVisible {
                captureTask?.cancel()
                collection.window.orderOut(nil)
            } else {
                showPanel()
            }
        }
    }

    private func addItem(_ title: String, action: Selector, to menu: NSMenu) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func toggle() {
        if state.isExpanded {
            // Never let a misplaced divider push our only recovery button away.
            guard let divider = dividerItem.button?.window,
                  let toggle = toggleItem.button?.window,
                  divider.screen == toggle.screen,
                  divider.frame.maxX <= toggle.frame.minX + 1 else {
                showHelp()
                let alert = NSAlert()
                alert.messageText = "请先把分隔线放到箭头左侧"
                alert.informativeText = "按住 ⌘，拖动 │ 到 TuckBar 箭头的左边，然后再点击箭头收起。"
                alert.runModal()
                return
            }
        }
        state.toggle()
        refresh()
        scheduleAutoCollapse()
    }

    @objc private func refresh() {
        dividerItem.button?.title = state.isExpanded ? "│" : ""
        dividerItem.length = CGFloat(state.dividerLength(
            screenWidths: NSScreen.screens.map { Double($0.frame.width) }
        ))
        let name = "tray.and.arrow.down"
        let label = "打开隐藏图标收纳面板"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: label)
        image?.isTemplate = true
        toggleItem.button?.image = image
        toggleItem.button?.toolTip = "TuckBar · \(label)（右键查看更多）"
        toggleItem.button?.setAccessibilityLabel("TuckBar · \(label)")
        if CommandLine.arguments.contains("--diagnostics") {
            Timer.scheduledTimer(timeInterval: 0.2, target: self,
                selector: #selector(reportDiagnostics), userInfo: nil, repeats: false)
        }
    }

    // Reports only this app's own layout; no screen capture or other-app inspection.
    @objc private func reportDiagnostics() {
        let toggleFrame = toggleItem.button?.window?.frame ?? .zero
        let dividerFrame = dividerItem.button?.window?.frame ?? .zero
        let screenFrame = toggleItem.button?.window?.screen?.frame ?? .zero
        let values: [String: Any] = [
            "expanded": state.isExpanded,
            "dividerLength": Double(dividerItem.length),
            "dividerFrame": NSStringFromRect(dividerFrame),
            "toggleFrame": NSStringFromRect(toggleFrame),
            "toggleOnScreen": screenFrame.intersects(toggleFrame)
        ]
        if let data = try? JSONSerialization.data(withJSONObject: values, options: [.sortedKeys]),
           let line = String(data: data, encoding: .utf8) {
            FileHandle.standardOutput.write(Data((line + "\n").utf8))
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return true
    }

    @objc private func showPanel() {
        helpWindow?.close()
        collapseTimer?.invalidate()
        captureTask?.cancel()
        panelGeneration += 1
        let generation = panelGeneration
        // Collapse before cataloguing; this keeps the actual icons out of the bar.
        autoCollapse()
        guard let anchor = toggleItem.button?.window,
              let screen = anchor.screen ?? NSScreen.main else { return }
        collection.show(anchor: anchor.frame, screen: screen.frame, toggleWindow: anchor)
        collection.update(entries: [], message: "正在读取隐藏区…")
        captureTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, !Task.isCancelled, self.panelGeneration == generation,
                  let divider = self.dividerItem.button?.window else { return }
            guard !self.state.isExpanded else {
                self.collection.update(entries: [], message: "分隔线位置不正确。点击「整理」，将 │ 拖到 TuckBar 图标左侧后完成整理。")
                return
            }
            let desktopTop = NSScreen.screens.first?.frame.maxY ?? 0
            let cgFrame = CGRect(x: divider.frame.minX, y: desktopTop - divider.frame.maxY,
                width: divider.frame.width, height: divider.frame.height)
            let entries = MenuBarCatalog.entries(dividerFrame: cgFrame, ownPID: ProcessInfo.processInfo.processIdentifier)
            self.collection.update(entries: entries)
            let captured = await MenuBarCatalog.captureImages(for: entries)
            guard !Task.isCancelled, self.panelGeneration == generation else { return }
            self.collection.update(entries: captured)
        }
    }

    private func useEntry(_ entry: MenuBarEntry) {
        guard AXIsProcessTrusted() else {
            collection.showError("请先点击「授权辅助功能」，授权后返回并点击刷新。")
            return
        }
        collection.window.orderOut(nil)
        // Some apps need their original item in its normal slot before AXPress.
        if !state.isExpanded { state.toggle(); refresh() }
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(200))
            guard let self else { return }
            if !MenuBarCatalog.press(entry) {
                self.showPanel()
                self.collection.showError("\(entry.name) 未响应菜单操作。可右键该图标打开 App，或使用右键菜单在原菜单栏展开。")
            } else {
                self.scheduleAutoCollapse()
            }
        }
    }

    @objc private func showHelp() {
        captureTask?.cancel()
        collection.window.orderOut(nil)
        // Setup is always done with the hidden region expanded.
        if !state.isExpanded { state.toggle(); refresh() }
        if helpWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 490, height: 350),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false
            )
            window.title = "TuckBar · 藏栏"
            window.isReleasedWhenClosed = false
            window.delegate = self
            let title = NSTextField(labelWithString: "让菜单栏，清爽一点。")
            title.font = .systemFont(ofSize: 24, weight: .semibold)
            let body = NSTextField(wrappingLabelWithString: "1. 按住 ⌘，把 │ 拖到 TuckBar 箭头的左侧。\n\n2. 按住 ⌘，把想隐藏的 App 图标拖到 │ 左侧；常用图标放在右侧。\n\n3. 完成整理后，点击 TuckBar 图标会在下方打开收纳面板；在面板里点击隐藏图标即可使用。")
            body.font = .systemFont(ofSize: 14)
            let note = NSTextField(wrappingLabelWithString: "操作隐藏图标需要辅助功能权限；显示原始图标画面可选授权屏幕录制。未授权画面时显示 App 图标。系统固定图标和部分 App 图标无法移动。")
            note.font = .systemFont(ofSize: 12)
            note.textColor = .secondaryLabelColor
            let done = NSButton(title: "整理完成，收起图标", target: self, action: #selector(closeHelp))
            done.bezelStyle = .rounded
            done.keyEquivalent = "\r"
            let stack = NSStackView(views: [title, body, note, done])
            stack.orientation = .vertical
            stack.alignment = .leading
            stack.spacing = 20
            stack.translatesAutoresizingMaskIntoConstraints = false
            window.contentView?.addSubview(stack)
            if let content = window.contentView {
                NSLayoutConstraint.activate([
                    stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28),
                    stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28),
                    stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 28),
                    stack.bottomAnchor.constraint(lessThanOrEqualTo: content.bottomAnchor, constant: -24)
                ])
            }
            window.center()
            helpWindow = window
        }
        collapseTimer?.invalidate()
        NSApp.activate(ignoringOtherApps: true)
        helpWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func closeHelp() {
        UserDefaults.standard.set(true, forKey: "hasShownSetup")
        helpWindow?.close()
        autoCollapse()
        showPanel()
    }

    func windowWillClose(_ notification: Notification) { scheduleAutoCollapse() }

    private func scheduleAutoCollapse() {
        collapseTimer?.invalidate()
        guard state.isExpanded, helpWindow?.isVisible != true else { return }
        collapseTimer = Timer.scheduledTimer(timeInterval: 15, target: self,
            selector: #selector(autoCollapse), userInfo: nil, repeats: false)
    }

    @objc private func autoCollapse() {
        guard state.isExpanded, helpWindow?.isVisible != true,
              let divider = dividerItem.button?.window,
              let toggle = toggleItem.button?.window,
              divider.screen == toggle.screen,
              divider.frame.maxX <= toggle.frame.minX + 1 else { return }
        state = VisibilityState(hasCompletedSetup: true)
        refresh()
    }
    @objc private func quit() { NSApp.terminate(nil) }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        dividerItem.length = 20
        NSStatusBar.system.removeStatusItem(dividerItem)
        NSStatusBar.system.removeStatusItem(toggleItem)
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
