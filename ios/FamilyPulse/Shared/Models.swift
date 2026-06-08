import Foundation

struct FamilySnapshot: Equatable {
    var familyId: UUID?
    var familyName: String
    var inviteCode: String
    var members: [FamilyMember]
    var elders: [ElderStatus]
    var feed: [ActivityItem]
    var records: [MedicalRecord]
    var appointments: [Appointment]
    var lastUpdatedAt: Date
}

struct FamilyMember: Identifiable, Equatable {
    var id: UUID
    var displayName: String
    var role: String
    var avatarSymbol: String
    var avatarColor: String
}

enum FamilyUserMode: String, CaseIterable, Identifiable {
    case elder
    case family

    var id: String { rawValue }

    var title: String {
        switch self {
        case .elder: String(localized: "我是老人")
        case .family: String(localized: "我是家人")
        }
    }

    var subtitle: String {
        switch self {
        case .elder: String(localized: "进入一键大按钮, 只记录自己的今日状态")
        case .family: String(localized: "查看全家同步墙, 管理复查与操作历史")
        }
    }

    var symbolName: String {
        switch self {
        case .elder: "hand.tap.fill"
        case .family: "person.2.fill"
        }
    }
}

struct ElderStatus: Identifiable, Equatable {
    var id: UUID
    var name: String
    var subtitle: String
    var actions: [CareAction]
}

struct CareAction: Identifiable, Equatable {
    var id: String { actionKey }
    var actionKey: String
    var title: String
    var symbolName: String
    var completedAt: Date?
    var source: ActionSource?
    var eventId: UUID?

    var isCompleted: Bool {
        completedAt != nil
    }
}

enum ActionSource: String, Equatable {
    case app = "APP"
    case widget = "WIDGET"
    case caregiver = "CAREGIVER"
}

struct ActivityItem: Identifiable, Equatable {
    var id: UUID
    var title: String
    var subtitle: String
    var comment: String?
    var elderName: String
    var actorDisplayName: String
    var actorAvatarSymbol: String
    var actorAvatarColor: String
    var symbolName: String
    var occurredAt: Date
    var tone: ActivityTone
}

enum ActivityTone: Equatable {
    case calm
    case success
    case warning
}

struct MedicalRecord: Identifiable, Equatable {
    var id: UUID
    var title: String
    var recordType: String
    var recordDate: Date
    var fields: [RecordField]
    var confirmationState: String
    var hasAttachments: Bool = false
    var familyId: UUID?
    var elderId: UUID?
}

struct RecordField: Identifiable, Equatable {
    var id = UUID()
    var name: String
    var value: String
    var unit: String?
    var confidence: Double?
}

struct Appointment: Identifiable, Equatable {
    var id: UUID
    var elderId: UUID
    var elderName: String
    var title: String
    var hospital: String
    var department: String
    var scheduledAt: Date
    var assigneeName: String
    var createdByName: String
    var checklist: [String]
    var note: String?
    var resultNote: String?
    var status: AppointmentStatus
}

enum AppointmentStatus: String, Equatable {
    case planned = "PLANNED"
    case done = "DONE"
    case canceled = "CANCELED"
}

enum AppTab: String, CaseIterable, Identifiable {
    case wall
    case appointments
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .wall: String(localized: "今日")
        case .appointments: String(localized: "复查")
        case .settings: String(localized: "家庭")
        }
    }

    var symbolName: String {
        switch self {
        case .wall: "checklist.checked"
        case .appointments: "calendar.badge.clock"
        case .settings: "person.2.fill"
        }
    }
}

enum PreviewData {
    static let momId = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    static let dadId = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

    static var snapshot: FamilySnapshot {
        let now = Date()
        return FamilySnapshot(
            familyId: UUID(uuidString: "99999999-9999-4999-8999-999999999999"),
            familyName: "爸妈健康同步",
            inviteCode: "FAMILY26",
            members: [
                FamilyMember(id: UUID(uuidString: "AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA")!, displayName: "我", role: "ADMIN", avatarSymbol: "figure.2.and.child.holdinghands", avatarColor: "green"),
                FamilyMember(id: UUID(uuidString: "BBBBBBBB-BBBB-4BBB-8BBB-BBBBBBBBBBBB")!, displayName: "妹妹", role: "CAREGIVER", avatarSymbol: "person.crop.circle.fill", avatarColor: "blue")
            ],
            elders: [
                ElderStatus(
                    id: momId,
                    name: "妈妈",
                    subtitle: "高血压 / 轻微健忘",
                    actions: [
                        CareAction(actionKey: "morning_meds", title: "已吃早药", symbolName: "pills.fill", completedAt: now.addingTimeInterval(-7200), source: .app, eventId: nil),
                        CareAction(actionKey: "blood_pressure", title: "已测血压", symbolName: "heart.text.square.fill", completedAt: now.addingTimeInterval(-5400), source: .widget, eventId: nil),
                        CareAction(actionKey: "evening_meds", title: "已吃晚药", symbolName: "moon.zzz.fill", completedAt: nil, source: nil, eventId: nil)
                    ]
                ),
                ElderStatus(
                    id: dadId,
                    name: "爸爸",
                    subtitle: "糖尿病 / 需要血糖记录",
                    actions: [
                        CareAction(actionKey: "morning_meds", title: "已吃早药", symbolName: "pills.fill", completedAt: now.addingTimeInterval(-3600), source: .caregiver, eventId: nil),
                        CareAction(actionKey: "blood_pressure", title: "已测血压", symbolName: "heart.text.square.fill", completedAt: nil, source: nil, eventId: nil),
                        CareAction(actionKey: "evening_meds", title: "已吃晚药", symbolName: "moon.zzz.fill", completedAt: nil, source: nil, eventId: nil)
                    ]
                )
            ],
            feed: [
                ActivityItem(id: UUID(), title: "妈妈 已测血压", subtitle: "完成 · 我", comment: nil, elderName: "妈妈", actorDisplayName: "我", actorAvatarSymbol: "figure.2.and.child.holdinghands", actorAvatarColor: "green", symbolName: "heart.text.square.fill", occurredAt: now.addingTimeInterval(-5400), tone: .success),
                ActivityItem(id: UUID(), title: "妈妈 已吃早药", subtitle: "完成 · 妹妹", comment: nil, elderName: "妈妈", actorDisplayName: "妹妹", actorAvatarSymbol: "person.crop.circle.fill", actorAvatarColor: "blue", symbolName: "pills.fill", occurredAt: now.addingTimeInterval(-7200), tone: .success),
                ActivityItem(id: UUID(), title: "妈妈 复查登记", subtitle: "内分泌科复查 · 市人民医院/内分泌科", comment: "带血糖记录和上次化验单", elderName: "妈妈", actorDisplayName: "我", actorAvatarSymbol: "figure.2.and.child.holdinghands", actorAvatarColor: "green", symbolName: "calendar.badge.clock", occurredAt: now.addingTimeInterval(-10800), tone: .calm)
            ],
            records: [],
            appointments: [
                Appointment(
                    id: UUID(),
                    elderId: momId,
                    elderName: "妈妈",
                    title: "内分泌科复查",
                    hospital: "市人民医院",
                    department: "内分泌科",
                    scheduledAt: now.addingTimeInterval(86400 * 6),
                    assigneeName: "我",
                    createdByName: "妹妹",
                    checklist: ["带血糖记录", "带上次化验单", "带二甲双胍药盒"],
                    note: "提前一天确认空腹抽血要求",
                    resultNote: nil,
                    status: .planned
                )
            ],
            lastUpdatedAt: now
        )
    }
}
