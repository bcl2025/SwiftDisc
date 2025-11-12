import Foundation

public struct GuildScheduledEventUser: Codable, Hashable {
    public let guild_scheduled_event_id: Snowflake
    public let user: User
    public let member: GuildMember?
}
