/// Geometry for a collapsible menu bar region. Launch expanded so setup is safe.
public struct VisibilityState {
    public private(set) var isExpanded = true
    public init() {}
    public mutating func toggle() { isExpanded.toggle() }

    public func dividerLength(screenWidths: [Double]) -> Double {
        guard !isExpanded else { return 20 }
        return max(500, min((screenWidths.max() ?? 0) * 2, 10_000))
    }
}
