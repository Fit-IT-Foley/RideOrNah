import Foundation
import Testing

/// Checks on the built app bundle. These tests are hosted in the app, so `Bundle.main` is it.
struct AppBundleTests {
    // The App Store reads the minimum OS from the bundle to tell older devices the app needs
    // a newer iOS.
    // Scenario: app-platform: Unsupported OS
    @Test("Unsupported OS")
    func declaresIOS26Minimum() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "MinimumOSVersion") as? String == "26.0")
    }

    // Debug and Release builds bundle the same manifest file.
    // Scenario: app-platform: Manifest present in build
    @Test("Manifest present in build")
    func privacyManifestDeclaresNoTrackingOrCollection() throws {
        let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let plist = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil)
        let manifest = try #require(plist as? [String: Any])

        #expect(manifest["NSPrivacyTracking"] as? Bool == false)
        #expect((manifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
        #expect((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
    }
}
