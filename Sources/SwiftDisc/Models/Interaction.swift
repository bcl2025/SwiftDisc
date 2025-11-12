import Foundation

public struct Interaction: Codable, Hashable {
    public let id: Snowflake
    public let application_id: Snowflake
    public let type: Int
    public let token: String
    public let channel_id: Snowflake?
    public let guild_id: Snowflake?

    public struct ApplicationCommandData: Codable, Hashable {
        public struct Option: Codable, Hashable {
            public let name: String
            public let type: Int?
            public let value: String?
            public let options: [Option]?
        }
        public let id: Snowflake?
        public let name: String
        public let type: Int?
        public let options: [Option]?
    }
    public let data: ApplicationCommandData?
}
