import Foundation

public struct DiscordConfiguration {
    public var apiBaseURL: URL
    public var apiVersion: Int
    public var gatewayBaseURL: URL
    public var maxUploadBytes: Int // per-file guardrail

    public init(apiBaseURL: URL = URL(string: "https://discord.com/api")!, apiVersion: Int = 10, gatewayBaseURL: URL = URL(string: "wss://gateway.discord.gg")!, maxUploadBytes: Int = 100 * 1024 * 1024) {
        self.apiBaseURL = apiBaseURL
        self.apiVersion = apiVersion
        self.gatewayBaseURL = gatewayBaseURL
        self.maxUploadBytes = maxUploadBytes
    }

    var restBase: URL { apiBaseURL.appendingPathComponent("v\(apiVersion)") }
}
