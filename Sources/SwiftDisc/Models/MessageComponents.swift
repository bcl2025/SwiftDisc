import Foundation

public enum MessageComponent: Codable, Hashable {
    case actionRow(ActionRow)
    case button(Button)
    case select(SelectMenu)

    private enum Discriminator: String, Codable { case actionRow = "1", button = "2" }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let type = try c.decode(Int.self, forKey: .type)
        switch type {
        case 1: // action row
            let row = try ActionRow(from: decoder)
            self = .actionRow(row)
        case 2: // button
            let btn = try Button(from: decoder)
            self = .button(btn)
        case 3: // select menu
            let sel = try SelectMenu(from: decoder)
            self = .select(sel)
        default:
            // Fallback: attempt button
            let btn = try Button(from: decoder)
            self = .button(btn)
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .actionRow(let row): try row.encode(to: encoder)
        case .button(let btn): try btn.encode(to: encoder)
        case .select(let sel): try sel.encode(to: encoder)
        }
    }

    private enum CodingKeys: String, CodingKey { case type }

    public struct ActionRow: Codable, Hashable {
        public let type: Int = 1
        public let components: [MessageComponent]
        public init(components: [MessageComponent]) { self.components = components }
    }

    public struct Button: Codable, Hashable {
        public let type: Int = 2
        public let style: Int
        public let label: String?
        public let custom_id: String?
        public let url: String?
        public let disabled: Bool?
        public init(style: Int, label: String? = nil, custom_id: String? = nil, url: String? = nil, disabled: Bool? = nil) {
            self.style = style
            self.label = label
            self.custom_id = custom_id
            self.url = url
            self.disabled = disabled
        }
    }

    public struct SelectMenu: Codable, Hashable {
        public struct Option: Codable, Hashable {
            public let label: String
            public let value: String
            public let description: String?
            public let emoji: String?
            public let `default`: Bool?
        }
        public let type: Int = 3
        public let custom_id: String
        public let options: [Option]
        public let placeholder: String?
        public let min_values: Int?
        public let max_values: Int?
        public let disabled: Bool?
        public init(custom_id: String, options: [Option], placeholder: String? = nil, min_values: Int? = nil, max_values: Int? = nil, disabled: Bool? = nil) {
            self.custom_id = custom_id
            self.options = options
            self.placeholder = placeholder
            self.min_values = min_values
            self.max_values = max_values
            self.disabled = disabled
        }
    }
}
