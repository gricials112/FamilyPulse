import Foundation
import WidgetKit

// MARK: - Shared UserDefaults (App Group)

enum WidgetSharedDefaults {
    private static let suite = UserDefaults(suiteName: "group.com.lwj.FamilyPulse")

    static var authToken: String? {
        get { suite?.string(forKey: "authToken") }
        set { suite?.set(newValue, forKey: "authToken") }
    }

    static var selectedElderId: String? {
        get { suite?.string(forKey: "selectedElderId") }
        set { suite?.set(newValue, forKey: "selectedElderId") }
    }

    static var familyId: String? {
        get { suite?.string(forKey: "familyId") }
        set { suite?.set(newValue, forKey: "familyId") }
    }

    static var elderName: String? {
        get { suite?.string(forKey: "elderName") }
        set { suite?.set(newValue, forKey: "elderName") }
    }

    /// Saves the current session context so the widget can read it.
    static func saveSession(authToken: String, familyId: String, elderId: String, elderName: String) {
        self.authToken = authToken
        self.familyId = familyId
        self.selectedElderId = elderId
        self.elderName = elderName
    }

    static func clearSession() {
        authToken = nil
        familyId = nil
        selectedElderId = nil
        elderName = nil
    }
}

// MARK: - Widget Entry

struct ElderActionsEntry: TimelineEntry {
    let date: Date
    let actions: [WidgetCareAction]  // current page's actions
    let allActions: [WidgetCareAction] // full list for page count
    let pageIndex: Int
    let totalPages: Int
    let elderName: String
    let isAuthenticated: Bool
    let isPremium: Bool
}

struct WidgetCareAction: Identifiable, Equatable {
    let id: String // actionKey
    let title: String
    let symbolName: String
    let isCompleted: Bool
}

// MARK: - Widget Data Manager

actor WidgetDataManager {
    func fetchTimeline() async -> ElderActionsEntry {
        return await fetchPage(pageIndex: 0)
    }

    func fetchAllPages() async -> [ElderActionsEntry] {
        guard let token = WidgetSharedDefaults.authToken,
              let familyId = WidgetSharedDefaults.familyId,
              let elderId = WidgetSharedDefaults.selectedElderId else {
            return [unauthenticatedEntry(date: Date())]
        }

        do {
            let client = FamilyPulseWidgetClient(authToken: token)
            let overview = try await client.fetchOverview(familyId: familyId)
            let subscription = try? await client.fetchSubscriptionStatus()

            guard let elderOverview = overview.elders.first(where: { $0.elder.id == elderId }) else {
                return [unauthenticatedEntry(date: Date())]
            }

            let allActions = elderOverview.todayActions.map { action in
                WidgetCareAction(
                    id: action.actionKey,
                    title: action.title,
                    symbolName: action.icon,
                    isCompleted: action.completed
                )
            }

            let isPremium = subscription?.tier != "FREE"
            let perPage = 4
            let totalPages = max(1, (allActions.count + perPage - 1) / perPage)
            let interval: TimeInterval = isPremium ? 8 : 10

            var entries: [ElderActionsEntry] = []
            for page in 0..<totalPages {
                let start = page * perPage
                let pageActions = Array(allActions[start..<min(start + perPage, allActions.count)])
                let entry = ElderActionsEntry(
                    date: Date().addingTimeInterval(interval * Double(page)),
                    actions: pageActions,
                    allActions: allActions,
                    pageIndex: page,
                    totalPages: totalPages,
                    elderName: elderOverview.elder.name,
                    isAuthenticated: true,
                    isPremium: isPremium
                )
                entries.append(entry)
            }
            return entries
        } catch {
            return [ElderActionsEntry(
                date: Date(),
                actions: [],
                allActions: [],
                pageIndex: 0,
                totalPages: 1,
                elderName: WidgetSharedDefaults.elderName ?? "家安",
                isAuthenticated: false,
                isPremium: false
            )]
        }
    }

    private func fetchPage(pageIndex: Int) async -> ElderActionsEntry {
        guard let token = WidgetSharedDefaults.authToken,
              let familyId = WidgetSharedDefaults.familyId,
              let elderId = WidgetSharedDefaults.selectedElderId else {
            return unauthenticatedEntry(date: Date())
        }

        do {
            let client = FamilyPulseWidgetClient(authToken: token)
            let overview = try await client.fetchOverview(familyId: familyId)
            let subscription = try? await client.fetchSubscriptionStatus()

            guard let elderOverview = overview.elders.first(where: { $0.elder.id == elderId }) else {
                return unauthenticatedEntry(date: Date())
            }

            let allActions = elderOverview.todayActions.map { action in
                WidgetCareAction(
                    id: action.actionKey,
                    title: action.title,
                    symbolName: action.icon,
                    isCompleted: action.completed
                )
            }

            let perPage = 4
            let totalPages = max(1, (allActions.count + perPage - 1) / perPage)
            let page = min(pageIndex, totalPages - 1)
            let start = page * perPage
            let pageActions = Array(allActions[start..<min(start + perPage, allActions.count)])

            return ElderActionsEntry(
                date: Date(),
                actions: pageActions,
                allActions: allActions,
                pageIndex: page,
                totalPages: totalPages,
                elderName: elderOverview.elder.name,
                isAuthenticated: true,
                isPremium: subscription?.tier != "FREE"
            )
        } catch {
            return unauthenticatedEntry(date: Date())
        }
    }

    private func unauthenticatedEntry(date: Date) -> ElderActionsEntry {
        ElderActionsEntry(
            date: date,
            actions: [],
            allActions: [],
            pageIndex: 0,
            totalPages: 1,
            elderName: WidgetSharedDefaults.elderName ?? "家安",
            isAuthenticated: false,
            isPremium: false
        )
    }
}

// MARK: - Widget API Client (lightweight for extension)

private struct FamilyPulseWidgetClient {
    let authToken: String
    private let baseURL = URL(string: "https://jiaan.online")!

    func fetchOverview(familyId: String) async throws -> WidgetOverview {
        try await send(path: "/api/families/\(familyId)/overview")
    }

    func fetchSubscriptionStatus() async throws -> WidgetSubscriptionStatus {
        try await send(path: "/api/subscription/status")
    }

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
        let _: WidgetCareEventResponse = try await send(
            path: "/api/families/\(familyId)/elders/\(elderId)/actions/events",
            method: "POST",
            body: body
        )
    }

    private func send<T: Decodable>(path: String, method: String = "GET", body: [String: String]? = nil) async throws -> T {
        guard let url = URL(string: baseURL.absoluteString + path) else {
            throw WidgetError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw WidgetError.requestFailed
        }
        return try JSONDecoder().decode(T.self, from: data)
    }
}

private struct WidgetOverview: Decodable {
    let family: WidgetFamily
    let elders: [WidgetElderOverview]
}

private struct WidgetFamily: Decodable {
    let id: String
}

private struct WidgetElderOverview: Decodable {
    let elder: WidgetElder
    let todayActions: [WidgetTodayAction]
}

private struct WidgetElder: Decodable {
    let id: String
    let name: String
}

struct ElderActionData: Decodable {
    let elderId: String
    let name: String
    let todayActions: [WidgetTodayAction]
}

struct WidgetTodayAction: Decodable {
    let actionKey: String
    let title: String
    let icon: String
    let completed: Bool
}

private struct WidgetCareEventResponse: Decodable {}

struct WidgetSubscriptionStatus: Decodable {
    let tier: String
}

enum WidgetError: Error {
    case invalidURL
    case requestFailed
}

// Note: Main app writes to the same App Group keys via FamilyStore.syncWidgetSession().
