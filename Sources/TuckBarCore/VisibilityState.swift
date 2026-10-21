/// Geometry for a collapsible menu bar region. First launch stays expanded for setup; later launches start collapsed.
public struct VisibilityState {
    public private(set) var isExpanded = true
    public init(hasCompletedSetup: Bool = false) {
        isExpanded = !hasCompletedSetup
    }
    public mutating func toggle() { isExpanded.toggle() }

    public func dividerLength(screenWidths: [Double]) -> Double {
        guard !isExpanded else { return 20 }
        return max(500, min((screenWidths.max() ?? 0) * 2, 10_000))
    }
}
