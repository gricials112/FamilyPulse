import SwiftUI

struct RecordsView: View {
    var store: FamilyStore

    var body: some View {
        NavigationStack {
            GlassCard(cornerRadius: 28) {
                VStack(alignment: .leading, spacing: 14) {
                    Label("病历上传已移除", systemImage: "lock.shield.fill")
                        .font(.title2.bold())
                    Text("为避免采集处方、化验单、影像等敏感个人健康资料，家安不再提供病历上传、附件上传或云端病历夹功能。")
                        .foregroundStyle(.secondary)
                    Text("当前版本只保留照护状态同步、复查安排和操作历史。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .navigationTitle("隐私保护")
        }
    }
}

#Preview {
    RecordsView(store: FamilyStore())
}
