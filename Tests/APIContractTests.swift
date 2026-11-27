import XCTest
@testable import vibecodeGram

final class APIContractTests: XCTestCase {
    func testAuthenticationResponseUsesBackendSnakeCaseFields() throws {
        let data = Data(#"{"token":"test-token","user":{"id":42,"username":"ferz","display_name":"Ferz"}}"#.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let response = try decoder.decode(AuthResponse.self, from: data)

        XCTAssertEqual(response.token, "test-token")
        XCTAssertEqual(response.user.id, 42)
        XCTAssertEqual(response.user.username, "ferz")
        XCTAssertEqual(response.user.displayName, "Ferz")
    }

    func testFeedPostDecodesBackendFields() throws {
        let data = Data(#"{"id":7,"author_id":42,"username":"ferz","display_name":"Ferz","body":"Hello","tag":"ios","created_at":"2026-11-27T10:00:00Z","likes":3,"liked":true,"saved":false,"video_url":"","media_type":"","media_size":0,"content_kind":"post"}"#.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let post = try decoder.decode(APIPost.self, from: data)

        XCTAssertEqual(post.id, 7)
        XCTAssertEqual(post.authorId, 42)
        XCTAssertEqual(post.body, "Hello")
        XCTAssertEqual(post.likes, 3)
        XCTAssertTrue(post.liked)
        XCTAssertEqual(post.contentKind, "post")
    }

    func testAPIErrorUnauthorizedClassification() {
        XCTAssertTrue(APIError.httpStatus(401, "expired").isUnauthorized)
        XCTAssertFalse(APIError.httpStatus(500, "server").isUnauthorized)
    }
}
