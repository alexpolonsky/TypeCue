import Foundation
import Testing
@testable import TypeCue

@MainActor
@Suite("SessionController")
struct SessionControllerTests {
    private func makeController(scripts: [Script]) -> SessionController {
        SessionController { id in
            scripts.first(where: { $0.id == id })?.blocks
        }
    }

    private func makeScript(blockCount: Int) -> Script {
        let blocks = (0..<blockCount).map { TextBlock(text: "block-\($0)") }
        return Script(name: "test", blocks: blocks)
    }

    @Test("Initial state is idle with no active script")
    func initialIdle() {
        let controller = makeController(scripts: [])
        #expect(controller.activeScriptID == nil)
        #expect(controller.cursor == 0)
        #expect(controller.state == .idle)
    }

    @Test("setActiveScript arms at index 0")
    func armsAtZero() {
        let script = makeScript(blockCount: 3)
        let controller = makeController(scripts: [script])
        controller.setActiveScript(script.id)
        #expect(controller.activeScriptID == script.id)
        #expect(controller.cursor == 0)
        #expect(controller.state == .armed(nextIndex: 0, total: 3))
    }

    @Test("advance returns blocks in order and completes with STOP")
    func advanceInOrderThenStop() {
        let script = makeScript(blockCount: 3)
        let controller = makeController(scripts: [script])
        controller.setActiveScript(script.id)

        let first = controller.advance()
        #expect(first?.text == "block-0")
        #expect(controller.state == .armed(nextIndex: 1, total: 3))

        let second = controller.advance()
        #expect(second?.text == "block-1")
        #expect(controller.state == .armed(nextIndex: 2, total: 3))

        let third = controller.advance()
        #expect(third?.text == "block-2")
        #expect(controller.state == .complete(total: 3))

        // STOP: further presses return nil and stay complete (no looping).
        #expect(controller.advance() == nil)
        #expect(controller.advance() == nil)
        #expect(controller.state == .complete(total: 3))
    }

    @Test("reset re-arms at index 0")
    func resetReArms() {
        let script = makeScript(blockCount: 2)
        let controller = makeController(scripts: [script])
        controller.setActiveScript(script.id)
        _ = controller.advance()
        _ = controller.advance()
        #expect(controller.state == .complete(total: 2))

        controller.reset()
        #expect(controller.cursor == 0)
        #expect(controller.state == .armed(nextIndex: 0, total: 2))
        #expect(controller.advance()?.text == "block-0")
    }

    @Test("rewind re-arms the interrupted block (rewind on cancel)")
    func rewindReArmsInterruptedBlock() {
        let script = makeScript(blockCount: 3)
        let controller = makeController(scripts: [script])
        controller.setActiveScript(script.id)

        let first = controller.advance()
        #expect(first?.text == "block-0")
        #expect(controller.cursor == 1)

        // User pressed the shortcut again mid-block-0: rewind to the typed index.
        controller.rewind(to: 0)
        #expect(controller.cursor == 0)
        #expect(controller.state == .armed(nextIndex: 0, total: 3))
        // The same block re-arms and is typed again on the next press (not skipped).
        #expect(controller.advance()?.text == "block-0")
    }

    @Test("rewind clamps out-of-range indices without desyncing state")
    func rewindClampsBounds() {
        let script = makeScript(blockCount: 2)
        let controller = makeController(scripts: [script])
        controller.setActiveScript(script.id)

        controller.rewind(to: -5)
        #expect(controller.cursor == 0)
        #expect(controller.state == .armed(nextIndex: 0, total: 2))

        controller.rewind(to: 99)
        #expect(controller.cursor == 2)
        #expect(controller.state == .complete(total: 2))
    }

    @Test("Switching active script resets the cursor")
    func switchingResetsCursor() {
        let a = makeScript(blockCount: 3)
        let b = makeScript(blockCount: 2)
        let controller = makeController(scripts: [a, b])
        controller.setActiveScript(a.id)
        _ = controller.advance()
        _ = controller.advance()
        #expect(controller.cursor == 2)

        controller.setActiveScript(b.id)
        #expect(controller.cursor == 0)
        #expect(controller.state == .armed(nextIndex: 0, total: 2))
    }

    @Test("Clearing active script returns to idle")
    func clearingReturnsIdle() {
        let script = makeScript(blockCount: 1)
        let controller = makeController(scripts: [script])
        controller.setActiveScript(script.id)
        controller.setActiveScript(nil)
        #expect(controller.activeScriptID == nil)
        #expect(controller.state == .idle)
        #expect(controller.advance() == nil)
    }

    @Test("Empty script is complete(total: 0) and advance returns nil")
    func emptyScriptIsComplete() {
        let empty = makeScript(blockCount: 0)
        let controller = makeController(scripts: [empty])
        controller.setActiveScript(empty.id)
        #expect(controller.state == .complete(total: 0))
        #expect(controller.advance() == nil)
        #expect(controller.state == .complete(total: 0))
    }
}
