import AuthenticationServices
import AVFoundation
import SwiftUI

struct LoginView: View {
    var store: FamilyStore
    @State private var username = ""
    @State private var password = ""
    @State private var selectedMode: FamilyUserMode = .family
    @State private var showForm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                Spacer(minLength: 16)
                hero
                rolePicker
                loginCard
                privacyNotice
                Spacer(minLength: 20)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
        .alert("提示", isPresented: Binding(
            get: { store.loginError != nil },
            set: { if !$0 { store.loginError = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(store.loginError ?? "")
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            BrandMark(size: 64)
            VStack(spacing: 6) {
                Text("家安")
                    .font(.system(.largeTitle, design: .rounded).weight(.bold))
                Text("爸妈今天安心了吗？")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.top, 10)
        .accessibilityElement(children: .combine)
    }

    private var rolePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这台手机给谁使用？")
                .font(.headline)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                ForEach(FamilyUserMode.allCases.reversed()) { mode in
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                            selectedMode = mode
                        }
                    } label: {
                        LoginModeTile(mode: mode, isSelected: selectedMode == mode)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(mode == .elder ? "elderModeButton" : "familyModeButton")
                }
            }
        }
    }

    private var loginCard: some View {
        GlassCard(cornerRadius: 32) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedMode == .family ? "进入家庭同步" : "进入一键记录")
                            .font(.title3.bold())
                        Text(selectedMode == .family ? "查看今日状态、复查和家庭成员。" : "只显示大按钮，点一下就告诉家人。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    SoftIcon(symbolName: selectedMode.symbolName)
                }

                SignInWithAppleButton(
                    onRequest: { request in
                        request.requestedScopes = [.fullName, .email]
                    },
                    onCompletion: handleAppleResult
                )
                .signInWithAppleButtonStyle(.black)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .disabled(store.isSyncing)

                if AppConfiguration.isWeChatEnabled {
                    Button {
                        performWeChatLogin(mode: selectedMode)
                    } label: {
                        LoginActionRow(
                            title: store.isSyncing ? "微信登录中..." : "微信登录",
                            subtitle: "使用微信授权进入家安",
                            symbolName: "message.fill",
                            tint: FamilyTheme.accent,
                            isLoading: store.isSyncing
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(store.isSyncing)
                    .accessibilityIdentifier("wechatLoginButton")
                }

                Button {
                    store.signInAsGuest(mode: selectedMode)
                } label: {
                    LoginActionRow(
                        title: store.isSyncing ? "准备演示中..." : "体验演示",
                        subtitle: "无需密码，先看看完整流程",
                        symbolName: "play.circle.fill",
                        tint: .blue,
                        isLoading: store.isSyncing
                    )
                }
                .buttonStyle(.plain)
                .disabled(store.isSyncing)
                .accessibilityIdentifier("guestLoginButton")

                DisclosureGroup(isExpanded: $showForm) {
                    formContent
                        .padding(.top, 10)
                } label: {
                    Label("已有账号密码登录", systemImage: "person.text.rectangle.fill")
                        .font(.callout.weight(.semibold))
                }
                .tint(FamilyTheme.accent)
                .accessibilityIdentifier("accountLoginButton")
            }
        }
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("账号", text: $username)
                .textContentType(.username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding()
                .glassSurface(cornerRadius: 18, interactive: true)
                .accessibilityIdentifier("usernameField")

            SecureField("密码", text: $password)
                .textContentType(.password)
                .padding()
                .glassSurface(cornerRadius: 18, interactive: true)
                .accessibilityIdentifier("passwordField")

            Button {
                store.login(username: username, password: password, mode: selectedMode)
            } label: {
                Text("登录")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(FamilyTheme.accent)
            .disabled(store.isSyncing)

            Text("仅保留给已设置密码的账号和测试审核账号使用。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var privacyNotice: some View {
        VStack(spacing: 6) {
            Text("家安只用于家庭照护记录与提醒，不提供诊断、治疗或用药建议。")
            HStack(spacing: 4) {
                Text("继续即表示你同意")
                Link("隐私政策", destination: URL(string: "https://jiaan.online/privacy.html")!)
                    .foregroundStyle(.green)
                Text("与")
                Link("服务条款", destination: URL(string: "https://jiaan.online/terms.html")!)
                    .foregroundStyle(.green)
                Text("。")
            }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 10)
    }

    @MainActor
    private func performWeChatLogin(mode: FamilyUserMode) {
        guard !store.isSyncing else { return }
        Task {
            do {
                let code = try await WeChatService.shared.sendAuthRequest()
                store.signInWithWeChat(code: code, mode: mode)
            } catch WeChatLoginError.notInstalled {
                store.loginError = String(localized: "微信未安装，请先安装微信")
            } catch WeChatLoginError.authCancelled {
                // 用户取消，不提示
            } catch {
                store.loginError = error.localizedDescription
            }
        }
    }

    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) {
        guard case .success(let authorization) = result else {
            if case .failure(let error) = result {
                print("[AppleLogin] Authorization failed: \(error) (code: \((error as NSError).code))")
                if let authError = error as? ASAuthorizationError, authError.code == .canceled {
                    store.loginError = String(localized: "Apple 授权已取消（如果弹窗闪退，请在 Apple Developer Portal 开启 Sign In with Apple）")
                } else {
                    store.loginError = String(localized: "Apple 授权失败: \(error.localizedDescription)")
                }
            }
            return
        }
        print("[AppleLogin] Authorization succeeded")

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            print("[AppleLogin] credential is not ASAuthorizationAppleIDCredential")
            store.loginError = String(localized: "Apple 登录失败")
            return
        }

        guard let tokenData = credential.identityToken else {
            print("[AppleLogin] identityToken is nil (need to sign into iCloud on simulator)")
            store.loginError = String(localized: "Apple 登录失败（模拟器需要登录 iCloud）")
            return
        }

        guard let token = String(data: tokenData, encoding: .utf8) else {
            print("[AppleLogin] identityToken could not be decoded as UTF-8")
            store.loginError = String(localized: "Apple 登录失败")
            return
        }

        print("[AppleLogin] identityToken obtained, length: \(token.count)")
        let components = [credential.fullName?.familyName, credential.fullName?.givenName]
            .compactMap { $0 }
            .joined()
        store.signInWithApple(identityToken: token, displayName: components.isEmpty ? nil : components, mode: selectedMode)
    }
}

private struct LoginModeTile: View {
    var mode: FamilyUserMode
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SoftIcon(symbolName: mode.symbolName, tint: isSelected ? FamilyTheme.accent : .secondary, size: 42)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? FamilyTheme.accent : .secondary)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(mode == .family ? "给家人" : "给老人")
                    .font(.headline)
                Text(mode == .family ? "看今日安心" : "一键记录")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .padding(16)
        .glassSurface(cornerRadius: 24, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(isSelected ? FamilyTheme.accent.opacity(0.35) : .clear, lineWidth: 1.5)
        }
    }
}

private struct LoginActionRow: View {
    var title: String
    var subtitle: String
    var symbolName: String
    var tint: Color
    var isLoading: Bool

    var body: some View {
        HStack(spacing: 12) {
            SoftIcon(symbolName: symbolName, tint: tint, size: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isLoading {
                ProgressView()
            } else {
                Image(systemName: "chevron.right")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .glassSurface(cornerRadius: 22, interactive: true)
    }
}

struct FamilyOnboardingView: View {
    var store: FamilyStore
    @Environment(\.dismiss) private var dismiss
    @State private var familyName = ""
    @State private var inviteCode = ""
    @State private var showQRScanner = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("选择家庭")
                        .font(.largeTitle.bold())
                        .padding(.horizontal, 4)

                    GlassCard(cornerRadius: 28) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("创建新家庭")
                                .font(.title3.bold())
                            TextField("家庭名称", text: $familyName)
                                .padding()
                                .glassSurface(cornerRadius: 18, interactive: true)
                            Button {
                                store.createFamily(name: familyName)
                            } label: {
                                Label("创建家庭", systemImage: "person.2.badge.plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.green)
                            .disabled(store.isSyncing)
                        }
                    }

                    GlassCard(cornerRadius: 28) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("加入已有家庭")
                                .font(.title3.bold())
                            HStack(spacing: 10) {
                                TextField("邀请码", text: $inviteCode)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .padding()
                                    .glassSurface(cornerRadius: 18, interactive: true)
                                Button {
                                    showQRScanner = true
                                } label: {
                                    Image(systemName: "qrcode.viewfinder")
                                        .font(.title2)
                                }
                                .buttonStyle(.bordered)
                            }
                            Button {
                                store.joinFamily(inviteCode: inviteCode)
                            } label: {
                                Label("加入家庭", systemImage: "person.2.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .disabled(store.isSyncing)
                        }
                    }
                }
                .padding(18)
            }
        }
        .alert("提示", isPresented: Binding(
            get: { store.familyError != nil },
            set: { if !$0 { store.familyError = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(store.familyError ?? "")
        }
        .sheet(isPresented: $showQRScanner) {
            QRCodeScannerView { scanned in
                let code = parseQRCodeUrl(scanned) ?? scanned
                inviteCode = code
                showQRScanner = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    store.joinFamily(inviteCode: code)
                }
            }
        }
        .onChange(of: store.isSyncing) { wasSyncing, isSyncing in
            if wasSyncing && !isSyncing && store.selectedFamily != nil && store.familyError == nil {
                dismiss()
            }
        }
    }
}

struct ElderIdentitySelectionView: View {
    var store: FamilyStore
    @State private var elderName = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("选择本人")
                        .font(.largeTitle.bold())
                        .padding(.horizontal, 4)

                    GlassCard(cornerRadius: 28) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(store.selectedFamily?.name ?? "当前家庭")
                                .font(.title2.bold())
                            Text("选择当前使用手机的老人。选择后会进入一键记录界面。")
                                .font(.callout)
                                .foregroundStyle(.secondary)

                            ForEach(store.snapshot.elders) { elder in
                                Button {
                                    store.selectElderIdentity(elder.id)
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "figure.wave")
                                            .font(.title3)
                                            .foregroundStyle(.green)
                                            .frame(width: 30)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(elder.name)
                                                .font(.headline)
                                            Text(elder.subtitle)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.footnote.weight(.bold))
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(14)
                                    .glassSurface(cornerRadius: 20, interactive: true)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("selectElder-\(elder.name)")
                            }
                        }
                    }

                    GlassCard(cornerRadius: 28) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("没有我的名字")
                                .font(.title3.bold())
                            TextField("老人姓名", text: $elderName)
                                .padding()
                                .glassSurface(cornerRadius: 18, interactive: true)
                            TextField("慢病或备注（可选）", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .padding()
                                .glassSurface(cornerRadius: 18, interactive: true)
                            Button {
                                store.addElder(name: elderName, notes: notes.isEmpty ? nil : notes)
                            } label: {
                                Label("添加并选择", systemImage: "person.badge.plus")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.green)
                        }
                    }

                    Button {
                        store.switchMode(.family)
                    } label: {
                        Label("我是其他家人", systemImage: "person.2.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(18)
            }
        }
        .alert("提示", isPresented: Binding(
            get: { store.familyError != nil },
            set: { if !$0 { store.familyError = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(store.familyError ?? "")
        }
    }
}

struct DisplayNameSetupView: View {
    var store: FamilyStore
    @State private var displayName = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 10) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("设置你的名字")
                        .font(.largeTitle.bold())
                    Text("为了方便家人识别，请输入你的称呼。")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                GlassCard(cornerRadius: 28) {
                    VStack(spacing: 14) {
                        TextField("请输入你的名字", text: $displayName)
                            .textContentType(.name)
                            .padding()
                            .glassSurface(cornerRadius: 18, interactive: true)
                            .onSubmit { submit() }

                        Button(action: submit) {
                            Label("继续", systemImage: "arrow.right")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(.green)
                        .disabled(store.isSyncing)
                    }
                }
                .padding(.horizontal, 28)

                Spacer()
            }
            .padding(.vertical, 40)
        }
    }

    private func submit() {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.setupDisplayName(trimmed)
    }
}

struct ElderOnboardingView: View {
    var store: FamilyStore
    @State private var elderName = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("添加照护对象")
                        .font(.largeTitle.bold())
                        .padding(.horizontal, 4)

                    GlassCard(cornerRadius: 28) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text(store.selectedFamily?.name ?? "当前家庭")
                                .font(.title2.bold())
                            Text("一个家庭可以添加多位老人, 同步墙会按老人分别展示照护状态。")
                                .font(.callout)
                                .foregroundStyle(.secondary)

                            TextField("老人姓名", text: $elderName)
                                .padding()
                                .glassSurface(cornerRadius: 18, interactive: true)

                            TextField("慢病或备注（可选）", text: $notes, axis: .vertical)
                                .lineLimit(2...4)
                                .padding()
                                .glassSurface(cornerRadius: 18, interactive: true)

                            Button {
                                store.addElder(name: elderName, notes: notes.isEmpty ? nil : notes)
                            } label: {
                                Label("添加并进入家庭", systemImage: "figure.2.and.child.holdinghands")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .tint(.green)
                            .disabled(store.isSyncing)
                        }
                    }

                    GlassCard(cornerRadius: 28) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("暂不添加")
                                .font(.title3.bold())
                            Text("之后在设置页面可随时添加老人。")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Button {
                                store.skipElderOnboarding()
                            } label: {
                                Label("先跳过", systemImage: "forward.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }
                    }
                }
                .padding(18)
            }
        }
        .alert("提示", isPresented: Binding(
            get: { store.familyError != nil },
            set: { if !$0 { store.familyError = nil } }
        )) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(store.familyError ?? "")
        }
    }
}

#Preview("Login") {
    LoginView(store: FamilyStore())
}
