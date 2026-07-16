import Foundation
import Testing
import TypeCue

@Suite("TextBlock legacy migration")
struct TextBlockTests {
    private func decode(_ json: String) throws -> TextBlock {
        try JSONDecoder().decode(TextBlock.self, from: Data(json.utf8))
    }

    @Test("legacy speedOverride becomes speed markers around the text")
    func migratesSpeedOverride() throws {
        let block = try decode(#"{"id":"\#(UUID().uuidString)","text":"hello","speedOverride":0.02}"#)
        #expect(block.text == "[speed:20]hello[speed:default]")
    }

    @Test("legacy delayBefore becomes a leading pause marker")
    func migratesDelayBefore() throws {
        let block = try decode(#"{"id":"\#(UUID().uuidString)","text":"hello","delayBefore":1.0}"#)
        #expect(block.text == "[1]hello")
    }

    @Test("both overrides combine: pause then speed wrap")
    func migratesBoth() throws {
        let block = try decode(#"{"id":"\#(UUID().uuidString)","text":"hi","delayBefore":0.5,"speedOverride":0.05}"#)
        #expect(block.text == "[0.5][speed:50]hi[speed:default]")
    }

    @Test("text without legacy fields is unchanged")
    func noMigrationNeeded() throws {
        let block = try decode(#"{"id":"\#(UUID().uuidString)","text":"plain"}"#)
        #expect(block.text == "plain")
    }

    @Test("re-encoding drops legacy keys and keeps only id and text")
    func encodeIsClean() throws {
        let original = try decode(#"{"id":"\#(UUID().uuidString)","text":"x","speedOverride":0.02}"#)
        let data = try JSONEncoder().encode(original)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(object?["speedOverride"] == nil)
        #expect(object?["delayBefore"] == nil)
        #expect(object?["text"] as? String == "[speed:20]x[speed:default]")
    }
}
