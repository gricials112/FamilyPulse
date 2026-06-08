import SwiftUI
import XCTest

@MainActor
final class ViewBodyCoverageTests: XCTestCase {
    func testReadyModeScreenBodiesBuildFromRepresentativeState() {
        let store = makeReadyStore()

        forceBuild(ContentView(store: store))
        forceBuild(FamilyWallView(store: store))
        forceBuild(AppointmentsView(store: store))
        forceBuild(SettingsView(store: store))
        forceBuild(RecordsView(store: store))

        store.userMode = .elder
        store.selectedElderId = PreviewData.momId
        forceBuild(ContentView(store: store))
        forceBuild(ElderOneTapHomeView(store: store))
    }

    func testSignedOutAndOnboardingScreenBodiesBuild() {
        let store = makeReadyStore()

        store.phase = .signedOut
        forceBuild(ContentView(store: store))
        forceBuild(LoginView(store: store))

        store.phase = .intro
        forceBuild(ContentView(store: store))
        forceBuild(IntroOnboardingView(store: store))

        store.phase = .needsFamily
        forceBuild(ContentView(store: store))
        forceBuild(FamilyOnboardingView(store: store))

        store.phase = .needsElder
        forceBuild(ContentView(store: store))
        forceBuild(ElderOnboardingView(store: store))

        store.phase = .needsElderSelection
        store.userMode = .elder
        forceBuild(ContentView(store: store))
        forceBuild(ElderIdentitySelectionView(store: store))
    }

    func testReusableViewComponentBodiesBuild() {
        forceBuild(AppBackground())
        forceBuild(GlassCard { Text("内容") })
        forceBuild(StatusPill(text: "已同步", symbolName: "checkmark.circle.fill", tint: .green))
        forceBuild(AvatarView(symbolName: "heart.circle.fill", colorName: "orange", size: 64))
    }

    private func makeReadyStore() -> FamilyStore {
        let family = ServerFamily(
            id: PreviewData.snapshot.familyId!,
            name: PreviewData.snapshot.familyName,
            inviteCode: PreviewData.snapshot.inviteCode,
            role: "ADMIN"
        )
        let store = FamilyStore()
        store.currentUser = ServerUser(
            id: UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!,
            externalId: "password:alice",
            username: "alice",
            displayName: "Alice",
            avatarSymbol: "person.crop.circle.fill",
            avatarColor: "green",
            subscriptionTier: "YEARLY"
        )
        store.families = [family]
        store.selectedFamily = family
        store.selectedElderId = PreviewData.momId
        store.snapshot = PreviewData.snapshot
        store.phase = .ready
        store.subscriptionTier = "YEARLY"
        store.canQueueOfflineActions = true
        store.syncDelaySeconds = 10
        store.maxCustomActionsPerElder = 20
        store.historyRetentionDays = -1
        store.historyDailyLimit = 30
        store.actionHistory = PreviewData.snapshot.feed
        store.statusMessage = "已同步"
        return store
    }

    private func forceBuild<V: View>(_ view: V) {
        _ = view.body
    }
}
