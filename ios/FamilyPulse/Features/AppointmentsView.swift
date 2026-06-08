import SwiftUI

struct AppointmentsView: View {
    var store: FamilyStore
    @State private var showCreateSheet = false

    private var plannedAppointments: [Appointment] {
        store.snapshot.appointments
            .filter { $0.status == .planned }
            .sorted { $0.scheduledAt < $1.scheduledAt }
    }

    private var completedAppointments: [Appointment] {
        store.snapshot.appointments
            .filter { $0.status != .planned }
            .sorted { $0.scheduledAt > $1.scheduledAt }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    heroCard

                    if plannedAppointments.isEmpty && completedAppointments.isEmpty {
                        EmptyStateCard(
                            symbolName: "calendar.badge.clock",
                            title: "还没有复查登记",
                            message: "点右上角加号，登记时间、医院科室、负责人和携带清单。"
                        )
                    } else {
                        if !plannedAppointments.isEmpty {
                            FamilySectionHeader(title: "即将复查", subtitle: "按时间排序，避免家庭沟通遗漏。", symbolName: "calendar")
                            ForEach(plannedAppointments) { appointment in
                                AppointmentCard(appointment: appointment, store: store)
                            }
                        }

                        if !completedAppointments.isEmpty {
                            FamilySectionHeader(title: "已处理", subtitle: nil, symbolName: "checkmark.seal")
                            ForEach(completedAppointments) { appointment in
                                AppointmentCard(appointment: appointment, store: store)
                            }
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 20)
            }
            .refreshable { store.refresh() }
            .navigationTitle("复查")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("登记复查")
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                NewAppointmentSheet(store: store, isPresented: $showCreateSheet)
            }
            .onAppear {
                if store.selectedElderId == nil {
                    store.selectedElderId = store.snapshot.elders.first?.id
                }
            }
        }
    }

    private var heroCard: some View {
        GlassCard(cornerRadius: 34) {
            HStack(alignment: .top, spacing: 14) {
                SoftIcon(symbolName: "calendar.badge.clock", tint: .blue, size: 52)
                VStack(alignment: .leading, spacing: 7) {
                    Text("复查看板")
                        .font(.system(.title, design: .rounded).weight(.bold))
                    Text("登记时间、负责人和携带清单。家安只做家庭提醒，不提供医疗建议。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }
}

private struct NewAppointmentSheet: View {
    var store: FamilyStore
    @Binding var isPresented: Bool
    @State private var newTitle = "内分泌科复查"
    @State private var scheduledAt = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
    @State private var hospital = "市人民医院"
    @State private var department = "内分泌科"
    @State private var assigneeId: UUID?
    @State private var checklistText = "带血糖记录\n带上次化验单\n带当前药盒"
    @State private var note = "提前一天确认是否需要空腹。"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("复查对象", selection: elderSelection) {
                        ForEach(store.snapshot.elders) { elder in
                            Text(elder.name).tag(Optional(elder.id))
                        }
                    }
                    .pickerStyle(.menu)
                    .padding()
                    .glassSurface(cornerRadius: 18, interactive: true)

                    TextField("复查标题", text: $newTitle)
                        .padding()
                        .glassSurface(cornerRadius: 18, interactive: true)

                    DatePicker("复查时间", selection: $scheduledAt, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .padding()
                        .glassSurface(cornerRadius: 18, interactive: true)

                    HStack(spacing: 10) {
                        TextField("医院", text: $hospital)
                            .padding()
                            .glassSurface(cornerRadius: 18, interactive: true)
                        TextField("科室", text: $department)
                            .padding()
                            .glassSurface(cornerRadius: 18, interactive: true)
                    }

                    Picker("负责人", selection: $assigneeId) {
                        ForEach(store.snapshot.members) { member in
                            Text(member.displayName).tag(Optional(member.id))
                        }
                    }
                    .padding()
                    .glassSurface(cornerRadius: 18, interactive: true)

                    TextField("携带清单（每行一项）", text: $checklistText, axis: .vertical)
                        .lineLimit(3...6)
                        .padding()
                        .glassSurface(cornerRadius: 18, interactive: true)

                    TextField("登记留言", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                        .padding()
                        .glassSurface(cornerRadius: 18, interactive: true)

                    Text("请只记录家庭沟通所需信息，不上传病历、处方、化验单或影像资料。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
                .padding()
            }
            .navigationTitle("登记复查")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { isPresented = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.createAppointment(
                            title: newTitle,
                            scheduledAt: scheduledAt,
                            hospital: hospital,
                            department: department,
                            assignedToUserId: assigneeId,
                            checklistText: checklistText,
                            note: note
                        )
                        isPresented = false
                    }
                    .disabled(store.isSyncing || store.snapshot.elders.isEmpty)
                }
            }
            .onAppear {
                assigneeId = assigneeId ?? store.currentUser?.id
                store.selectedElderId = store.selectedElderId ?? store.snapshot.elders.first?.id
            }
        }
        .presentationDetents([.large])
    }

    private var elderSelection: Binding<UUID?> {
        Binding {
            store.selectedElder?.id
        } set: { newValue in
            store.selectedElderId = newValue
        }
    }
}

private struct AppointmentCard: View {
    var appointment: Appointment
    var store: FamilyStore
    @State private var resultNote = "已完成复查，资料已带回。"

    var body: some View {
        GlassCard(cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    SoftIcon(symbolName: appointment.status == .done ? "checkmark.seal.fill" : "calendar.badge.clock", tint: appointment.status.color, size: 48)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(appointment.title)
                            .font(.title3.bold())
                        Text("\(appointment.elderName) · \(appointment.hospital) / \(appointment.department)")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusPill(text: appointment.status.title, symbolName: "calendar.circle.fill", tint: appointment.status.color)
                }

                VStack(alignment: .leading, spacing: 8) {
                    appointmentRow("时间", systemImage: "clock.fill", value: appointment.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                    appointmentRow("负责人", systemImage: "person.fill.checkmark", value: appointment.assigneeName)
                    appointmentRow("登记人", systemImage: "person.text.rectangle.fill", value: appointment.createdByName)
                }

                if let note = appointment.note, !note.isEmpty {
                    messageBlock(title: "登记留言", text: note)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("携带清单")
                        .font(.headline)
                    ForEach(appointment.checklist, id: \.self) { item in
                        Label(item, systemImage: "checkmark.circle")
                            .font(.callout)
                    }
                }

                if let resultNote = appointment.resultNote, !resultNote.isEmpty {
                    messageBlock(title: "完成留言", text: resultNote)
                } else if appointment.status != .done {
                    TextField("完成后留言", text: $resultNote, axis: .vertical)
                        .lineLimit(2...4)
                        .padding()
                        .glassSurface(cornerRadius: 18, interactive: true)

                    Button {
                        store.markAppointmentDone(appointment.id, resultNote: resultNote)
                    } label: {
                        Label("标记复查完成", systemImage: "checkmark.seal.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .tint(FamilyTheme.accent)
                }
            }
        }
    }

    private func appointmentRow(_ title: String, systemImage: String, value: String) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
        .font(.callout)
    }

    private func messageBlock(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(text)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassSurface(cornerRadius: 18)
    }
}

#Preview {
    AppointmentsView(store: FamilyStore())
}
