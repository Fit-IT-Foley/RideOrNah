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

    /// The Info.plists of the app and the three bundles embedded in it, by bundle ID suffix.
    static func bundles() throws -> [String: [String: Any]] {
        let app = Bundle.main.bundleURL
        let watch = app.appending(path: "Watch/RideOrNahWatch.app")
        let urls = [
            "": app,
            ".Widgets": app.appending(path: "PlugIns/RideOrNahWidgets.appex"),
            ".watchkitapp": watch,
            ".watchkitapp.Widgets": watch.appending(path: "PlugIns/RideOrNahWatchWidgets.appex"),
        ]
        return try urls.mapValues { url in
            let data = try Data(contentsOf: url.appending(path: "Info.plist"))
            return try #require(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        }
    }

    // Scenario: app-release: Bundle identifiers
    @Test("Bundle identifiers")
    func bundlesUseTheRealIdentity() throws {
        for (suffix, info) in try Self.bundles() {
            #expect(info["CFBundleIdentifier"] as? String == "com.rideornah.RideOrNah\(suffix)")
            #expect(info["RideOrNahAppGroup"] as? String == "group.com.rideornah.RideOrNah")
        }
        let watch = try #require(Self.bundles()[".watchkitapp"])
        #expect(watch["WKCompanionAppBundleIdentifier"] as? String == "com.rideornah.RideOrNah")
    }

    // Scenario: app-release: Home Screen name
    @Test("Home Screen name")
    func homeScreenLabel() {
        #expect(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String == "Ride or Nah")
    }

    // App Store Connect rejects an upload whose extensions' versions differ from the app's.
    // Scenario: app-release: Matching versions
    @Test("Matching versions")
    func bundlesShareVersionAndBuild() throws {
        let bundles = try Self.bundles()
        let build = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)
        #expect(bundles.count == 4)
        for info in bundles.values {
            #expect(info["CFBundleShortVersionString"] as? String == "1.0")
            #expect(info["CFBundleVersion"] as? String == build)
        }
    }

    // Scenario: app-release: Encryption declaration
    @Test("Encryption declaration")
    func bundlesDeclareNoNonExemptEncryption() throws {
        for info in try Self.bundles().values {
            #expect(info["ITSAppUsesNonExemptEncryption"] as? Bool == false)
        }
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
