import AppKit
import ApplicationServices
import ScreenCaptureKit

@MainActor
struct MenuBarEntry {
    let windowID: CGWindowID
    let pid: pid_t
    let name: String
    let frame: CGRect
    let appIcon: NSImage?
    var image: NSImage?
}

@MainActor
enum MenuBarCatalog {
    /// Enumerates only small menu-extra windows to the left of our own divider.
    static func entries(dividerFrame: CGRect, ownPID: pid_t) -> [MenuBarEntry] {
        guard let windows = CGWindowListCopyWindowInfo(.optionAll, kCGNullWindowID) as? [[String: Any]] else { return [] }
        return windows.compactMap { window in
            guard let layer = window[kCGWindowLayer as String] as? Int, layer == 25,
                  let pid = window[kCGWindowOwnerPID as String] as? Int32, pid != ownPID,
                  let number = window[kCGWindowNumber as String] as? UInt32,
                  let rawBounds = window[kCGWindowBounds as String] as? NSDictionary,
                  let frame = CGRect(dictionaryRepresentation: rawBounds),
                  frame.width > 1, frame.width < 180, frame.height > 8, frame.height < 60,
                  abs(frame.midY - dividerFrame.midY) < 12,
                  frame.maxX <= dividerFrame.minX + 1 else { return nil }
            let app = NSRunningApplication(processIdentifier: pid)
            let name = app?.localizedName ?? (window[kCGWindowOwnerName as String] as? String) ?? "菜单栏图标"
            return MenuBarEntry(windowID: number, pid: pid, name: name, frame: frame, appIcon: app?.icon)
        }.sorted { $0.frame.minX < $1.frame.minX }
    }

    static func captureImages(for entries: [MenuBarEntry]) async -> [MenuBarEntry] {
        guard #available(macOS 14.0, *), CGPreflightScreenCaptureAccess(), !entries.isEmpty else { return entries }
        guard let content = try? await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false) else { return entries }
        var result = entries
        for index in result.indices {
            guard !Task.isCancelled else { break }
            guard let window = content.windows.first(where: { $0.windowID == result[index].windowID }) else { continue }
            let configuration = SCStreamConfiguration()
            configuration.width = max(2, Int(window.frame.width * 2))
            configuration.height = max(2, Int(window.frame.height * 2))
            configuration.showsCursor = false
            configuration.ignoreShadowsSingleWindow = true
            if let image = try? await SCScreenshotManager.captureImage(
                contentFilter: SCContentFilter(desktopIndependentWindow: window), configuration: configuration
            ) {
                result[index].image = NSImage(cgImage: image, size: window.frame.size)
            }
        }
        return result
    }

    /// Uses Accessibility's press action rather than synthesizing mouse clicks.
    static func press(_ entry: MenuBarEntry) -> Bool {
        guard AXIsProcessTrusted() else { return false }
        let app = AXUIElementCreateApplication(entry.pid)
        AXUIElementSetMessagingTimeout(app, 1)
        var menu: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, "AXExtrasMenuBar" as CFString, &menu) == .success,
              let menu else { return false }
        var rawChildren: CFTypeRef?
        let menuElement = menu as! AXUIElement
        guard AXUIElementCopyAttributeValue(menuElement, kAXChildrenAttribute as CFString, &rawChildren) == .success,
              let children = rawChildren as? [AXUIElement], !children.isEmpty else { return false }
        let currentFrame = windowFrame(id: entry.windowID) ?? entry.frame
        let candidates = children.compactMap { child -> (AXUIElement, CGFloat)? in
            guard let frame = frame(of: child) else { return nil }
            return (child, abs(frame.midX - currentFrame.midX) + abs(frame.midY - currentFrame.midY))
        }.sorted { $0.1 < $1.1 }
        // Do not press an unrelated item when an app owns multiple menu extras.
        guard let target = candidates.first, target.1 < 30 else { return false }
        return AXUIElementPerformAction(target.0, kAXPressAction as CFString) == .success
    }

    private static func windowFrame(id: CGWindowID) -> CGRect? {
        guard let windows = CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]],
              let raw = windows.first?[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: raw)
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &size) == .success,
              let position, let size,
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(position as! AXValue, .cgPoint, &point),
              AXValueGetValue(size as! AXValue, .cgSize, &dimensions) else { return nil }
        return CGRect(origin: point, size: dimensions)
    }
}
