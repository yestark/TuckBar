import Testing
@testable import TuckBarCore

struct VisibilityStateTests {
    @Test func toggleRevealsAndHidesIcons() {
        var state = VisibilityState()
        #expect(state.isExpanded)
        state.toggle()
        #expect(!state.isExpanded)
        #expect(state.dividerLength(screenWidths: [1512]) == 3024)
        state.toggle()
        #expect(state.isExpanded)
        #expect(state.dividerLength(screenWidths: [1512]) == 20)
    }

    @Test func hidingCoversWidestConnectedDisplay() {
        var state = VisibilityState()
        state.toggle()
        #expect(state.dividerLength(screenWidths: [1512, 2560]) == 5120)
        #expect(state.dividerLength(screenWidths: [1512]) == 3024)
    }

    @Test func hidingBoundsWidthForMissingAndVeryLargeScreens() {
        var state = VisibilityState()
        state.toggle()
        #expect(state.dividerLength(screenWidths: []) == 500)
        #expect(state.dividerLength(screenWidths: [8000]) == 10000)
    }
}
