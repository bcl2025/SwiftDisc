import Foundation

public struct GuildBan: Codable, Hashable {
    public let reason: String?
    public let user: User
}
