import Foundation

public struct Template: Codable, Hashable {
    public struct TemplateGuild: Codable, Hashable { public let id: Snowflake?; public let name: String? }
    public let code: String
    public let name: String
    public let description: String?
    public let usage_count: Int
    public let creator_id: Snowflake
    public let created_at: String
    public let updated_at: String
    public let source_guild_id: Snowflake
    public let serialized_source_guild: TemplateGuild?
    public let is_dirty: Bool?
}
