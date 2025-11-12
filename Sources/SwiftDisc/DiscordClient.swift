import Foundation

public final class DiscordClient {
    public let token: String
    private let http: HTTPClient
    private let gateway: GatewayClient

    private var eventStream: AsyncStream<DiscordEvent>!
    private var eventContinuation: AsyncStream<DiscordEvent>.Continuation!

    public let cache = Cache()

    public var events: AsyncStream<DiscordEvent> { eventStream }

    // Phase 3: Callback adapters
    public var onReady: ((ReadyEvent) async -> Void)?
    public var onMessage: ((Message) async -> Void)?
    public var onGuildCreate: ((Guild) async -> Void)?

    // Phase 3: Command framework
    public var commands: CommandRouter?
    public func useCommands(_ router: CommandRouter) { self.commands = router }

    public init(token: String, configuration: DiscordConfiguration = .init()) {
        self.token = token
        self.http = HTTPClient(token: token, configuration: configuration)
        self.gateway = GatewayClient(token: token, configuration: configuration)

        var localContinuation: AsyncStream<DiscordEvent>.Continuation!
        self.eventStream = AsyncStream<DiscordEvent> { continuation in
            continuation.onTermination = { _ in }
            localContinuation = continuation
        }
        self.eventContinuation = localContinuation
    }

    public func loginAndConnect(intents: GatewayIntents) async throws {
        try await gateway.connect(intents: intents, eventSink: { [weak self] event in
            guard let self = self else { return }
            Task { [weak self] in
                guard let self = self else { return }
                // Minimal cache updates
                switch event {
                case .ready(let info):
                    await self.cache.upsert(user: info.user)
                    if let onReady = self.onReady { await onReady(info) }
                case .messageCreate(let msg):
                    await self.cache.upsert(user: msg.author)
                    await self.cache.upsert(channel: Channel(id: msg.channel_id, type: 0, name: nil))
                    await self.cache.add(message: msg)
                    if let onMessage = self.onMessage { await onMessage(msg) }
                    if let router = self.commands { await router.handleIfCommand(message: msg, client: self) }
                case .guildCreate(let guild):
                    await self.cache.upsert(guild: guild)
                    if let onGuildCreate = self.onGuildCreate { await onGuildCreate(guild) }
                case .channelCreate(let channel), .channelUpdate(let channel):
                    await self.cache.upsert(channel: channel)
                case .channelDelete(let channel):
                    await self.cache.removeChannel(id: channel.id)
                case .interactionCreate(let interaction):
                    if let cid = interaction.channel_id {
                        await self.cache.upsert(channel: Channel(id: cid, type: 0, name: nil))
                    }
                }
                self.eventContinuation?.yield(event)
            }
        })
    }

    public func getCurrentUser() async throws -> User {
        try await http.get(path: "/users/@me")
    }

    public func sendMessage(channelId: Snowflake, content: String) async throws -> Message {
        struct Body: Encodable { let content: String }
        return try await http.post(path: "/channels/\(channelId)/messages", body: Body(content: content))
    }

    // Overload: send message with embeds
    public func sendMessage(channelId: Snowflake, content: String? = nil, embeds: [Embed]) async throws -> Message {
        struct Body: Encodable { let content: String?; let embeds: [Embed] }
        return try await http.post(path: "/channels/\(channelId)/messages", body: Body(content: content, embeds: embeds))
    }

    // Phase 3: Presence helper
    public func setPresence(status: String, activities: [PresenceUpdatePayload.Activity] = [], afk: Bool = false, since: Int? = nil) async {
        await gateway.setPresence(status: status, activities: activities, afk: afk, since: since)
    }

    // MARK: - Phase 2 REST: Channels
    public func getChannel(id: Snowflake) async throws -> Channel {
        try await http.get(path: "/channels/\(id)")
    }

    public func modifyChannelName(id: Snowflake, name: String) async throws -> Channel {
        struct Body: Encodable { let name: String }
        return try await http.patch(path: "/channels/\(id)", body: Body(name: name))
    }

    public func deleteMessage(channelId: Snowflake, messageId: Snowflake) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)")
    }

    // MARK: - Phase 2 REST: Guilds
    public func getGuild(id: Snowflake) async throws -> Guild {
        try await http.get(path: "/guilds/\(id)")
    }

    // MARK: - Phase 2 REST: Interactions
    // Minimal interaction response helper (type 4 = ChannelMessageWithSource)
    public func createInteractionResponse(interactionId: Snowflake, token: String, content: String) async throws {
        struct DataObj: Encodable { let content: String }
        struct Body: Encodable { let type: Int = 4; let data: DataObj }
        struct Ack: Decodable {}
        let body = Body(data: DataObj(content: content))
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    // Overload: interaction response with embeds
    public func createInteractionResponse(interactionId: Snowflake, token: String, content: String? = nil, embeds: [Embed]) async throws {
        struct DataObj: Encodable { let content: String?; let embeds: [Embed] }
        struct Body: Encodable { let type: Int = 4; let data: DataObj }
        struct Ack: Decodable {}
        let body = Body(data: DataObj(content: content, embeds: embeds))
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    // MARK: - Phase 4: Slash Commands (minimal)
    public struct ApplicationCommand: Codable {
        public let id: Snowflake
        public let application_id: Snowflake
        public let name: String
        public let description: String
    }

    public struct ApplicationCommandOption: Codable {
        public enum ApplicationCommandOptionType: Int, Codable {
            case subCommand = 1
            case subCommandGroup = 2
            case string = 3
            case integer = 4
            case boolean = 5
            case user = 6
            case channel = 7
            case role = 8
            case mentionable = 9
            case number = 10
            case attachment = 11
        }
        public let type: ApplicationCommandOptionType
        public let name: String
        public let description: String
        public let required: Bool?
        public init(type: ApplicationCommandOptionType, name: String, description: String, required: Bool? = nil) {
            self.type = type
            self.name = name
            self.description = description
            self.required = required
        }
    }

    public struct ApplicationCommandCreate: Encodable {
        public let name: String
        public let description: String
        public let options: [ApplicationCommandOption]?
        public init(name: String, description: String, options: [ApplicationCommandOption]? = nil) {
            self.name = name
            self.description = description
            self.options = options
        }
    }

    public func createGlobalCommand(name: String, description: String) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable { let name: String; let description: String }
        return try await http.post(path: "/applications/\(appId)/commands", body: Body(name: name, description: description))
    }

    public func createGuildCommand(guildId: Snowflake, name: String, description: String) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable { let name: String; let description: String }
        return try await http.post(path: "/applications/\(appId)/guilds/\(guildId)/commands", body: Body(name: name, description: description))
    }

    public func createGlobalCommand(name: String, description: String, options: [ApplicationCommandOption]) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable { let name: String; let description: String; let options: [ApplicationCommandOption] }
        return try await http.post(path: "/applications/\(appId)/commands", body: Body(name: name, description: description, options: options))
    }

    public func createGuildCommand(guildId: Snowflake, name: String, description: String, options: [ApplicationCommandOption]) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        struct Body: Encodable { let name: String; let description: String; let options: [ApplicationCommandOption] }
        return try await http.post(path: "/applications/\(appId)/guilds/\(guildId)/commands", body: Body(name: name, description: description, options: options))
    }

    public func listGlobalCommands() async throws -> [ApplicationCommand] {
        let appId = try await getCurrentUser().id
        return try await http.get(path: "/applications/\(appId)/commands")
    }

    public func listGuildCommands(guildId: Snowflake) async throws -> [ApplicationCommand] {
        let appId = try await getCurrentUser().id
        return try await http.get(path: "/applications/\(appId)/guilds/\(guildId)/commands")
    }

    public func deleteGlobalCommand(commandId: Snowflake) async throws {
        let appId = try await getCurrentUser().id
        try await http.delete(path: "/applications/\(appId)/commands/\(commandId)")
    }

    public func deleteGuildCommand(guildId: Snowflake, commandId: Snowflake) async throws {
        let appId = try await getCurrentUser().id
        try await http.delete(path: "/applications/\(appId)/guilds/\(guildId)/commands/\(commandId)")
    }

    public func bulkOverwriteGlobalCommands(_ commands: [ApplicationCommandCreate]) async throws -> [ApplicationCommand] {
        let appId = try await getCurrentUser().id
        return try await http.put(path: "/applications/\(appId)/commands", body: commands)
    }

    public func bulkOverwriteGuildCommands(guildId: Snowflake, _ commands: [ApplicationCommandCreate]) async throws -> [ApplicationCommand] {
        let appId = try await getCurrentUser().id
        return try await http.put(path: "/applications/\(appId)/guilds/\(guildId)/commands", body: commands)
    }

    // MARK: - Phase 2 REST: Webhooks
    public func createWebhook(channelId: Snowflake, name: String) async throws -> Webhook {
        struct Body: Encodable { let name: String }
        return try await http.post(path: "/channels/\(channelId)/webhooks", body: Body(name: name))
    }

    public func executeWebhook(webhookId: Snowflake, token: String, content: String) async throws -> Message {
        struct Body: Encodable { let content: String }
        return try await http.post(path: "/webhooks/\(webhookId)/\(token)", body: Body(content: content))
    }

    public func listChannelWebhooks(channelId: Snowflake) async throws -> [Webhook] {
        try await http.get(path: "/channels/\(channelId)/webhooks")
    }

    public func getWebhook(id: Snowflake) async throws -> Webhook {
        try await http.get(path: "/webhooks/\(id)")
    }

    public func modifyWebhook(id: Snowflake, name: String? = nil, channelId: Snowflake? = nil) async throws -> Webhook {
        struct Body: Encodable { let name: String?; let channel_id: Snowflake? }
        return try await http.patch(path: "/webhooks/\(id)", body: Body(name: name, channel_id: channelId))
    }

    public func deleteWebhook(id: Snowflake) async throws {
        try await http.delete(path: "/webhooks/\(id)")
    }
}
