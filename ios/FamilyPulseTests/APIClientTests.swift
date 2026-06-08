import XCTest

final class APIClientTests: XCTestCase {
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    func testDecodesServerUser() throws {
        let json = """
        {
            "id": "11111111-1111-4111-8111-111111111111",
            "externalId": "password:alice",
            "username": "alice",
            "displayName": "Alice",
            "avatarSymbol": "person.crop.circle.fill",
            "avatarColor": "green",
            "subscriptionTier": "FREE",
            "hasPassword": false,
            "hasWeChatBinding": false,
            "isGuest": true
        }
        """.data(using: .utf8)!
        let user = try JSONDecoder().decode(ServerUser.self, from: json)
        XCTAssertEqual(user.displayName, "Alice")
        XCTAssertEqual(user.username, "alice")
        XCTAssertEqual(user.subscriptionTier, "FREE")
        XCTAssertEqual(user.hasPassword, false)
        XCTAssertEqual(user.hasWeChatBinding, false)
        XCTAssertEqual(user.isGuest, true)
    }

    func testDecodesServerUserWithNilUsername() throws {
        let json = """
        {
            "id": "22222222-2222-4222-8222-222222222222",
            "externalId": "apple:subject123",
            "displayName": "Apple 用户",
            "avatarSymbol": "heart.circle.fill",
            "avatarColor": "blue"
        }
        """.data(using: .utf8)!
        let user = try JSONDecoder().decode(ServerUser.self, from: json)
        XCTAssertNil(user.username)
        XCTAssertEqual(user.displayName, "Apple 用户")
    }

    func testDecodesAuthResponse() throws {
        let json = """
        {
            "user": {
                "id": "11111111-1111-4111-8111-111111111111",
                "externalId": "password:alice",
                "username": "alice",
                "displayName": "Alice",
                "avatarSymbol": "person.crop.circle.fill",
                "avatarColor": "green",
                "subscriptionTier": "FREE"
            },
            "token": "test-token-value",
            "expiresAt": "2026-06-30T00:00:00Z"
        }
        """.data(using: .utf8)!
        let auth = try decoder.decode(ServerAuthResponse.self, from: json)
        XCTAssertEqual(auth.token, "test-token-value")
        XCTAssertEqual(auth.user.displayName, "Alice")
    }

    func testDecodesOverviewNullCollectionsAsEmptyArrays() throws {
        let json = """
        {
            "family": {
                "id": "99999999-9999-4999-8999-999999999999",
                "name": "空家庭",
                "inviteCode": "EMPTY26",
                "role": "ADMIN"
            },
            "members": null,
            "elders": null,
            "recentRecords": null,
            "upcomingAppointments": null,
            "feed": null
        }
        """.data(using: .utf8)!
        let overview = try decoder.decode(ServerOverview.self, from: json)
        XCTAssertTrue(overview.members.isEmpty)
        XCTAssertTrue(overview.elders.isEmpty)
        XCTAssertTrue(overview.recentRecords.isEmpty)
        XCTAssertTrue(overview.upcomingAppointments.isEmpty)
        XCTAssertTrue(overview.feed.isEmpty)
    }

    func testDecodesSubscriptionStatus() throws {
        let json = """
        {
            "tier": "MONTHLY",
            "expiresAt": "2027-05-30T00:00:00Z",
            "canUploadAttachments": false,
            "canCreateMultipleFamilies": true,
            "canQueueOfflineActions": true,
            "syncDelaySeconds": 30,
            "maxCustomActionsPerElder": 3,
            "historyRetentionDays": 7,
            "historyDailyLimit": 10,
            "activationCode": "FP-ABCD-2345",
            "activationDeviceLimit": 2,
            "activationUsedCount": 1
        }
        """.data(using: .utf8)!
        let status = try decoder.decode(FamilyPulseServerClient.SubscriptionStatus.self, from: json)
        XCTAssertEqual(status.tier, "MONTHLY")
        XCTAssertFalse(status.canUploadAttachments)
        XCTAssertTrue(status.canCreateMultipleFamilies)
        XCTAssertTrue(status.canQueueOfflineActions)
        XCTAssertEqual(status.syncDelaySeconds, 30)
        XCTAssertEqual(status.historyRetentionDays, 7)
        XCTAssertEqual(status.activationCode, "FP-ABCD-2345")
        XCTAssertEqual(status.activationDeviceLimit, 2)
        XCTAssertEqual(status.activationUsedCount, 1)
    }
}
