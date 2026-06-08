import XCTest

final class APIClientNetworkTests: XCTestCase {
    private var session: StubHTTPSession!

    override func setUp() {
        super.setUp()
        session = StubHTTPSession(handler: Self.response(for:))
    }

    override func tearDown() {
        session = nil
        super.tearDown()
    }

    func testAuthenticationEndpointsUseExpectedRequestsAndDecodeResponses() async throws {
        let client = makeClient()

        let guest = try await client.guestLogin()
        let registered = try await client.register(username: "alice", password: "secret", displayName: "Alice")
        let loggedIn = try await client.login(username: "alice", password: "secret")
        let apple = try await client.loginWithApple(identityToken: "apple-token", displayName: "Alice")
        let wechat = try await client.loginWithWeChat(code: "wx_mock_family", openId: nil, unionId: nil, nickname: nil)

        XCTAssertEqual([guest, registered, loggedIn, apple, wechat].map(\.token), ["token", "token", "token", "token", "token"])
        XCTAssertEqual(session.seenRequests.map { $0.url?.path }, ["/api/auth/guest", "/api/auth/register", "/api/auth/login", "/api/auth/apple", "/api/auth/wechat"])
        XCTAssertTrue(session.seenRequests.allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == nil })
        XCTAssertBody(of: session.seenRequests[1], contains: "\"displayName\":\"Alice\"")
        XCTAssertBody(of: session.seenRequests[3], contains: "\"identityToken\":\"apple-token\"")
        XCTAssertBody(of: session.seenRequests[4], contains: "\"code\":\"wx_mock_family\"")
    }

    func testFamilyOverviewActionsAppointmentsHistoryAndSubscriptionEndpoints() async throws {
        let familyId = UUID(uuidString: "99999999-9999-4999-8999-999999999999")!
        let elderId = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let appointmentId = UUID(uuidString: "66666666-6666-4666-8666-666666666666")!
        let eventId = UUID(uuidString: "77777777-7777-4777-8777-777777777777")!
        var client = makeClient()
        client.authToken = "auth-token"

        let health = try await client.health()
        let families = try await client.listFamilies()
        let createdFamily = try await client.createFamily(name: "爸妈健康同步")
        let joinedFamily = try await client.joinFamily(inviteCode: "FAMILY26")
        let createdElder = try await client.createElder(familyId: familyId, name: "妈妈", birthYear: 1958, notes: "高血压")
        let overview = try await client.overview(familyId: familyId)
        let actionHistory = try await client.actionHistory(familyId: familyId, date: Date(timeIntervalSince1970: 0), limit: 3)
        let yearlyStatus = try await client.getSubscriptionStatus()
        let monthlyPurchase = try await client.purchasePremium(tier: "MONTHLY")
        let yearlyReceipt = try await client.verifyReceipt(transactionJws: "jws")
        let codeActivation = try await client.activateSubscriptionCode(code: "FP-ABCD-2345", deviceId: "ios-device")
        let createdEvent = try await client.createCareEvent(familyId: familyId, elderId: elderId, actionKey: "morning_meds")
        let undoneEvent = try await client.undoCareEvent(familyId: familyId, elderId: elderId, eventId: eventId)
        let createdAppointment = try await client.createAppointment(familyId: familyId, elderId: elderId, title: "复查", scheduledAt: Date(timeIntervalSince1970: 0), hospital: "市医院", department: "内分泌", assignedToUserId: nil, checklist: ["化验单"], note: "空腹")
        let doneAppointment = try await client.markAppointmentDone(familyId: familyId, appointmentId: appointmentId, resultNote: "完成")
        let updatedUser = try await client.updateAvatar(symbol: "heart.circle.fill", color: "orange")
        let passwordUser = try await client.setPassword(currentPassword: nil, newPassword: "Password123!")
        let wechatUser = try await client.bindWeChat(code: "wx_mock_family", openId: nil, unionId: nil, nickname: nil)
        let customActions = try await client.listCustomActions(familyId: familyId)
        let createdCustomAction = try await client.createCustomAction(familyId: familyId, elderId: elderId, actionKey: "walk", title: "散步", icon: "figure.walk")
        try await client.deleteCustomAction(familyId: familyId, elderId: elderId, actionKey: "walk")
        try await client.leaveFamily(familyId: familyId)

        XCTAssertEqual(health, "UP")
        XCTAssertEqual(families.first?.inviteCode, "FAMILY26")
        XCTAssertEqual(createdFamily.name, "爸妈健康同步")
        XCTAssertEqual(joinedFamily.role, "ADMIN")
        XCTAssertEqual(createdElder.name, "妈妈")
        XCTAssertEqual(overview.family.id, familyId)
        XCTAssertTrue(overview.recentRecords.isEmpty)
        XCTAssertEqual(actionHistory.first?.type, "CARE_ACTION")
        XCTAssertEqual(yearlyStatus.tier, "YEARLY")
        XCTAssertFalse(yearlyStatus.canUploadAttachments)
        XCTAssertEqual(yearlyStatus.historyRetentionDays, -1)
        XCTAssertEqual(yearlyStatus.historyDailyLimit, 10)
        XCTAssertEqual(monthlyPurchase.syncDelaySeconds, 30)
        XCTAssertEqual(monthlyPurchase.historyRetentionDays, 7)
        XCTAssertEqual(yearlyReceipt.maxCustomActionsPerElder, 20)
        XCTAssertEqual(yearlyReceipt.activationDeviceLimit, 4)
        XCTAssertNil(codeActivation.activationCode)
        XCTAssertEqual(createdEvent.eventIdString, eventId.uuidString)
        XCTAssertEqual(undoneEvent.status, "DONE")
        XCTAssertEqual(createdAppointment.id, appointmentId)
        XCTAssertEqual(doneAppointment.status, "DONE")
        XCTAssertEqual(updatedUser.avatarColor, "orange")
        XCTAssertEqual(passwordUser.hasPassword, true)
        XCTAssertEqual(wechatUser.hasWeChatBinding, true)
        XCTAssertEqual(customActions.first?.actionKey, "walk")
        XCTAssertEqual(createdCustomAction.title, "散步")
        XCTAssertTrue(session.seenRequests.dropFirst().allSatisfy { $0.value(forHTTPHeaderField: "Authorization") == "Bearer auth-token" })
        XCTAssertTrue(session.seenRequests.contains { $0.httpMethod == "PATCH" && $0.url?.path == "/api/users/avatar" })
        XCTAssertFalse(session.seenRequests.contains { $0.url?.path.contains("/records") == true })
        XCTAssertFalse(session.seenRequests.contains { $0.url?.path.contains("/attachments") == true })
    }

    func testServerErrorsUseBackendMessageOrStatusFallback() async {
        var client = makeClient()
        client.authToken = "auth-token"

        session.handler = { request in
            if request.url?.path == "/api/health" {
                return (409, Data(#"{"status":409,"message":"账号已存在"}"#.utf8), ["Content-Type": "application/json"])
            }
            return (429, Data(), ["Content-Type": "application/json"])
        }

        do {
            _ = try await client.health()
            XCTFail("health should fail")
        } catch let error as FamilyPulseServerClient.ApiClientError {
            XCTAssertEqual(error.errorDescription, "账号已存在")
        } catch {
            XCTFail("unexpected error: \(error)")
        }

        do {
            _ = try await client.listFamilies()
            XCTFail("listFamilies should fail")
        } catch let error as FamilyPulseServerClient.ApiClientError {
            XCTAssertEqual(error.errorDescription, "请求过于频繁，请稍后重试")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    private func makeClient() -> FamilyPulseServerClient {
        return FamilyPulseServerClient(
            baseURL: URL(string: "http://familypulse.test")!,
            session: session
        )
    }

    private func XCTAssertBody(of request: URLRequest, contains expected: String, file: StaticString = #filePath, line: UInt = #line) {
        let body = request.httpBody.flatMap { String(data: $0, encoding: .utf8) } ?? ""
        XCTAssertTrue(body.contains(expected), "body was \(body)", file: file, line: line)
    }

    private static func response(for request: URLRequest) -> (Int, Data, [String: String]) {
        let path = request.url?.path ?? ""
        let method = request.httpMethod ?? "GET"
        if path == "/api/health" { return json(#"{"status":"UP","serverTime":"2026-05-31T00:00:00Z"}"#) }
        if path.hasPrefix("/api/auth/") { return json(authResponse) }
        if path == "/api/families", method == "GET" { return json("[\(family)]") }
        if path == "/api/families" || path == "/api/families/join" { return json(family) }
        if path.hasSuffix("/elders") { return json(elder) }
        if path.hasSuffix("/overview") { return json(overview) }
        if path.contains("/action-history") { return json("[\(activity)]") }
        if path == "/api/subscription/status" { return json(subscription(tier: "YEARLY")) }
        if path.contains("/api/subscription/purchase") { return json(subscription(tier: "MONTHLY")) }
        if path == "/api/subscription/verify-receipt" { return json(subscription(tier: "YEARLY")) }
        if path == "/api/subscription/activate-code" { return json(activatedSubscription(tier: "YEARLY")) }
        if path.hasSuffix("/actions/events") || path.contains("/actions/events/") { return json(careEvent) }
        if path.contains("/appointments/") { return json(doneAppointment) }
        if path.hasSuffix("/appointments") { return json(appointment) }
        if path == "/api/users/avatar" { return json(user(avatarColor: "orange")) }
        if path == "/api/users/password" { return json(user(hasPassword: true)) }
        if path == "/api/users/wechat" { return json(user(hasWeChatBinding: true)) }
        if path.hasSuffix("/actions/manage") && method == "GET" { return json("[\(customAction)]") }
        if path.hasSuffix("/actions/manage") { return json(customAction) }
        if path.contains("/actions/manage/") || path.hasSuffix("/leave") { return json("{}") }
        return json("{}")
    }

    private static func json(_ value: String) -> (Int, Data, [String: String]) {
        (200, Data(value.utf8), ["Content-Type": "application/json"])
    }

    private static let family = #"{"id":"99999999-9999-4999-8999-999999999999","name":"爸妈健康同步","inviteCode":"FAMILY26","role":"ADMIN"}"#
    private static let elder = #"{"id":"11111111-1111-4111-8111-111111111111","familyId":"99999999-9999-4999-8999-999999999999","name":"妈妈","birthYear":1958,"notes":"高血压","createdAt":"2026-05-31T00:00:00Z"}"#
    private static let activity = #"{"type":"CARE_ACTION","entityId":"77777777-7777-4777-8777-777777777777","elderId":"11111111-1111-4111-8111-111111111111","elderName":"妈妈","actorUserId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","actorDisplayName":"我","actorAvatarSymbol":"person.crop.circle.fill","actorAvatarColor":"green","title":"妈妈 已吃早药","subtitle":"完成 · 我","comment":null,"occurredAt":"2026-05-31T08:00:00Z"}"#
    private static let careEvent = #"{"id":"77777777-7777-4777-8777-777777777777","familyId":"99999999-9999-4999-8999-999999999999","elderId":"11111111-1111-4111-8111-111111111111","actionKey":"morning_meds","status":"DONE","eventDate":"2026-05-31","eventTime":"2026-05-31T08:00:00Z","source":"APP","note":null,"createdByUserId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa"}"#
    private static let appointment = #"{"id":"66666666-6666-4666-8666-666666666666","familyId":"99999999-9999-4999-8999-999999999999","elderId":"11111111-1111-4111-8111-111111111111","title":"复查","scheduledAt":"2026-06-01T08:00:00Z","hospital":"市医院","department":"内分泌","assignedToUserId":null,"checklist":["化验单"],"note":"空腹","resultNote":null,"status":"PLANNED","createdByUserId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","createdAt":"2026-05-31T08:00:00Z"}"#
    private static let doneAppointment = appointment.replacingOccurrences(of: #""status":"PLANNED""#, with: #""status":"DONE","resultNote":"完成""#)
    private static let customAction = #"{"id":"55555555-5555-4555-8555-555555555555","actionKey":"walk","title":"散步","icon":"figure.walk","sortOrder":100,"elderId":"11111111-1111-4111-8111-111111111111"}"#
    private static let overview = #"{"family":\#(family),"members":[{"id":"bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb","userId":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","displayName":"我","role":"ADMIN","avatarSymbol":"person.crop.circle.fill","avatarColor":"green"}],"elders":[{"elder":\#(elder),"todayActions":[{"actionKey":"morning_meds","title":"已吃早药","icon":"pills.fill","sortOrder":1,"completed":true,"completedAt":"2026-05-31T08:00:00Z","source":"APP","eventId":"77777777-7777-4777-8777-777777777777"}]}],"recentRecords":[],"upcomingAppointments":[\#(appointment)],"feed":[\#(activity)]}"#
    private static let authResponse = #"{"user":\#(user()),"token":"token","expiresAt":"2026-06-30T00:00:00Z"}"#

    private static func user(avatarColor: String = "green", hasPassword: Bool = false, hasWeChatBinding: Bool = false) -> String {
        #"{"id":"aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa","externalId":"password:alice","username":"alice","displayName":"Alice","avatarSymbol":"person.crop.circle.fill","avatarColor":"\#(avatarColor)","subscriptionTier":"FREE","hasPassword":\#(hasPassword),"hasWeChatBinding":\#(hasWeChatBinding),"isGuest":false}"#
    }

    private static func subscription(tier: String) -> String {
        #"{"tier":"\#(tier)","expiresAt":"2026-06-30T00:00:00Z","canUploadAttachments":false,"canCreateMultipleFamilies":true,"canQueueOfflineActions":true,"syncDelaySeconds":\#(tier == "YEARLY" ? 10 : 30),"maxCustomActionsPerElder":\#(tier == "YEARLY" ? 20 : 3),"historyRetentionDays":\#(tier == "YEARLY" ? -1 : 7),"historyDailyLimit":10,"activationCode":"FP-ABCD-2345","activationDeviceLimit":\#(tier == "YEARLY" ? 4 : 2),"activationUsedCount":1}"#
    }

    private static func activatedSubscription(tier: String) -> String {
        #"{"tier":"\#(tier)","expiresAt":"2026-06-30T00:00:00Z","canUploadAttachments":false,"canCreateMultipleFamilies":true,"canQueueOfflineActions":true,"syncDelaySeconds":\#(tier == "YEARLY" ? 10 : 30),"maxCustomActionsPerElder":\#(tier == "YEARLY" ? 20 : 3),"historyRetentionDays":\#(tier == "YEARLY" ? -1 : 7),"historyDailyLimit":10,"activationCode":null,"activationDeviceLimit":0,"activationUsedCount":0}"#
    }
}

private extension ServerCareActionEvent {
    var eventIdString: String { id.uuidString }
}

private final class StubHTTPSession: FamilyPulseHTTPSession {
    var seenRequests: [URLRequest] = []
    var handler: (URLRequest) -> (Int, Data, [String: String])

    init(handler: @escaping (URLRequest) -> (Int, Data, [String: String])) {
        self.handler = handler
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else {
            throw URLError(.badURL)
        }
        seenRequests.append(request)
        let (status, data, headers) = handler(request)
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
        return (data, response)
    }
}
