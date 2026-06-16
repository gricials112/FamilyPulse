import Foundation

enum AppConfiguration {
    #if DEBUG
//    static let apiBaseURL = URL(string: "http://127.0.0.1:8081")!
    static let apiBaseURL = URL(string: "https://jiaan.online")!
    #else
    static let apiBaseURL = URL(string: "https://jiaan.online")!
    #endif

    // MARK: - 微信登录配置
    // 请在微信开放平台 (https://open.weixin.qq.com) 申请后填写

    /// 微信开放平台 AppID
    static let wechatAppID = "wx2566b5d6902fd8be"

    /// Universal Link (需在微信开放平台配置，并与 Associated Domain 一致)
    static let wechatUniversalLink = "https://jiaan.online/wechat/"

    /// 是否启用微信登录功能（审核版本设为 false，提审前关闭）
    static let isWeChatEnabled = true
}

enum AppRuntime {
    static var isRunningUnitTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }
}
