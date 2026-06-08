import SwiftUI

struct IntroOnboardingView: View {
    var store: FamilyStore
    @State private var appeared = false
    @Environment(\.colorScheme) private var colorScheme

    private let introItems: [(symbol: String, title: String, detail: String, color: Color)] = [
        ("figure.wave", "老人模式", "进入一键大按钮界面，老人只需点一下就能记录今日状态。信息自动同步给所有家人。", .green),
        ("lock.shield.fill", "隐私边界", "只有加入家庭的成员才能访问健康资料。老人可随时查看谁在看自己的记录。", .orange),
        ("cross.case.fill", "医疗边界", "本 App 只用于家人间的照护同步与记录，不提供任何诊断或医疗建议。", .blue),
    ]

    var body: some View {
        ZStack(alignment: .bottom) {
            (colorScheme == .dark ? Color.black.opacity(0.15) : Color.black.opacity(0.35))
                .ignoresSafeArea()
                .onTapGesture { /* block taps behind cards */ }
                .animation(.easeOut(duration: 0.4).delay(0.25), value: appeared)

            VStack(spacing: 14) {
                Spacer()

                VStack(spacing: 8) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.green)
                    Text("欢迎使用家安")
                        .font(.largeTitle.bold())
                        .foregroundStyle(.primary)
                    Text("家庭健康同步从这里开始")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 30)

                ForEach(Array(introItems.enumerated()), id: \.offset) { index, item in
                    introCard(symbol: item.symbol, title: item.title, detail: item.detail, color: item.color)
                        .offset(y: appeared ? 0 : 30)
                        .opacity(appeared ? 1 : 0)
                        .animation(.easeOut(duration: 0.35).delay(0.1 * Double(index + 1)), value: appeared)
                }

                Button {
                    store.dismissIntro()
                } label: {
                    Text("开始使用")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.green, in: RoundedRectangle(cornerRadius: 22))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
                .offset(y: appeared ? 0 : 30)
                .opacity(appeared ? 1 : 0)
                .animation(.easeOut(duration: 0.35).delay(0.45), value: appeared)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 40)
        }
        .onAppear {
            appeared = true
        }
    }

    private func introCard(symbol: String, title: String, detail: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 38)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .compositingGroup()
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
        }
    }
}

#Preview {
    IntroOnboardingView(store: FamilyStore())
}
