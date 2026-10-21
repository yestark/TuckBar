import Foundation
import CoreGraphics

public enum PanelLayout {
    public static func frame(anchor: CGRect, screen: CGRect, size: CGSize) -> CGRect {
        let width = min(size.width, max(1, screen.width - 24))
        let height = min(size.height, max(1, screen.height - 48))
        let x = min(max(anchor.midX - width / 2, screen.minX + 12), screen.maxX - width - 12)
        let y = max(screen.minY + 12, anchor.minY - height - 8)
        return CGRect(x: x, y: y, width: width, height: height)
    }
}
