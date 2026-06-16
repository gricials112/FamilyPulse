import Foundation

// MARK: - 微信登录错误

enum WeChatLoginError: Error, LocalizedError {
    case notInstalled
    case sendFailed
    case authCancelled
    case authDenied
    case authFailed(Int32, String?)
    case sdkNotAvailable

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "微信未安装，请先安装微信"
        case .sendFailed:
            return "无法拉起微信，请稍后重试"
        case .authCancelled:
            return "微信授权已取消"
        case .authDenied:
            return "微信授权被拒绝"
        case .authFailed(_, let msg):
            return msg ?? "微信授权失败，请稍后重试"
        case .sdkNotAvailable:
            return "微信 SDK 未集成"
        }
    }
}

// MARK: - 微信服务

#if canImport(WechatOpenSDK)
import WechatOpenSDK

@MainActor
final class WeChatService: NSObject, WXApiDelegate {
    static let shared = WeChatService()

    private var authContinuation: CheckedContinuation<String, Error>?

    private override init() {
        super.init()
    }

    func register() {
        let ret = WXApi.registerApp(
            AppConfiguration.wechatAppID,
            universalLink: AppConfiguration.wechatUniversalLink
        )
        print("[WeChat] registerApp result: \(ret)")
    }

    var isWXAppInstalled: Bool {
        // WXApi.isWXAppInstalled() 在 iOS 14+ 可能因 LSApplicationQueriesSchemes 限制误判，
        // 额外用 canOpenURL 做备用检测。
        if WXApi.isWXAppInstalled() { return true }
        guard let url = URL(string: "weixin://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    func sendAuthRequest() async throws -> String {
        guard isWXAppInstalled else {
            throw WeChatLoginError.notInstalled
        }

        let state = UUID().uuidString

        let req = SendAuthReq()
        req.scope = "snsapi_userinfo"
        req.state = state

        let sent = await WXApi.send(req)
        guard sent else {
            throw WeChatLoginError.sendFailed
        }

        return try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask { [self] in
                try await withCheckedThrowingContinuation { continuation in
                    MainActor.assumeIsolated {
                        self.authContinuation = continuation
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: 30_000_000_000)
                throw WeChatLoginError.authFailed(-1, "微信授权超时，请重试")
            }
            defer { authContinuation = nil }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }

    func handleOpenURL(_ url: URL) -> Bool {
        WXApi.handleOpen(url, delegate: self)
    }

    func handleUniversalLink(_ userActivity: NSUserActivity) -> Bool {
        WXApi.handleOpenUniversalLink(userActivity, delegate: self)
    }

    nonisolated func onResp(_ resp: BaseResp) {
        Task { @MainActor in
            handleResp(resp)
        }
    }

    private func handleResp(_ resp: BaseResp) {
        guard let authResp = resp as? SendAuthResp else { return }

        // 防止多次回调（URL Scheme + Universal Link 同时触发）导致 continuation 重复恢复
        guard let continuation = authContinuation else { return }
        authContinuation = nil

        if authResp.errCode == WXSuccess.rawValue {
            guard let code = authResp.code, !code.isEmpty else {
                continuation.resume(throwing: WeChatLoginError.authFailed(authResp.errCode, "未获取到授权码"))
                return
            }
            continuation.resume(returning: code)
        } else {
            switch authResp.errCode {
            case WXErrCodeAuthDeny.rawValue:
                continuation.resume(throwing: WeChatLoginError.authDenied)
            case WXErrCodeUserCancel.rawValue:
                continuation.resume(throwing: WeChatLoginError.authCancelled)
            default:
                continuation.resume(throwing: WeChatLoginError.authFailed(authResp.errCode, authResp.errStr))
            }
        }
    }
}

#else

@MainActor
final class WeChatService {
    static let shared = WeChatService()

    func register() {}

    var isWXAppInstalled: Bool { false }

    func sendAuthRequest() async throws -> String {
        throw WeChatLoginError.sdkNotAvailable
    }

    func handleOpenURL(_ url: URL) -> Bool { false }

    func handleUniversalLink(_ userActivity: NSUserActivity) -> Bool { false }
}

#endif
