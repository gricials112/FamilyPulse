import XCTest

final class FamilyPulseTests: XCTestCase {

    func testFamilyUserModeMetadata() {
        XCTAssertEqual(FamilyUserMode.elder.title, "我是老人")
        XCTAssertEqual(FamilyUserMode.elder.symbolName, "hand.tap.fill")
        XCTAssertTrue(FamilyUserMode.elder.subtitle.contains("一键大按钮"))

        XCTAssertEqual(FamilyUserMode.family.title, "我是家人")
        XCTAssertEqual(FamilyUserMode.family.symbolName, "person.2.fill")
        XCTAssertTrue(FamilyUserMode.family.subtitle.contains("同步墙"))
    }

    func testCareActionCompletionReflectsCompletedAt() {
        let incomplete = CareAction(actionKey: "morning_meds", title: "已吃早药", symbolName: "pills.fill", completedAt: nil, source: nil, eventId: nil)
        let complete = CareAction(actionKey: "morning_meds", title: "已吃早药", symbolName: "pills.fill", completedAt: Date(), source: .app, eventId: UUID())

        XCTAssertFalse(incomplete.isCompleted)
        XCTAssertTrue(complete.isCompleted)
    }

    func testAppTabMetadataMatchesVisibleNavigation() {
        XCTAssertEqual(AppTab.allCases.map(\.title), ["同步墙", "复查", "设置"])
        XCTAssertEqual(AppTab.wall.symbolName, "heart.text.square.fill")
        XCTAssertEqual(AppTab.appointments.symbolName, "calendar.badge.clock")
        XCTAssertEqual(AppTab.settings.symbolName, "gearshape.fill")
    }

    func testPreviewSnapshotContainsCoreDemoState() {
        let snapshot = PreviewData.snapshot

        XCTAssertEqual(snapshot.familyName, "爸妈健康同步")
        XCTAssertEqual(snapshot.inviteCode, "FAMILY26")
        XCTAssertEqual(snapshot.members.count, 2)
        XCTAssertEqual(snapshot.elders.map(\.name), ["妈妈", "爸爸"])
        XCTAssertTrue(snapshot.records.isEmpty)
        XCTAssertEqual(snapshot.appointments.first?.status, .planned)
    }
}
