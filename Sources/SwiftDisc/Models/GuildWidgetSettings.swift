import Foundation

public struct GuildWidgetSettings: Codable, Hashable {
    public let enabled: Bool
    public let channel_id: Snowflake?
}
