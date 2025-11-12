import Foundation

public struct Channel: Codable, Hashable {
    public let id: Snowflake
    public let type: Int
    public let name: String?
    public let topic: String?
    public let nsfw: Bool?
    public let position: Int?
    public let parent_id: Snowflake?
}
