import XCTest

final class FamilyPulseTestsLaunchTests: XCTestCase {

    func testAppConfigurationUsesLocalBackendInDebugBuilds() {
        #if DEBUG
        XCTAssertEqual(AppConfiguration.apiBaseURL.absoluteString, "http://127.0.0.1:8081")
        #else
        XCTAssertEqual(AppConfiguration.apiBaseURL.absoluteString, "https://jiaan.online")
        #endif
    }
}
