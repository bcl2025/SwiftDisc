import Foundation

public struct Sticker: Codable, Hashable {
    public let id: Snowflake
    public let name: String
    public let description: String?
    public let tags: String?
    public let type: Int?
    public let format_type: Int?
    public let available: Bool?
    public let guild_id: Snowflake?
}

public struct StickerItem: Codable, Hashable {
    public let id: Snowflake
    public let name: String
    public let format_type: Int
}

public struct StickerPack: Codable, Hashable {
    public let id: Snowflake
    public let stickers: [Sticker]
    public let name: String
    public let sku_id: Snowflake?
    public let cover_sticker_id: Snowflake?
    public let description: String?
    public let banner_asset_id: Snowflake?
}
