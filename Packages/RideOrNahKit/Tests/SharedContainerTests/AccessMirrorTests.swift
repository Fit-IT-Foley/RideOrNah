import Foundation
import SharedContainer
import Testing

struct AccessMirrorTests {
    @Test("Access mirror round-trips")
    func roundTrips() throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "Mirror-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let container = SharedContainer.resolve(groupIdentifier: "group.test") { _ in url }
        #expect(container.readAccessMirror() == nil)
        let mirror = AccessMirror(isActive: true, checkedAt: Date(timeIntervalSince1970: 1_780_000_000))
        container.writeAccessMirror(mirror)
        #expect(container.readAccessMirror() == mirror)
    }
}
