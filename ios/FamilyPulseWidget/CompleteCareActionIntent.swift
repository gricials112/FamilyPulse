import AppIntents
import Foundation
import WidgetKit

struct CompleteCareActionIntent: AppIntent {
    static var title: LocalizedStringResource = "记录照护操作"
    static var description = IntentDescription("从小组件快速记录照护操作")

    @Parameter(title: "actionKey")
    var actionKey: String

    @Parameter(title: "elderId")
    var elderId: String

    init() {}

    init(actionKey: String, elderId: String) {
        self.actionKey = actionKey
        self.elderId = elderId
    }

    func perform() async throws -> some IntentResult {
        guard let token = WidgetSharedDefaults.authToken,
              let familyId = WidgetSharedDefaults.familyId else {
            return .result(dialog: "请先打开 App 登录")
        }

        let client = CareActionWidgetClient(authToken: token)
        do {
            try await client.createCareEvent(
                familyId: familyId,
                elderId: elderId,
                actionKey: actionKey
            )
            // Refresh widget timelines
            WidgetCenter.shared.reloadAllTimelines()
            return .result(dialog: "已记录")
        } catch {
            return .result(dialog: "记录失败，请稍后重试")
        }
    }
}

// MARK: - App Intent for the "Open App" button

struct OpenAppIntent: OpenIntent {
    static var title: LocalizedStringResource = "打开家安"

    @Parameter(title: "target")
    var target: AppTargetEntity

    init() {}

    init(target: AppTargetEntity) {
        self.target = target
    }

    func perform() async throws -> some IntentResult {
        .result()
    }
}

struct AppTargetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "App Target"
    static var defaultQuery = AppTargetQuery()

    var id: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(id)")
    }
}

struct AppTargetQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [AppTargetEntity] {
        identifiers.map { AppTargetEntity(id: $0) }
    }

    func suggestedEntities() async throws -> [AppTargetEntity] {
        [AppTargetEntity(id: "default")]
    }
}

// MARK: - Lightweight widget client for App Intents

private struct CareActionWidgetClient {
    let authToken: String
    private let baseURL = URL(string: "https://jiaan.online")!

    func createCareEvent(familyId: String, elderId: String, actionKey: String) async throws {
        let now = ISO8601DateFormatter()
        now.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let dateFmt = DateFormatter()
        dateFmt.calendar = Calendar(identifier: .gregorian)
        dateFmt.locale = Locale(identifier: "en_US_POSIX")
        dateFmt.dateFormat = "yyyy-MM-dd"

        let body: [String: String] = [
            "actionKey": actionKey,
            "status": "DONE",
            "eventDate": dateFmt.string(from: Date()),
            "eventTime": now.string(from: Date()),
            "source": "WIDGET"
        ]

        guard let url = URL(string: baseURL.absoluteString + "/api/families/\(familyId)/elders/\(elderId)/actions/events") else {
            throw WidgetError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw WidgetError.requestFailed
        }
    }
}
