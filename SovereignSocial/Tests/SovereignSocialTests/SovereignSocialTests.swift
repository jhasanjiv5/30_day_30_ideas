import XCTest
@testable import SovereignSocial

final class SovereignSocialTests: XCTestCase {
    func testPrivacyScannerFlagsPhoneNumbers() {
        let leakText = "Call me at 415-555-0199 for orders"
        let result = PrivacyScanner.scan(text: leakText)
        XCTAssertFalse(result.isSafe)
        XCTAssertEqual(result.flags.count, 1)
    }

    func testPrivacyScannerCleanPost() {
        let safeText = "Fresh sourdough loaves cooling on the rack. Order via link in bio!"
        let result = PrivacyScanner.scan(text: safeText)
        XCTAssertTrue(result.isSafe)
        XCTAssertEqual(result.score, 100)
    }
}
