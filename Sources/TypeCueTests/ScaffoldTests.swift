import Testing

@Suite("Scaffold")
struct ScaffoldTests {
    @Test("Toolchain and test target are wired up")
    func toolchainIsWiredUp() {
        #expect(Bool(true))
    }
}
