import Testing
@testable import ONNXRuntime

@Test func buildFlavorIsCpu() async throws {
    #expect(ONNXRuntime.buildFlavor == "cpu")
}
