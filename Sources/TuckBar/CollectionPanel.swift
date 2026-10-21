import AppKit
import ApplicationServices
import TuckBarCore

@MainActor
private final class PopupPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
    override func cancelOperation(_ sender: Any?) { orderOut(nil) }
}

@MainActor
final class CollectionPanel: NSObject {
    let window: NSPanel
    var onArrange: (() -> Void)?
    var onReload: (() -> Void)?
    var onPress: ((MenuBarEntry) -> Void)?
    private let body = NSStackView()
    private let status = NSTextField(wrappingLabelWithString: "正在读取隐藏区…")
    private var entries: [MenuBarEntry] = []
    private weak var anchorWindow: NSWindow?
    private var localMouseMonitor: Any?
    private var globalMouseMonitor: Any?

    override init() {
        window = PopupPanel(contentRect: NSRect(x: 0, y: 0, width: 480, height: 285),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        super.init()
        window.title = "TuckBar 收纳面板"
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        let effect = NSVisualEffectView()
        effect.material = .popover
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = 16
        effect.layer?.masksToBounds = true
        window.contentView = effect
        body.orientation = .vertical
        body.alignment = .leading
        body.spacing = 14
        body.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(body)
        NSLayoutConstraint.activate([
            body.topAnchor.constraint(equalTo: effect.topAnchor, constant: 18),
            body.leadingAnchor.constraint(equalTo: effect.leadingAnchor, constant: 20),
            body.trailingAnchor.constraint(equalTo: effect.trailingAnchor, constant: -20),
            body.bottomAnchor.constraint(lessThanOrEqualTo: effect.bottomAnchor, constant: -18)
        ])
        render()
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, self.window.isVisible else { return }
                // Let the status button's mouse-up handler toggle the panel itself.
                if event.window !== self.window, event.window !== self.anchorWindow {
                    self.window.orderOut(nil)
                }
            }
            return event
        }
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.window.orderOut(nil) }
        }
    }

    func show(anchor: NSRect, screen: NSRect, toggleWindow: NSWindow) {
        anchorWindow = toggleWindow
        window.setFrame(PanelLayout.frame(anchor: anchor, screen: screen, size: CGSize(width: 480, height: 280)), display: true)
        window.makeKeyAndOrderFront(nil)
    }

    func update(entries: [MenuBarEntry], message: String? = nil) {
        self.entries = entries
        status.stringValue = message ?? (entries.isEmpty ? "隐藏区还没有检测到图标。点击「整理」将图标拖到分隔线左侧。" : "\(entries.count) 个隐藏图标 · 点击使用，右键打开对应 App")
        render()
    }

    func showError(_ message: String) { status.stringValue = message }

    private func render() {
        for child in body.arrangedSubviews { body.removeArrangedSubview(child); child.removeFromSuperview() }
        let title = NSTextField(labelWithString: "藏起来，随时用。")
        title.font = .systemFont(ofSize: 19, weight: .semibold)
        let arrange = button("整理…", action: #selector(arrange))
        let reload = button("刷新", action: #selector(reload))
        let header = NSStackView(views: [title, NSView(), arrange, reload])
        header.orientation = .horizontal
        body.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
        status.font = .systemFont(ofSize: 12)
        status.textColor = .secondaryLabelColor
        body.addArrangedSubview(status)
        status.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true

        if !entries.isEmpty {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 8
            row.edgeInsets = NSEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
            for (index, entry) in entries.enumerated() {
                let item = NSButton(title: entry.name, target: self, action: #selector(pressEntry(_:)))
                item.tag = index
                item.image = entry.image ?? entry.appIcon ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: entry.name)
                item.imagePosition = .imageAbove
                item.imageScaling = .scaleProportionallyDown
                item.bezelStyle = .regularSquare
                item.isBordered = false
                item.font = .systemFont(ofSize: 11)
                item.lineBreakMode = .byTruncatingTail
                item.toolTip = "\(entry.name) · 使用菜单栏图标"
                item.setAccessibilityLabel("使用 \(entry.name) 的菜单栏图标")
                item.widthAnchor.constraint(equalToConstant: 68).isActive = true
                item.heightAnchor.constraint(equalToConstant: 62).isActive = true
                let menu = NSMenu()
                let open = NSMenuItem(title: "打开 \(entry.name)", action: #selector(openApp(_:)), keyEquivalent: "")
                open.target = self
                open.tag = index
                menu.addItem(open)
                item.menu = menu
                row.addArrangedSubview(item)
            }
            let scroll = NSScrollView()
            scroll.hasHorizontalScroller = true
            scroll.drawsBackground = false
            scroll.documentView = row
            row.translatesAutoresizingMaskIntoConstraints = false
            row.heightAnchor.constraint(equalToConstant: 76).isActive = true
            row.widthAnchor.constraint(greaterThanOrEqualToConstant: CGFloat(entries.count) * 76).isActive = true
            body.addArrangedSubview(scroll)
            scroll.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
            scroll.heightAnchor.constraint(equalToConstant: 88).isActive = true
        }
        let accessibility = button(AXIsProcessTrusted() ? "辅助功能已授权 ✓" : "授权辅助功能（操作图标）", action: #selector(requestAccessibility))
        let capture = button(CGPreflightScreenCaptureAccess() ? "图标画面已授权 ✓" : "显示原始图标画面…", action: #selector(requestCapture))
        let permissions = NSStackView(views: [accessibility, capture])
        permissions.orientation = .horizontal
        permissions.spacing = 8
        body.addArrangedSubview(permissions)
        let footnote = NSTextField(wrappingLabelWithString: "未授权画面时显示 App 图标；点击原菜单图标需要辅助功能权限。图标画面只在内存中使用。")
        footnote.font = .systemFont(ofSize: 11)
        footnote.textColor = .secondaryLabelColor
        body.addArrangedSubview(footnote)
        footnote.widthAnchor.constraint(equalTo: body.widthAnchor).isActive = true
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let result = NSButton(title: title, target: self, action: action)
        result.bezelStyle = .rounded
        return result
    }
    @objc private func arrange() { onArrange?() }
    @objc private func reload() { onReload?() }
    @objc private func pressEntry(_ sender: NSButton) {
        guard entries.indices.contains(sender.tag) else { return }
        onPress?(entries[sender.tag])
    }
    @objc private func openApp(_ sender: NSMenuItem) {
        guard entries.indices.contains(sender.tag),
              let app = NSRunningApplication(processIdentifier: entries[sender.tag].pid),
              let url = app.bundleURL else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
    @objc private func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    @objc private func requestCapture() {
        _ = CGRequestScreenCaptureAccess()
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }
}
