import Foundation
import Testing
@testable import SharedContainer

struct SharedContainerTests {
    @Test func usesAppGroupWhenAvailable() {
        let groupURL = URL(filePath: "/tmp/group.com.example.rideornah", directoryHint: .isDirectory)
        let container = SharedContainer.resolve(groupIdentifier: "group.com.example.rideornah") { _ in groupURL }

        #expect(container.kind == .appGroup)
        #expect(container.url == groupURL)
    }

    @Test func fallsBackWhenGroupIsUnavailable() throws {
        let container = SharedContainer.resolve(groupIdentifier: "group.com.example.rideornah") { _ in nil }

        #expect(container.kind == .temporary)
        #expect(container.url.lastPathComponent == "RideOrNah-\(ProcessInfo.processInfo.processIdentifier)")
        #expect(FileManager.default.fileExists(atPath: container.url.path()))
    }

    @Test(arguments: [nil, ""])
    func fallsBackWithoutGroupIdentifier(identifier: String?) {
        var lookedUp = false
        let container = SharedContainer.resolve(groupIdentifier: identifier) { _ in
            lookedUp = true
            return nil
        }

        #expect(container.kind == .temporary)
        #expect(!lookedUp)
    }

    @Test func fallbackDirectoryIsWritable() throws {
        let container = SharedContainer.resolve(groupIdentifier: nil)
        let file = container.url.appending(path: "probe.txt")
        try Data("ok".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(try String(contentsOf: file, encoding: .utf8) == "ok")
    }
}
