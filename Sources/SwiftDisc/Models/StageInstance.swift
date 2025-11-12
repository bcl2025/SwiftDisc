import Foundation

public struct StageInstance: Codable, Hashable {
    public let id: Snowflake
    public let guild_id: Snowflake
    public let channel_id: Snowflake
    public let topic: String
    public let privacy_level: Int
    public let discoverable_disabled: Bool?
    public let guild_scheduled_event_id: Snowflake?
}
