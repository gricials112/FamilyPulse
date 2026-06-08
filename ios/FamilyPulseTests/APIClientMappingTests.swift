import XCTest

final class APIClientMappingTests: XCTestCase {
    func testSubscriptionStatusDefaultsForFreeMonthlyAndYearlyPlans() throws {
        let free = try decodeStatus(#"{"tier":"FREE"}"#)
        let monthly = try decodeStatus(#"{"tier":"MONTHLY"}"#)
        let yearly = try decodeStatus(#"{"tier":"YEARLY"}"#)

        XCTAssertFalse(free.canUploadAttachments)
        XCTAssertFalse(free.canCreateMultipleFamilies)
        XCTAssertFalse(free.canQueueOfflineActions)
        XCTAssertEqual(free.syncDelaySeconds, 0)
        XCTAssertEqual(free.maxCustomActionsPerElder, 0)
        XCTAssertEqual(free.historyRetentionDays, 0)
        XCTAssertEqual(free.historyDailyLimit, 10)

        XCTAssertTrue(monthly.canCreateMultipleFamilies)
        XCTAssertTrue(monthly.canQueueOfflineActions)
        XCTAssertEqual(monthly.syncDelaySeconds, 30)
        XCTAssertEqual(monthly.maxCustomActionsPerElder, 3)
        XCTAssertEqual(monthly.historyRetentionDays, 7)

        XCTAssertEqual(yearly.syncDelaySeconds, 10)
        XCTAssertEqual(yearly.maxCustomActionsPerElder, 20)
        XCTAssertEqual(yearly.historyRetentionDays, -1)
    }

    func testFamilySnapshotMappingCoversFallbacksAndOrdering() {
        let familyId = UUID(uuidString: "99999999-9999-4999-8999-999999999999")!
        let elderId = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        let userId = UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let overview = ServerOverview(
            family: ServerFamily(id: familyId, name: "爸妈健康同步", inviteCode: "FAMILY26", role: "ADMIN"),
            members: [
                ServerMember(id: UUID(), userId: userId, displayName: "我", role: "ADMIN", avatarSymbol: nil, avatarColor: nil)
            ],
            elders: [
                ServerElderOverview(
                    elder: ServerElder(id: elderId, familyId: familyId, name: "妈妈", birthYear: 1958, notes: nil, createdAt: createdAt),
                    todayActions: [
                        ServerTodayAction(actionKey: "later", title: "后做", icon: "moon.zzz.fill", sortOrder: 20, completed: false, completedAt: createdAt, source: "UNKNOWN", eventId: nil),
                        ServerTodayAction(actionKey: "first", title: "先做", icon: "pills.fill", sortOrder: 1, completed: true, completedAt: createdAt, source: "APP", eventId: UUID())
                    ]
                )
            ],
            recentRecords: [
                ServerMedicalRecord(
                    id: UUID(),
                    familyId: familyId,
                    elderId: elderId,
                    recordType: "LAB",
                    recordDate: nil,
                    title: "血糖化验",
                    ocrText: nil,
                    fields: [ServerRecordField(name: "血糖", value: "6.1", unit: "mmol/L", confidence: 0.92)],
                    createdByUserId: userId,
                    createdAt: createdAt,
                    attachmentCount: 2
                )
            ],
            upcomingAppointments: [
                ServerAppointment(
                    id: UUID(),
                    familyId: familyId,
                    elderId: elderId,
                    title: "复查",
                    scheduledAt: createdAt,
                    hospital: nil,
                    department: nil,
                    assignedToUserId: userId,
                    checklist: ["化验单"],
                    note: nil,
                    resultNote: "完成",
                    status: "DONE",
                    createdByUserId: nil,
                    createdAt: createdAt
                ),
                ServerAppointment(
                    id: UUID(),
                    familyId: familyId,
                    elderId: UUID(),
                    title: "未知老人复查",
                    scheduledAt: createdAt,
                    hospital: "市医院",
                    department: "内分泌",
                    assignedToUserId: nil,
                    checklist: [],
                    note: "空腹",
                    resultNote: nil,
                    status: "UNKNOWN",
                    createdByUserId: userId,
                    createdAt: createdAt
                )
            ],
            feed: [
                activity(type: "CARE_ACTION", elderId: elderId, title: "已吃药"),
                activity(type: "MEDICAL_RECORD", elderId: UUID(), elderName: nil, actorDisplayName: nil, title: "上传化验单"),
                activity(type: "APPOINTMENT", elderId: elderId, title: "登记复查")
            ]
        )

        let snapshot = FamilySnapshot.from(server: overview)

        XCTAssertEqual(snapshot.familyId, familyId)
        XCTAssertEqual(snapshot.members.first?.avatarSymbol, "person.crop.circle.fill")
        XCTAssertEqual(snapshot.members.first?.avatarColor, "green")
        XCTAssertEqual(snapshot.elders.first?.subtitle, "家庭照护对象")
        XCTAssertEqual(snapshot.elders.first?.actions.map(\.actionKey), ["first", "later"])
        XCTAssertEqual(snapshot.elders.first?.actions.first?.source, .app)
        XCTAssertNil(snapshot.elders.first?.actions.last?.completedAt)
        XCTAssertNil(snapshot.elders.first?.actions.last?.source)
        XCTAssertEqual(snapshot.feed.map(\.symbolName), ["heart.text.square.fill", "doc.text.viewfinder", "calendar.badge.clock"])
        XCTAssertEqual(snapshot.feed.map(\.tone), [.success, .calm, .calm])
        XCTAssertEqual(snapshot.feed[1].elderName, "照护对象")
        XCTAssertEqual(snapshot.feed[1].actorDisplayName, "家庭成员")
        XCTAssertTrue(snapshot.records.first?.hasAttachments == true)
        XCTAssertEqual(snapshot.records.first?.fields.first?.unit, "mmol/L")
        XCTAssertEqual(snapshot.appointments.first?.hospital, "未填写医院")
        XCTAssertEqual(snapshot.appointments.first?.department, "未填写科室")
        XCTAssertEqual(snapshot.appointments.first?.assigneeName, "我")
        XCTAssertEqual(snapshot.appointments.first?.createdByName, "家庭成员")
        XCTAssertEqual(snapshot.appointments.first?.status, .done)
        XCTAssertEqual(snapshot.appointments.last?.elderName, "照护对象")
        XCTAssertEqual(snapshot.appointments.last?.assigneeName, "未指派")
        XCTAssertEqual(snapshot.appointments.last?.createdByName, "我")
        XCTAssertEqual(snapshot.appointments.last?.status, .planned)
    }

    private func decodeStatus(_ json: String) throws -> FamilyPulseServerClient.SubscriptionStatus {
        try JSONDecoder().decode(FamilyPulseServerClient.SubscriptionStatus.self, from: Data(json.utf8))
    }

    private func activity(type: String, elderId: UUID, elderName: String? = "妈妈", actorDisplayName: String? = "我", title: String) -> ServerActivityItem {
        ServerActivityItem(
            type: type,
            entityId: UUID(),
            elderId: elderId,
            elderName: elderName,
            actorUserId: nil,
            actorDisplayName: actorDisplayName,
            actorAvatarSymbol: nil,
            actorAvatarColor: nil,
            title: title,
            subtitle: "完成",
            comment: nil,
            occurredAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }
}
