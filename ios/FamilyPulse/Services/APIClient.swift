import Foundation

protocol FamilyPulseHTTPSession {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: FamilyPulseHTTPSession {}

struct FamilyPulseServerClient {
    var baseURL: URL
    var authToken = ""
    var session: any FamilyPulseHTTPSession = URLSession.shared

    func health() async throws -> String {
        let decoded: HealthResponse = try await send(path: "/api/health", method: "GET")
        return decoded.status
    }

    func guestLogin() async throws -> ServerAuthResponse {
        try await send(
            path: "/api/auth/guest",
            method: "POST",
            body: Optional<EmptyBody>.none,
            includeAuthHeaders: false
        )
    }

    func register(username: String, password: String, displayName: String) async throws -> ServerAuthResponse {
        try await send(
            path: "/api/auth/register",
            method: "POST",
            body: RegisterRequest(username: username, password: password, displayName: displayName),
            includeAuthHeaders: false
        )
    }

    func login(username: String, password: String) async throws -> ServerAuthResponse {
        try await send(
            path: "/api/auth/login",
            method: "POST",
            body: LoginRequest(username: username, password: password),
            includeAuthHeaders: false
        )
    }

    func loginWithWeChat(code: String, openId: String?, unionId: String?, nickname: String?) async throws -> ServerAuthResponse {
        try await send(
            path: "/api/auth/wechat",
            method: "POST",
            body: WeChatLoginRequest(code: code, openId: openId, unionId: unionId, nickname: nickname, avatarUrl: nil),
            includeAuthHeaders: false
        )
    }

    func loginWithApple(identityToken: String, displayName: String?) async throws -> ServerAuthResponse {
        try await send(
            path: "/api/auth/apple",
            method: "POST",
            body: AppleLoginRequest(identityToken: identityToken, authorizationCode: nil, displayName: displayName),
            includeAuthHeaders: false
        )
    }

    func listFamilies() async throws -> [ServerFamily] {
        try await send(path: "/api/families", method: "GET")
    }

    func createFamily(name: String) async throws -> ServerFamily {
        try await send(path: "/api/families", method: "POST", body: CreateFamilyRequest(name: name))
    }

    func joinFamily(inviteCode: String) async throws -> ServerFamily {
        try await send(path: "/api/families/join", method: "POST", body: JoinFamilyRequest(inviteCode: inviteCode))
    }

    func createElder(familyId: UUID, name: String, birthYear: Int?, notes: String?) async throws -> ServerElder {
        try await send(
            path: "/api/families/\(familyId.uuidString)/elders",
            method: "POST",
            body: CreateElderRequest(name: name, birthYear: birthYear, notes: notes)
        )
    }

    func deleteElder(familyId: UUID, elderId: UUID) async throws {
        let _: String? = try await send(path: "/api/families/\(familyId.uuidString)/elders/\(elderId.uuidString)", method: "DELETE")
    }

    func overview(familyId: UUID) async throws -> ServerOverview {
        try await send(path: "/api/families/\(familyId.uuidString)/overview", method: "GET")
    }

    func actionHistory(familyId: UUID, date: Date?, limit: Int = 10) async throws -> [ServerActivityItem] {
        var path = "/api/families/\(familyId.uuidString)/action-history?limit=\(limit)"
        if let date {
            path += "&date=\(Self.localDateFormatter.string(from: date))"
        }
        return try await send(path: path, method: "GET")
    }

    func activityHeatmap(familyId: UUID, days: Int = 365) async throws -> [ServerElderActivityHeatmap] {
        let path = "/api/families/\(familyId.uuidString)/activity-heatmap?days=\(days)"
        return try await send(path: path, method: "GET")
    }

    // MARK: - Subscription

    struct SubscriptionStatus: Decodable {
        var tier: String
        var expiresAt: Date?
        var canUploadAttachments: Bool
        var canCreateMultipleFamilies: Bool
        var canQueueOfflineActions: Bool
        var canUsePushNotifications: Bool
        var syncDelaySeconds: Int
        var maxCustomActionsPerElder: Int
        var historyRetentionDays: Int
        var historyDailyLimit: Int
        var activationCode: String?
        var activationDeviceLimit: Int
        var activationUsedCount: Int

        private enum CodingKeys: String, CodingKey {
            case tier
            case expiresAt
            case canUploadAttachments
            case canCreateMultipleFamilies
            case canQueueOfflineActions
            case canUsePushNotifications
            case syncDelaySeconds
            case maxCustomActionsPerElder
            case historyRetentionDays
            case historyDailyLimit
            case activationCode
            case activationDeviceLimit
            case activationUsedCount
        }

        init(
            tier: String,
            expiresAt: Date? = nil,
            canUploadAttachments: Bool = false,
            canCreateMultipleFamilies: Bool = false,
            canQueueOfflineActions: Bool = false,
            canUsePushNotifications: Bool = false,
            syncDelaySeconds: Int = 0,
            maxCustomActionsPerElder: Int = 0,
            historyRetentionDays: Int = 0,
            historyDailyLimit: Int = 10,
            activationCode: String? = nil,
            activationDeviceLimit: Int = 0,
            activationUsedCount: Int = 0
        ) {
            self.tier = tier
            self.expiresAt = expiresAt
            self.canUploadAttachments = canUploadAttachments
            self.canCreateMultipleFamilies = canCreateMultipleFamilies
            self.canQueueOfflineActions = canQueueOfflineActions
            self.canUsePushNotifications = canUsePushNotifications
            self.syncDelaySeconds = syncDelaySeconds
            self.maxCustomActionsPerElder = maxCustomActionsPerElder
            self.historyRetentionDays = historyRetentionDays
            self.historyDailyLimit = historyDailyLimit
            self.activationCode = activationCode
            self.activationDeviceLimit = activationDeviceLimit
            self.activationUsedCount = activationUsedCount
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            tier = try container.decode(String.self, forKey: .tier)
            expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
            canUploadAttachments = try container.decodeIfPresent(Bool.self, forKey: .canUploadAttachments) ?? false
            canCreateMultipleFamilies = try container.decodeIfPresent(Bool.self, forKey: .canCreateMultipleFamilies) ?? (tier != "FREE")
            canQueueOfflineActions = try container.decodeIfPresent(Bool.self, forKey: .canQueueOfflineActions) ?? (tier != "FREE")
            canUsePushNotifications = try container.decodeIfPresent(Bool.self, forKey: .canUsePushNotifications) ?? (tier != "FREE")
            syncDelaySeconds = try container.decodeIfPresent(Int.self, forKey: .syncDelaySeconds) ?? (tier == "YEARLY" ? 10 : (tier == "FREE" ? 0 : 30))
            maxCustomActionsPerElder = try container.decodeIfPresent(Int.self, forKey: .maxCustomActionsPerElder) ?? (tier == "YEARLY" ? 20 : (tier == "FREE" ? 0 : 3))
            historyRetentionDays = try container.decodeIfPresent(Int.self, forKey: .historyRetentionDays) ?? (tier == "YEARLY" ? -1 : (tier == "FREE" ? 0 : 7))
            historyDailyLimit = try container.decodeIfPresent(Int.self, forKey: .historyDailyLimit) ?? 10
            activationCode = try container.decodeIfPresent(String.self, forKey: .activationCode)
            activationDeviceLimit = try container.decodeIfPresent(Int.self, forKey: .activationDeviceLimit) ?? 0
            activationUsedCount = try container.decodeIfPresent(Int.self, forKey: .activationUsedCount) ?? 0
        }
    }

    func getSubscriptionStatus() async throws -> SubscriptionStatus {
        try await send(path: "/api/subscription/status", method: "GET")
    }

    func purchasePremium(tier: String = "MONTHLY") async throws -> SubscriptionStatus {
        try await send(path: "/api/subscription/purchase?tier=\(tier)", method: "POST")
    }

    func verifyReceipt(transactionJws: String) async throws -> SubscriptionStatus {
        try await send(path: "/api/subscription/verify-receipt", method: "POST", body: VerifyReceiptRequest(transactionJws: transactionJws))
    }

    func activateSubscriptionCode(code: String, deviceId: String) async throws -> SubscriptionStatus {
        try await send(path: "/api/subscription/activate-code", method: "POST", body: ActivateSubscriptionCodeRequest(code: code, deviceId: deviceId))
    }

    func registerPushDeviceToken(_ token: String, environment: String) async throws -> ServerPushDevice {
        try await send(
            path: "/api/notifications/device-token",
            method: "POST",
            body: RegisterPushDeviceRequest(deviceToken: token, platform: "IOS", environment: environment)
        )
    }

    func disablePushDeviceToken(_ token: String) async throws -> ServerPushDevice {
        let encodedToken = token.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? token
        return try await send(path: "/api/notifications/device-token/\(encodedToken)", method: "DELETE")
    }

    func leaveFamily(familyId: UUID) async throws {
        let _: String? = try await send(path: "/api/families/\(familyId.uuidString)/leave", method: "POST")
    }

    func createCareEvent(familyId: UUID, elderId: UUID, actionKey: String, occurredAt: Date = Date()) async throws -> ServerCareActionEvent {
        try await send(
            path: "/api/families/\(familyId.uuidString)/elders/\(elderId.uuidString)/actions/events",
            method: "POST",
            body: CreateCareActionEventRequest(
                actionKey: actionKey,
                status: "DONE",
                eventDate: Self.localDateFormatter.string(from: occurredAt),
                eventTime: Self.isoFormatter.string(from: occurredAt),
                source: "APP"
            )
        )
    }

    func undoCareEvent(familyId: UUID, elderId: UUID, eventId: UUID) async throws -> ServerCareActionEvent {
        try await send(
            path: "/api/families/\(familyId.uuidString)/elders/\(elderId.uuidString)/actions/events/\(eventId.uuidString)",
            method: "DELETE"
        )
    }

    func createAppointment(
        familyId: UUID,
        elderId: UUID,
        title: String,
        scheduledAt: Date,
        hospital: String,
        department: String,
        assignedToUserId: UUID?,
        checklist: [String],
        note: String
    ) async throws -> ServerAppointment {
        try await send(
            path: "/api/families/\(familyId.uuidString)/appointments",
            method: "POST",
            body: CreateAppointmentRequest(
                elderId: elderId,
                title: title,
                scheduledAt: Self.isoFormatter.string(from: scheduledAt),
                hospital: hospital,
                department: department,
                assignedToUserId: assignedToUserId,
                checklist: checklist,
                note: note
            )
        )
    }

    func updateAvatar(symbol: String, color: String) async throws -> ServerUser {
        try await send(path: "/api/users/avatar", method: "PATCH", body: UpdateAvatarRequest(avatarSymbol: symbol, avatarColor: color))
    }

    func updateUsername(_ username: String) async throws -> ServerUser {
        try await send(path: "/api/users/username", method: "PATCH", body: UpdateUsernameRequest(username: username))
    }

    func updateDisplayName(_ displayName: String) async throws -> ServerUser {
        try await send(path: "/api/users/display-name", method: "PATCH", body: UpdateDisplayNameRequest(displayName: displayName))
    }

    func setPassword(currentPassword: String?, newPassword: String) async throws -> ServerUser {
        try await send(path: "/api/users/password", method: "PATCH", body: SetPasswordRequest(currentPassword: currentPassword, newPassword: newPassword))
    }

    func fetchCurrentUser() async throws -> ServerUser {
        try await send(path: "/api/users/me", method: "GET")
    }

    func bindWeChat(code: String, openId: String?, unionId: String?, nickname: String?) async throws -> ServerUser {
        try await send(path: "/api/users/wechat", method: "POST", body: BindWeChatRequest(code: code, openId: openId, unionId: unionId, nickname: nickname, avatarUrl: nil))
    }

    func deleteAccount() async throws {
        let _: [String: String] = try await send(path: "/api/account", method: "DELETE")
    }

    func listCustomActions(familyId: UUID) async throws -> [ServerCustomAction] {
        try await send(path: "/api/families/\(familyId.uuidString)/actions/manage", method: "GET")
    }

    func createCustomAction(familyId: UUID, elderId: UUID, actionKey: String, title: String, icon: String) async throws -> ServerCustomAction {
        try await send(path: "/api/families/\(familyId.uuidString)/actions/manage", method: "POST", body: CreateCustomActionRequest(actionKey: actionKey, title: title, icon: icon, sortOrder: 100, elderId: elderId))
    }

    func deleteCustomAction(familyId: UUID, elderId: UUID, actionKey: String) async throws {
        let _: String? = try await send(path: "/api/families/\(familyId.uuidString)/actions/manage/\(actionKey)?elderId=\(elderId.uuidString)", method: "DELETE")
    }

    func markAppointmentDone(familyId: UUID, appointmentId: UUID, resultNote: String) async throws -> ServerAppointment {
        try await send(
            path: "/api/families/\(familyId.uuidString)/appointments/\(appointmentId.uuidString)",
            method: "PATCH",
            body: PatchAppointmentRequest(status: "DONE", resultNote: resultNote)
        )
    }

    private func send<Response: Decodable>(path: String, method: String) async throws -> Response {
        let empty: EmptyBody? = nil
        return try await send(path: path, method: method, body: empty)
    }

    private func send<RequestBody: Encodable, Response: Decodable>(
        path: String,
        method: String,
        body: RequestBody?,
        includeAuthHeaders: Bool = true
    ) async throws -> Response {
        // appending(path:) percent-encodes ? and =, breaking query parameters.
        // Use string concatenation instead to preserve query strings.
        guard let url = URL(string: baseURL.absoluteString + path) else {
            throw ApiClientError.networkError("无效的 URL")
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if includeAuthHeaders {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        if let body {
            request.httpBody = try Self.encoder.encode(body)
        }
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ApiClientError.networkError("无法连接服务器")
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            if let serverError = try? Self.decoder.decode(ServerErrorResponse.self, from: data) {
                throw ApiClientError.serverError(httpResponse.statusCode, serverError.message)
            }
            throw ApiClientError.serverError(httpResponse.statusCode, httpErrorMessage(for: httpResponse.statusCode))
        }
        return try Self.decoder.decode(Response.self, from: data)
    }

    private func httpErrorMessage(for statusCode: Int) -> String {
        switch statusCode {
        case 400: "请求参数有误"
        case 401: "登录已过期，请重新登录"
        case 402: "订阅后可使用此功能"
        case 403: "没有访问权限"
        case 404: "请求的资源不存在"
        case 409: "账号已存在"
        case 422: "输入数据不合法"
        case 429: "请求过于频繁，请稍后重试"
        case 500...599: "服务器内部错误，请稍后重试"
        default: "操作失败（\(statusCode)）"
        }
    }

    enum ApiClientError: Error, LocalizedError {
        case networkError(String)
        case serverError(Int, String)

        var errorDescription: String? {
            switch self {
            case .networkError(let msg), .serverError(_, let msg): msg
            }
        }
    }

    private struct ServerErrorResponse: Decodable {
        var status: Int
        var message: String
        var timestamp: String?
    }

    private static let encoder = JSONEncoder()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            if let date = isoFormatter.date(from: value) {
                return date
            }
            if let date = isoFormatterNoFraction.date(from: value) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO date: \(value)")
        }
        return decoder
    }()

    static let isoFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let isoFormatterNoFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    private static let localDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

private struct EmptyBody: Encodable {}

private struct HealthResponse: Decodable {
    var status: String
    var serverTime: Date?
}

private struct RegisterRequest: Encodable {
    var username: String
    var password: String
    var displayName: String
}

private struct LoginRequest: Encodable {
    var username: String
    var password: String
}

private struct AppleLoginRequest: Encodable {
    var identityToken: String
    var authorizationCode: String?
    var displayName: String?
}

private struct WeChatLoginRequest: Encodable {
    var code: String
    var openId: String?
    var unionId: String?
    var nickname: String?
    var avatarUrl: String?
}

private struct SetPasswordRequest: Encodable {
    var currentPassword: String?
    var newPassword: String
}

private struct BindWeChatRequest: Encodable {
    var code: String
    var openId: String?
    var unionId: String?
    var nickname: String?
    var avatarUrl: String?
}

private struct CreateFamilyRequest: Encodable {
    var name: String
}

private struct JoinFamilyRequest: Encodable {
    var inviteCode: String
}

private struct CreateElderRequest: Encodable {
    var name: String
    var birthYear: Int?
    var notes: String?
}

private struct CreateCareActionEventRequest: Encodable {
    var actionKey: String
    var status: String
    var eventDate: String
    var eventTime: String
    var source: String
}

private struct CreateAppointmentRequest: Encodable {
    var elderId: UUID
    var title: String
    var scheduledAt: String
    var hospital: String
    var department: String
    var assignedToUserId: UUID?
    var checklist: [String]
    var note: String
}

private struct PatchAppointmentRequest: Encodable {
    var status: String
    var resultNote: String
}

private struct UpdateAvatarRequest: Encodable {
    var avatarSymbol: String
    var avatarColor: String
}

private struct UpdateUsernameRequest: Encodable {
    var username: String
}

private struct UpdateDisplayNameRequest: Encodable {
    var displayName: String
}

private struct CreateCustomActionRequest: Encodable {
    var actionKey: String
    var title: String
    var icon: String
    var sortOrder: Int
    var elderId: UUID
}

struct ServerCustomAction: Decodable, Identifiable, Equatable {
    var id: UUID
    var actionKey: String
    var title: String
    var icon: String
    var sortOrder: Int
    var elderId: UUID
}

private struct VerifyReceiptRequest: Encodable {
    var transactionJws: String
}

private struct ActivateSubscriptionCodeRequest: Encodable {
    var code: String
    var deviceId: String
}

private struct RegisterPushDeviceRequest: Encodable {
    var deviceToken: String
    var platform: String
    var environment: String
}

struct ServerDailyActionCount: Decodable, Equatable {
    var date: String
    var count: Int
}

struct ServerElderActivityHeatmap: Decodable, Identifiable, Equatable {
    var elderId: UUID
    var elderName: String
    var dailyCounts: [ServerDailyActionCount]

    var id: UUID { elderId }
}

struct ServerPushDevice: Decodable, Equatable {
    var id: UUID
    var platform: String
    var environment: String
    var enabled: Bool
    var lastRegisteredAt: Date
}

struct ServerAuthResponse: Decodable, Equatable {
    var user: ServerUser
    var token: String
    var expiresAt: Date
}

struct ServerUser: Codable, Equatable {
    var id: UUID
    var externalId: String
    var username: String?
    var displayName: String
    var avatarSymbol: String?
    var avatarColor: String?
    var subscriptionTier: String?
    var hasPassword: Bool?
    var hasWeChatBinding: Bool?
    var isGuest: Bool?

    var needsRecoverySetup: Bool {
        !(hasPassword ?? false) && !(hasWeChatBinding ?? false)
    }
}

struct ServerFamily: Decodable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var inviteCode: String
    var role: String
}

struct ServerMember: Decodable, Identifiable, Equatable {
    var id: UUID
    var userId: UUID
    var displayName: String
    var role: String
    var avatarSymbol: String?
    var avatarColor: String?
}

struct ServerOverview: Decodable {
    var family: ServerFamily
    var members: [ServerMember]
    var elders: [ServerElderOverview]
    var recentRecords: [ServerMedicalRecord]
    var upcomingAppointments: [ServerAppointment]
    var feed: [ServerActivityItem]

    init(
        family: ServerFamily,
        members: [ServerMember],
        elders: [ServerElderOverview],
        recentRecords: [ServerMedicalRecord],
        upcomingAppointments: [ServerAppointment],
        feed: [ServerActivityItem]
    ) {
        self.family = family
        self.members = members
        self.elders = elders
        self.recentRecords = recentRecords
        self.upcomingAppointments = upcomingAppointments
        self.feed = feed
    }

    private enum CodingKeys: String, CodingKey {
        case family
        case members
        case elders
        case recentRecords
        case upcomingAppointments
        case feed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        family = try container.decode(ServerFamily.self, forKey: .family)
        members = try container.decodeIfPresent([ServerMember].self, forKey: .members) ?? []
        elders = try container.decodeIfPresent([ServerElderOverview].self, forKey: .elders) ?? []
        recentRecords = try container.decodeIfPresent([ServerMedicalRecord].self, forKey: .recentRecords) ?? []
        upcomingAppointments = try container.decodeIfPresent([ServerAppointment].self, forKey: .upcomingAppointments) ?? []
        feed = try container.decodeIfPresent([ServerActivityItem].self, forKey: .feed) ?? []
    }
}

struct ServerElderOverview: Decodable {
    var elder: ServerElder
    var todayActions: [ServerTodayAction]

    init(elder: ServerElder, todayActions: [ServerTodayAction]) {
        self.elder = elder
        self.todayActions = todayActions
    }

    private enum CodingKeys: String, CodingKey {
        case elder
        case todayActions
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        elder = try container.decode(ServerElder.self, forKey: .elder)
        todayActions = try container.decodeIfPresent([ServerTodayAction].self, forKey: .todayActions) ?? []
    }
}

struct ServerElder: Decodable, Identifiable, Equatable {
    var id: UUID
    var familyId: UUID
    var name: String
    var birthYear: Int?
    var notes: String?
    var createdAt: Date
}

struct ServerTodayAction: Decodable, Equatable {
    var actionKey: String
    var title: String
    var icon: String
    var sortOrder: Int
    var completed: Bool
    var completedAt: Date?
    var source: String?
    var eventId: UUID?
}

struct ServerCareActionEvent: Decodable, Equatable {
    var id: UUID
    var familyId: UUID
    var elderId: UUID
    var actionKey: String
    var status: String
    var eventDate: String
    var eventTime: Date
    var source: String
    var note: String?
    var createdByUserId: UUID
}

struct ServerMedicalRecord: Decodable, Identifiable, Equatable {
    var id: UUID
    var familyId: UUID
    var elderId: UUID
    var recordType: String
    var recordDate: String?
    var title: String
    var ocrText: String?
    var fields: [ServerRecordField]
    var createdByUserId: UUID
    var createdAt: Date
    var attachmentCount: Int?
}

struct ServerRecordField: Decodable, Equatable {
    var name: String
    var value: String
    var unit: String?
    var confidence: Double?
}

struct ServerAppointment: Decodable, Identifiable, Equatable {
    var id: UUID
    var familyId: UUID
    var elderId: UUID
    var title: String
    var scheduledAt: Date
    var hospital: String?
    var department: String?
    var assignedToUserId: UUID?
    var checklist: [String]
    var note: String?
    var resultNote: String?
    var status: String
    var createdByUserId: UUID?
    var createdAt: Date
}

struct ServerActivityItem: Decodable, Identifiable, Equatable {
    var id: UUID { entityId }
    var type: String
    var entityId: UUID
    var elderId: UUID
    var elderName: String?
    var actorUserId: UUID?
    var actorDisplayName: String?
    var actorAvatarSymbol: String?
    var actorAvatarColor: String?
    var title: String
    var subtitle: String
    var comment: String?
    var occurredAt: Date
}

extension FamilySnapshot {
    static func from(server overview: ServerOverview) -> FamilySnapshot {
        let members = overview.members.map {
            FamilyMember(
                id: $0.userId,
                displayName: $0.displayName,
                role: $0.role,
                avatarSymbol: $0.avatarSymbol ?? "person.crop.circle.fill",
                avatarColor: $0.avatarColor ?? "green"
            )
        }
        let memberNames = Dictionary(uniqueKeysWithValues: members.map { ($0.id, $0.displayName) })
        let elderNames = Dictionary(uniqueKeysWithValues: overview.elders.map { ($0.elder.id, $0.elder.name) })
        return FamilySnapshot(
            familyId: overview.family.id,
            familyName: overview.family.name,
            inviteCode: overview.family.inviteCode,
            members: members,
            elders: overview.elders.map { elderOverview in
                ElderStatus(
                    id: elderOverview.elder.id,
                    name: elderOverview.elder.name,
                    subtitle: elderOverview.elder.notes ?? "家庭照护对象",
                    actions: elderOverview.todayActions
                        .sorted { $0.sortOrder < $1.sortOrder }
                        .map { action in
                            CareAction(
                                actionKey: action.actionKey,
                                title: action.title,
                                symbolName: action.icon,
                                completedAt: action.completed ? action.completedAt : nil,
                                source: action.source.flatMap(ActionSource.init(rawValue:)),
                                eventId: action.eventId
                            )
                        }
                )
            },
            feed: overview.feed.map { item in
                ActivityItem(
                    id: item.entityId,
                    title: item.title,
                    subtitle: item.subtitle,
                    comment: item.comment,
                    elderName: item.elderName ?? elderNames[item.elderId] ?? "照护对象",
                    actorDisplayName: item.actorDisplayName ?? "家庭成员",
                    actorAvatarSymbol: item.actorAvatarSymbol ?? "person.crop.circle.fill",
                    actorAvatarColor: item.actorAvatarColor ?? "green",
                    symbolName: symbolName(for: item.type),
                    occurredAt: item.occurredAt,
                    tone: item.type == "CARE_ACTION" ? .success : .calm
                )
            },
            records: overview.recentRecords.map { record in
                MedicalRecord(
                    id: record.id,
                    title: record.title,
                    recordType: record.recordType,
                    recordDate: record.createdAt,
                    fields: record.fields.map { RecordField(name: $0.name, value: $0.value, unit: $0.unit, confidence: $0.confidence) },
                    confirmationState: "家人已核对",
                    hasAttachments: (record.attachmentCount ?? 0) > 0,
                    familyId: record.familyId,
                    elderId: record.elderId
                )
            },
            appointments: overview.upcomingAppointments.map { appointment in
                Appointment(
                    id: appointment.id,
                    elderId: appointment.elderId,
                    elderName: elderNames[appointment.elderId] ?? "照护对象",
                    title: appointment.title,
                    hospital: appointment.hospital ?? "未填写医院",
                    department: appointment.department ?? "未填写科室",
                    scheduledAt: appointment.scheduledAt,
                    assigneeName: appointment.assignedToUserId.flatMap { memberNames[$0] } ?? "未指派",
                    createdByName: appointment.createdByUserId.flatMap { memberNames[$0] } ?? "家庭成员",
                    checklist: appointment.checklist,
                    note: appointment.note,
                    resultNote: appointment.resultNote,
                    status: AppointmentStatus(rawValue: appointment.status) ?? .planned
                )
            },
            lastUpdatedAt: Date()
        )
    }

    private static func symbolName(for activityType: String) -> String {
        switch activityType {
        case "MEDICAL_RECORD": "doc.text.viewfinder"
        case "APPOINTMENT": "calendar.badge.clock"
        default: "heart.text.square.fill"
        }
    }
}
