import AppKit
import TuckBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var state = VisibilityState()
    private var toggleItem: NSStatusItem!
    private var dividerItem: NSStatusItem!
    private var helpWindow: NSWindow?

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
        refresh()
        if !UserDefaults.standard.bool(forKey: "hasShownSetup") {
            showHelp()
            UserDefaults.standard.set(true, forKey: "hasShownSetup")
        }
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            let menu = NSMenu()
            addItem(state.isExpanded ? "收起隐藏区" : "展开隐藏区", action: #selector(toggle), to: menu)
            addItem("整理图标与使用说明…", action: #selector(showHelp), to: menu)
            menu.addItem(.separator())
            addItem("退出 TuckBar", action: #selector(quit), to: menu)
            if let button = toggleItem.button {
                menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
            }
        } else {
            toggle()
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
    }

    @objc private func refresh() {
        dividerItem.length = CGFloat(state.dividerLength(
            screenWidths: NSScreen.screens.map { Double($0.frame.width) }
        ))
        let name = state.isExpanded ? "chevron.left" : "chevron.right"
        let label = state.isExpanded ? "收起隐藏区" : "展开隐藏区"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: label)
        image?.isTemplate = true
        toggleItem.button?.image = image
        toggleItem.button?.toolTip = "TuckBar · \(label)（右键查看更多）"
        toggleItem.button?.setAccessibilityLabel("TuckBar · \(label)")
    }

    @objc private func showHelp() {
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
            let title = NSTextField(labelWithString: "让菜单栏，清爽一点。")
            title.font = .systemFont(ofSize: 24, weight: .semibold)
            let body = NSTextField(wrappingLabelWithString: "1. 按住 ⌘，把 │ 拖到 TuckBar 箭头的左侧。\n\n2. 按住 ⌘，把想隐藏的 App 图标拖到 │ 左侧；常用图标放在右侧。\n\n3. 点击箭头，一键收起或展开；右键箭头打开菜单。")
            body.font = .systemFont(ofSize: 14)
            let note = NSTextField(wrappingLabelWithString: "刘海屏提示：展开仍受菜单栏实际空间限制，图标过多时可能显示不全。系统固定图标和部分 App 图标无法移动。退出 TuckBar 会恢复显示。")
            note.font = .systemFont(ofSize: 12)
            note.textColor = .secondaryLabelColor
            let done = NSButton(title: "开始整理", target: self, action: #selector(closeHelp))
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
        NSApp.activate(ignoringOtherApps: true)
        helpWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func closeHelp() { helpWindow?.close() }
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
