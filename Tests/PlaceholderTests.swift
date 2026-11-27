import XCTest
@testable import vibecodeGram

final class PlaceholderTests: XCTestCase {
    func testAPIErrorUnauthorizedClassification() {
        XCTAssertTrue(APIError.httpStatus(401, "expired").isUnauthorized)
        XCTAssertFalse(APIError.httpStatus(500, "server").isUnauthorized)
    }
}
