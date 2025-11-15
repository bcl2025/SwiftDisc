import Foundation

public struct Snowflake<T>: Hashable, Codable, CustomStringConvertible, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(_ raw: String) { self.rawValue = raw }
    public init(stringLiteral value: String) { self.rawValue = value }
    public var description: String { rawValue }
}

public typealias UserID = Snowflake<User>
public typealias ChannelID = Snowflake<Channel>
public typealias MessageID = Snowflake<Message>
public typealias GuildID = Snowflake<Guild>
public typealias RoleID = Snowflake<Role>
public typealias EmojiID = Snowflake<Emoji>
public enum Application {}
public typealias ApplicationID = Snowflake<Application>
public enum AttachmentTag {}
public typealias AttachmentID = Snowflake<AttachmentTag>
public enum OverwriteTarget {}
public typealias OverwriteID = Snowflake<OverwriteTarget>
public enum InteractionTag {}
public typealias InteractionID = Snowflake<InteractionTag>
public enum ApplicationCommandTag {}
public typealias ApplicationCommandID = Snowflake<ApplicationCommandTag>

// Additional IDs
public typealias ForumTagID = Snowflake<ForumTag>
public enum GuildScheduledEventTag {}
public typealias GuildScheduledEventID = Snowflake<GuildScheduledEventTag>
