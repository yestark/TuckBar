import Foundation
import CoreGraphics
import Testing
@testable import TuckBarCore

struct PanelLayoutTests {
    @Test func panelStaysInsideRightEdge() {
        let frame = PanelLayout.frame(anchor: CGRect(x: 1400, y: 960, width: 30, height: 24),
            screen: CGRect(x: 0, y: 0, width: 1440, height: 984), size: CGSize(width: 360, height: 200))
        #expect(frame.maxX <= 1428)
        #expect(frame.maxY == 952)
    }
    @Test func panelStaysInsideLeftEdgeOnSecondaryDisplay() {
        let frame = PanelLayout.frame(anchor: CGRect(x: -1440, y: 960, width: 30, height: 24),
            screen: CGRect(x: -1440, y: 0, width: 1440, height: 984), size: CGSize(width: 360, height: 200))
        #expect(frame.minX == -1428)
    }
    @Test func narrowDisplayConstrainsPanelWidth() {
        let frame = PanelLayout.frame(anchor: CGRect(x: 200, y: 360, width: 30, height: 24),
            screen: CGRect(x: 0, y: 0, width: 320, height: 384), size: CGSize(width: 600, height: 200))
        #expect(frame.width == 296)
        #expect(frame.minX == 12)
    }
}
