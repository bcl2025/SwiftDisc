import Foundation

public final class DiscordClient {
    public let token: String
    private let http: HTTPClient
    private let gateway: GatewayClient
    private let dispatcher = EventDispatcher()

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

    // Phase 4+: Slash command router
    public var slashCommands: SlashCommandRouter?
    public func useSlashCommands(_ router: SlashCommandRouter) { self.slashCommands = router }

    public init(token: String, configuration: DiscordConfiguration = .init()) {
        self.token = token
        self.http = HTTPClient(token: token, configuration: configuration)
        self.gateway = GatewayClient(token: token, configuration: configuration)

        var localContinuation: AsyncStream<DiscordEvent>.Continuation!
        self.eventStream = AsyncStream<DiscordEvent> { continuation in
            continuation.onTermination = { _ in }
            localContinuation = continuation
        }

    // Guild widget settings
    public func getGuildWidgetSettings(guildId: Snowflake) async throws -> GuildWidgetSettings {
        try await http.get(path: "/guilds/\(guildId)/widget")
    }

    public func modifyGuildWidgetSettings(guildId: Snowflake, enabled: Bool, channelId: Snowflake?) async throws -> GuildWidgetSettings {
        struct Body: Encodable { let enabled: Bool; let channel_id: Snowflake? }
        return try await http.patch(path: "/guilds/\(guildId)/widget", body: Body(enabled: enabled, channel_id: channelId))
    }

    // Guild prune
    public func getGuildPruneCount(guildId: Snowflake, days: Int = 7) async throws -> Int {
        struct Resp: Decodable { let pruned: Int }
        let resp: Resp = try await http.get(path: "/guilds/\(guildId)/prune?days=\(days)")
        return resp.pruned
    }

    public func beginGuildPrune(guildId: Snowflake, days: Int = 7, computePruneCount: Bool = true) async throws -> Int {
        struct Body: Encodable { let days: Int; let compute_prune_count: Bool }
        struct Resp: Decodable { let pruned: Int }
        let resp: Resp = try await http.post(path: "/guilds/\(guildId)/prune", body: Body(days: days, compute_prune_count: computePruneCount))
        return resp.pruned
    }

    public func bulkModifyRolePositions(guildId: Snowflake, positions: [(id: Snowflake, position: Int)]) async throws -> [Role] {
        struct Entry: Encodable { let id: Snowflake; let position: Int }
        let body = positions.map { Entry(id: $0.id, position: $0.position) }
        return try await http.patch(path: "/guilds/\(guildId)/roles", body: body)
    }
        self.eventContinuation = localContinuation
    }

    public func loginAndConnect(intents: GatewayIntents) async throws {
        try await gateway.connect(intents: intents, shard: nil, eventSink: { [weak self] event in
            guard let self = self else { return }
            Task { await self.dispatcher.process(event: event, client: self) }
        })
    }

    // Sharded connect helper
    public func loginAndConnectSharded(index: Int, total: Int, intents: GatewayIntents) async throws {
        try await gateway.connect(intents: intents, shard: (index, total), eventSink: { [weak self] event in
            guard let self = self else { return }
            Task { await self.dispatcher.process(event: event, client: self) }
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

    // Overload: send message with embeds and components
    public func sendMessage(channelId: Snowflake, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil) async throws -> Message {
        struct Body: Encodable { let content: String?; let embeds: [Embed]?; let components: [MessageComponent]? }
        return try await http.post(path: "/channels/\(channelId)/messages", body: Body(content: content, embeds: embeds, components: components))
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

    // Broader channel modify helper
    public func modifyChannel(id: Snowflake, topic: String? = nil, nsfw: Bool? = nil, position: Int? = nil, parentId: Snowflake? = nil) async throws -> Channel {
        struct Body: Encodable { let topic: String?; let nsfw: Bool?; let position: Int?; let parent_id: Snowflake? }
        return try await http.patch(path: "/channels/\(id)", body: Body(topic: topic, nsfw: nsfw, position: position, parent_id: parentId))
    }

    public func deleteMessage(channelId: Snowflake, messageId: Snowflake) async throws {
        try await http.delete(path: "/channels/\(channelId)/messages/\(messageId)")
    }

    // Message retrieval
    public func getMessage(channelId: Snowflake, messageId: Snowflake) async throws -> Message {
        try await http.get(path: "/channels/\(channelId)/messages/\(messageId)")
    }

    // Message edit (content and/or embeds)
    public func editMessage(channelId: Snowflake, messageId: Snowflake, content: String? = nil, embeds: [Embed]? = nil, components: [MessageComponent]? = nil) async throws -> Message {
        struct Body: Encodable { let content: String?; let embeds: [Embed]?; let components: [MessageComponent]? }
        return try await http.patch(path: "/channels/\(channelId)/messages/\(messageId)", body: Body(content: content, embeds: embeds, components: components))
    }

    // List channel messages (simple limit)
    public func listChannelMessages(channelId: Snowflake, limit: Int = 50) async throws -> [Message] {
        try await http.get(path: "/channels/\(channelId)/messages?limit=\(limit)")
    }

    // MARK: - Phase 2 REST: Guilds
    public func getGuild(id: Snowflake) async throws -> Guild {
        try await http.get(path: "/guilds/\(id)")
    }

    public func getGuildChannels(guildId: Snowflake) async throws -> [Channel] {
        try await http.get(path: "/guilds/\(guildId)/channels")
    }

    public func getGuildMember(guildId: Snowflake, userId: Snowflake) async throws -> GuildMember {
        try await http.get(path: "/guilds/\(guildId)/members/\(userId)")
    }

    public func listGuildMembers(guildId: Snowflake, limit: Int = 1000, after: Snowflake? = nil) async throws -> [GuildMember] {
        var path = "/guilds/\(guildId)/members?limit=\(limit)"
        if let after { path += "&after=\(after)" }
        return try await http.get(path: path)
    }

    // Create/delete channels
    public func createGuildChannel(guildId: Snowflake, name: String, type: Int? = nil, topic: String? = nil, nsfw: Bool? = nil, parentId: Snowflake? = nil, position: Int? = nil) async throws -> Channel {
        struct Body: Encodable { let name: String; let type: Int?; let topic: String?; let nsfw: Bool?; let parent_id: Snowflake?; let position: Int? }
        return try await http.post(path: "/guilds/\(guildId)/channels", body: Body(name: name, type: type, topic: topic, nsfw: nsfw, parent_id: parentId, position: position))
    }

    public func deleteChannel(channelId: Snowflake) async throws {
        try await http.delete(path: "/channels/\(channelId)")
    }

    // Bulk modify channel positions (guild)
    public func bulkModifyGuildChannelPositions(guildId: Snowflake, positions: [(id: Snowflake, position: Int)]) async throws -> [Channel] {
        struct Entry: Encodable { let id: Snowflake; let position: Int }
        let body = positions.map { Entry(id: $0.id, position: $0.position) }
        return try await http.patch(path: "/guilds/\(guildId)/channels", body: body)
    }

    // Channel permission overwrites
    // type: 0 = role, 1 = member
    public func editChannelPermission(channelId: Snowflake, overwriteId: Snowflake, type: Int, allow: String? = nil, deny: String? = nil) async throws {
        struct Body: Encodable { let allow: String?; let deny: String?; let type: Int }
        let _: EmptyResponse = try await http.put(path: "/channels/\(channelId)/permissions/\(overwriteId)", body: Body(allow: allow, deny: deny, type: type))
    }

    public func deleteChannelPermission(channelId: Snowflake, overwriteId: Snowflake) async throws {
        try await http.delete(path: "/channels/\(channelId)/permissions/\(overwriteId)")
    }

    // Channel typing indicator
    public func triggerTypingIndicator(channelId: Snowflake) async throws {
        struct Empty: Encodable {}
        let _: EmptyResponse = try await http.post(path: "/channels/\(channelId)/typing", body: Empty())
    }

    // Roles
    public func listGuildRoles(guildId: Snowflake) async throws -> [Role] {
        try await http.get(path: "/guilds/\(guildId)/roles")
    }

    public func modifyRole(guildId: Snowflake, roleId: Snowflake, name: String? = nil, permissions: String? = nil, color: Int? = nil, hoist: Bool? = nil, mentionable: Bool? = nil) async throws -> Role {
        struct Body: Encodable { let name: String?; let permissions: String?; let color: Int?; let hoist: Bool?; let mentionable: Bool? }
        return try await http.patch(path: "/guilds/\(guildId)/roles/\(roleId)", body: Body(name: name, permissions: permissions, color: color, hoist: hoist, mentionable: mentionable))
    }

    public func createRole(guildId: Snowflake, name: String? = nil, permissions: String? = nil, color: Int? = nil, hoist: Bool? = nil, mentionable: Bool? = nil) async throws -> Role {
        struct Body: Encodable { let name: String?; let permissions: String?; let color: Int?; let hoist: Bool?; let mentionable: Bool? }
        return try await http.post(path: "/guilds/\(guildId)/roles", body: Body(name: name, permissions: permissions, color: color, hoist: hoist, mentionable: mentionable))
    }

    public func deleteRole(guildId: Snowflake, roleId: Snowflake) async throws {
        try await http.delete(path: "/guilds/\(guildId)/roles/\(roleId)")
    }

    // Bans
    public func listGuildBans(guildId: Snowflake) async throws -> [GuildBan] {
        try await http.get(path: "/guilds/\(guildId)/bans")
    }

    public func createGuildBan(guildId: Snowflake, userId: Snowflake, deleteMessageSeconds: Int? = nil) async throws {
        struct Empty: Encodable {}
        var path = "/guilds/\(guildId)/bans/\(userId)"
        if let s = deleteMessageSeconds { path += "?delete_message_seconds=\(s)" }
        let _: ApplicationCommand = try await http.put(path: path, body: Empty())
    }

    public func deleteGuildBan(guildId: Snowflake, userId: Snowflake) async throws {
        try await http.delete(path: "/guilds/\(guildId)/bans/\(userId)")
    }

    public func listGuildRoles(guildId: Snowflake) async throws -> [Role] {
        try await http.get(path: "/guilds/\(guildId)/roles")
    }

    public func modifyGuildMember(guildId: Snowflake, userId: Snowflake, nick: String? = nil, roles: [Snowflake]? = nil) async throws -> GuildMember {
        struct Body: Encodable { let nick: String?; let roles: [Snowflake]? }
        return try await http.patch(path: "/guilds/\(guildId)/members/\(userId)", body: Body(nick: nick, roles: roles))
    }

    // Guild settings
    public func modifyGuild(guildId: Snowflake, name: String? = nil, verificationLevel: Int? = nil, defaultMessageNotifications: Int? = nil, systemChannelId: Snowflake? = nil, explicitContentFilter: Int? = nil) async throws -> Guild {
        struct Body: Encodable {
            let name: String?
            let verification_level: Int?
            let default_message_notifications: Int?
            let system_channel_id: Snowflake?
            let explicit_content_filter: Int?
        }
        let body = Body(name: name, verification_level: verificationLevel, default_message_notifications: defaultMessageNotifications, system_channel_id: systemChannelId, explicit_content_filter: explicitContentFilter)
        return try await http.patch(path: "/guilds/\(guildId)", body: body)
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

    public enum InteractionResponseType: Int, Codable {
        case pong = 1
        case channelMessageWithSource = 4
        case deferredChannelMessageWithSource = 5
        case deferredUpdateMessage = 6
        case updateMessage = 7
    }

    public func createInteractionResponse(interactionId: Snowflake, token: String, type: InteractionResponseType, content: String? = nil, embeds: [Embed]? = nil) async throws {
        struct DataObj: Encodable { let content: String?; let embeds: [Embed]? }
        struct Body: Encodable { let type: Int; let data: DataObj? }
        struct Ack: Decodable {}
        let data = (content == nil && embeds == nil) ? nil : DataObj(content: content, embeds: embeds)
        let body = Body(type: type.rawValue, data: data)
        let _: Ack = try await http.post(path: "/interactions/\(interactionId)/\(token)/callback", body: body)
    }

    public func shutdown() async {
        await gateway.close()
        eventContinuation?.finish()
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
        public struct Choice: Codable { public let name: String; public let value: String }
        public let choices: [Choice]?
        public init(type: ApplicationCommandOptionType, name: String, description: String, required: Bool? = nil, choices: [Choice]? = nil) {
            self.type = type
            self.name = name
            self.description = description
            self.required = required
            self.choices = choices
        }
    }

    public struct ApplicationCommandCreate: Encodable {
        public let name: String
        public let description: String
        public let options: [ApplicationCommandOption]?
        public let default_member_permissions: String?
        public let dm_permission: Bool?
        public init(name: String, description: String, options: [ApplicationCommandOption]? = nil, default_member_permissions: String? = nil, dm_permission: Bool? = nil) {
            self.name = name
            self.description = description
            self.options = options
            self.default_member_permissions = default_member_permissions
            self.dm_permission = dm_permission
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

    public func createGlobalCommand(_ command: ApplicationCommandCreate) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        return try await http.post(path: "/applications/\(appId)/commands", body: command)
    }

    public func createGuildCommand(guildId: Snowflake, _ command: ApplicationCommandCreate) async throws -> ApplicationCommand {
        let appId = try await getCurrentUser().id
        return try await http.post(path: "/applications/\(appId)/guilds/\(guildId)/commands", body: command)
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

    public func createChannelInvite(channelId: Snowflake, maxAge: Int? = nil, maxUses: Int? = nil, temporary: Bool? = nil, unique: Bool? = nil) async throws -> Invite {
        struct Body: Encodable {
            let max_age: Int?
            let max_uses: Int?
            let temporary: Bool?
            let unique: Bool?
        }
        let body = Body(max_age: maxAge, max_uses: maxUses, temporary: temporary, unique: unique)
        return try await http.post(path: "/channels/\(channelId)/invites", body: body)
    }

    public func listChannelInvites(channelId: Snowflake) async throws -> [Invite] {
        try await http.get(path: "/channels/\(channelId)/invites")
    }

    public func listGuildInvites(guildId: Snowflake) async throws -> [Invite] {
        try await http.get(path: "/guilds/\(guildId)/invites")
    }

    public func getInvite(code: String, withCounts: Bool = false, withExpiration: Bool = false) async throws -> Invite {
        let path = "/invites/\(code)?with_counts=\(withCounts)&with_expiration=\(withExpiration)"
        return try await http.get(path: path)
    }

    public func deleteInvite(code: String) async throws {
        try await http.delete(path: "/invites/\(code)")
    }

    public func getTemplate(code: String) async throws -> Template {
        try await http.get(path: "/guilds/templates/\(code)")
    }

    public func listGuildTemplates(guildId: Snowflake) async throws -> [Template] {
        try await http.get(path: "/guilds/\(guildId)/templates")
    }

    public func createGuildTemplate(guildId: Snowflake, name: String, description: String? = nil) async throws -> Template {
        struct Body: Encodable { let name: String; let description: String? }
        return try await http.post(path: "/guilds/\(guildId)/templates", body: Body(name: name, description: description))
    }

    public func modifyGuildTemplate(guildId: Snowflake, code: String, name: String? = nil, description: String? = nil) async throws -> Template {
        struct Body: Encodable { let name: String?; let description: String? }
        return try await http.patch(path: "/guilds/\(guildId)/templates/\(code)", body: Body(name: name, description: description))
    }

    public func syncGuildTemplate(guildId: Snowflake, code: String) async throws -> Template {
        struct Empty: Encodable {}
        return try await http.put(path: "/guilds/\(guildId)/templates/\(code)", body: Empty())
    }

    public func deleteGuildTemplate(guildId: Snowflake, code: String) async throws {
        try await http.delete(path: "/guilds/\(guildId)/templates/\(code)")
    }

    // MARK: - REST: Stickers
    public func getSticker(id: Snowflake) async throws -> Sticker {
        try await http.get(path: "/stickers/\(id)")
    }

    public func listStickerPacks() async throws -> [StickerPack] {
        struct Packs: Decodable { let sticker_packs: [StickerPack] }
        let resp: Packs = try await http.get(path: "/sticker-packs")
        return resp.sticker_packs
    }

    public func listGuildStickers(guildId: Snowflake) async throws -> [Sticker] {
        try await http.get(path: "/guilds/\(guildId)/stickers")
    }

    public func getGuildSticker(guildId: Snowflake, stickerId: Snowflake) async throws -> Sticker {
        try await http.get(path: "/guilds/\(guildId)/stickers/\(stickerId)")
    }

    // MARK: - REST: Forum helpers
    public func createForumThread(
        channelId: Snowflake,
        name: String,
        content: String? = nil,
        embeds: [Embed]? = nil,
        components: [MessageComponent]? = nil,
        appliedTagIds: [Snowflake]? = nil,
        autoArchiveDuration: Int? = nil,
        rateLimitPerUser: Int? = nil
    ) async throws -> Channel {
        struct Msg: Encodable { let content: String?; let embeds: [Embed]?; let components: [MessageComponent]? }
        struct Body: Encodable {
            let name: String
            let auto_archive_duration: Int?
            let rate_limit_per_user: Int?
            let message: Msg?
            let applied_tags: [Snowflake]?
        }
        let message = (content == nil && embeds == nil && components == nil) ? nil : Msg(content: content, embeds: embeds, components: components)
        let body = Body(
            name: name,
            auto_archive_duration: autoArchiveDuration,
            rate_limit_per_user: rateLimitPerUser,
            message: message,
            applied_tags: appliedTagIds
        )
        return try await http.post(path: "/channels/\(channelId)/threads", body: body)
    }

    // MARK: - REST: Audit Logs
    public func getGuildAuditLog(
        guildId: Snowflake,
        userId: Snowflake? = nil,
        actionType: Int? = nil,
        before: Snowflake? = nil,
        limit: Int? = nil
    ) async throws -> AuditLog {
        var path = "/guilds/\(guildId)/audit-logs"
        var qs: [String] = []
        if let userId { qs.append("user_id=\(userId)") }
        if let actionType { qs.append("action_type=\(actionType)") }
        if let before { qs.append("before=\(before)") }
        if let limit { qs.append("limit=\(limit)") }
        if !qs.isEmpty { path += "?" + qs.joined(separator: "&") }
        return try await http.get(path: path)
    }

    // MARK: - REST: AutoModeration
    public func listAutoModerationRules(guildId: Snowflake) async throws -> [AutoModerationRule] {
        try await http.get(path: "/guilds/\(guildId)/auto-moderation/rules")
    }

    public func getAutoModerationRule(guildId: Snowflake, ruleId: Snowflake) async throws -> AutoModerationRule {
        try await http.get(path: "/guilds/\(guildId)/auto-moderation/rules/\(ruleId)")
    }

    public func createAutoModerationRule(
        guildId: Snowflake,
        name: String,
        eventType: Int,
        triggerType: Int,
        triggerMetadata: AutoModerationRule.TriggerMetadata? = nil,
        actions: [AutoModerationRule.Action],
        enabled: Bool? = nil,
        exemptRoles: [Snowflake]? = nil,
        exemptChannels: [Snowflake]? = nil
    ) async throws -> AutoModerationRule {
        struct Body: Encodable {
            let name: String
            let event_type: Int
            let trigger_type: Int
            let trigger_metadata: AutoModerationRule.TriggerMetadata?
            let actions: [AutoModerationRule.Action]
            let enabled: Bool?
            let exempt_roles: [Snowflake]?
            let exempt_channels: [Snowflake]?
        }
        let body = Body(
            name: name,
            event_type: eventType,
            trigger_type: triggerType,
            trigger_metadata: triggerMetadata,
            actions: actions,
            enabled: enabled,
            exempt_roles: exemptRoles,
            exempt_channels: exemptChannels
        )
        return try await http.post(path: "/guilds/\(guildId)/auto-moderation/rules", body: body)
    }

    public func modifyAutoModerationRule(
        guildId: Snowflake,
        ruleId: Snowflake,
        name: String? = nil,
        eventType: Int? = nil,
        triggerMetadata: AutoModerationRule.TriggerMetadata? = nil,
        actions: [AutoModerationRule.Action]? = nil,
        enabled: Bool? = nil,
        exemptRoles: [Snowflake]? = nil,
        exemptChannels: [Snowflake]? = nil
    ) async throws -> AutoModerationRule {
        struct Body: Encodable {
            let name: String?
            let event_type: Int?
            let trigger_metadata: AutoModerationRule.TriggerMetadata?
            let actions: [AutoModerationRule.Action]?
            let enabled: Bool?
            let exempt_roles: [Snowflake]?
            let exempt_channels: [Snowflake]?
        }
        let body = Body(
            name: name,
            event_type: eventType,
            trigger_metadata: triggerMetadata,
            actions: actions,
            enabled: enabled,
            exempt_roles: exemptRoles,
            exempt_channels: exemptChannels
        )
        return try await http.patch(path: "/guilds/\(guildId)/auto-moderation/rules/\(ruleId)", body: body)
    }

    public func deleteAutoModerationRule(guildId: Snowflake, ruleId: Snowflake) async throws {
        try await http.delete(path: "/guilds/\(guildId)/auto-moderation/rules/\(ruleId)")
    }

    // MARK: - REST: Scheduled Events
    public func listGuildScheduledEvents(guildId: Snowflake, withCounts: Bool = false) async throws -> [GuildScheduledEvent] {
        let suffix = withCounts ? "?with_user_count=true" : ""
        return try await http.get(path: "/guilds/\(guildId)/scheduled-events\(suffix)")
    }

    public func createGuildScheduledEvent(
        guildId: Snowflake,
        channelId: Snowflake?,
        entityType: GuildScheduledEvent.EntityType,
        name: String,
        scheduledStartTimeISO8601: String,
        scheduledEndTimeISO8601: String? = nil,
        privacyLevel: Int = 2,
        description: String? = nil,
        entityMetadata: GuildScheduledEvent.EntityMetadata? = nil
    ) async throws -> GuildScheduledEvent {
        struct Body: Encodable {
            let channel_id: Snowflake?
            let entity_type: Int
            let name: String
            let scheduled_start_time: String
            let scheduled_end_time: String?
            let privacy_level: Int
            let description: String?
            let entity_metadata: GuildScheduledEvent.EntityMetadata?
        }
        let body = Body(
            channel_id: channelId,
            entity_type: entityType.rawValue,
            name: name,
            scheduled_start_time: scheduledStartTimeISO8601,
            scheduled_end_time: scheduledEndTimeISO8601,
            privacy_level: privacyLevel,
            description: description,
            entity_metadata: entityMetadata
        )
        return try await http.post(path: "/guilds/\(guildId)/scheduled-events", body: body)
    }

    public func getGuildScheduledEvent(guildId: Snowflake, eventId: Snowflake, withCounts: Bool = false) async throws -> GuildScheduledEvent {
        let suffix = withCounts ? "?with_user_count=true" : ""
        return try await http.get(path: "/guilds/\(guildId)/scheduled-events/\(eventId)\(suffix)")
    }

    public func modifyGuildScheduledEvent(
        guildId: Snowflake,
        eventId: Snowflake,
        channelId: Snowflake? = nil,
        entityType: GuildScheduledEvent.EntityType? = nil,
        name: String? = nil,
        scheduledStartTimeISO8601: String? = nil,
        scheduledEndTimeISO8601: String? = nil,
        privacyLevel: Int? = nil,
        description: String? = nil,
        status: GuildScheduledEvent.Status? = nil,
        entityMetadata: GuildScheduledEvent.EntityMetadata? = nil
    ) async throws -> GuildScheduledEvent {
        struct Body: Encodable {
            let channel_id: Snowflake?
            let entity_type: Int?
            let name: String?
            let scheduled_start_time: String?
            let scheduled_end_time: String?
            let privacy_level: Int?
            let description: String?
            let status: Int?
            let entity_metadata: GuildScheduledEvent.EntityMetadata?
        }
        let body = Body(
            channel_id: channelId,
            entity_type: entityType?.rawValue,
            name: name,
            scheduled_start_time: scheduledStartTimeISO8601,
            scheduled_end_time: scheduledEndTimeISO8601,
            privacy_level: privacyLevel,
            description: description,
            status: status?.rawValue,
            entity_metadata: entityMetadata
        )
        return try await http.patch(path: "/guilds/\(guildId)/scheduled-events/\(eventId)", body: body)
    }

    public func deleteGuildScheduledEvent(guildId: Snowflake, eventId: Snowflake) async throws {
        try await http.delete(path: "/guilds/\(guildId)/scheduled-events/\(eventId)")
    }

    public func listGuildScheduledEventUsers(
        guildId: Snowflake,
        eventId: Snowflake,
        limit: Int? = nil,
        withMember: Bool = false,
        before: Snowflake? = nil,
        after: Snowflake? = nil
    ) async throws -> [GuildScheduledEventUser] {
        var path = "/guilds/\(guildId)/scheduled-events/\(eventId)/users"
        var qs: [String] = []
        if let limit { qs.append("limit=\(limit)") }
        if withMember { qs.append("with_member=true") }
        if let before { qs.append("before=\(before)") }
        if let after { qs.append("after=\(after)") }
        if !qs.isEmpty { path += "?" + qs.joined(separator: "&") }
        return try await http.get(path: path)
    }

    // MARK: - REST: Stage Instances
    public func createStageInstance(channelId: Snowflake, topic: String, privacyLevel: Int = 2, guildScheduledEventId: Snowflake? = nil) async throws -> StageInstance {
        struct Body: Encodable {
            let channel_id: Snowflake
            let topic: String
            let privacy_level: Int
            let guild_scheduled_event_id: Snowflake?
        }
        let body = Body(channel_id: channelId, topic: topic, privacy_level: privacyLevel, guild_scheduled_event_id: guildScheduledEventId)
        return try await http.post(path: "/stage-instances", body: body)
    }

    public func getStageInstance(channelId: Snowflake) async throws -> StageInstance {
        try await http.get(path: "/stage-instances/\(channelId)")
    }

    public func modifyStageInstance(channelId: Snowflake, topic: String? = nil, privacyLevel: Int? = nil) async throws -> StageInstance {
        struct Body: Encodable { let topic: String?; let privacy_level: Int? }
        return try await http.patch(path: "/stage-instances/\(channelId)", body: Body(topic: topic, privacy_level: privacyLevel))
    }

    public func deleteStageInstance(channelId: Snowflake) async throws {
        try await http.delete(path: "/stage-instances/\(channelId)")
    }
}
