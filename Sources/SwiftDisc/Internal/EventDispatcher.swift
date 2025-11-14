import Foundation

actor EventDispatcher {
    func process(event: DiscordEvent, client: DiscordClient) async {
        switch event {
        case .ready(let info):
            await client.cache.upsert(user: info.user)
            await client._internalSetCurrentUserId(info.user.id)
            if let onReady = client.onReady { await onReady(info) }
        case .messageCreate(let msg):
            await client.cache.upsert(user: msg.author)
            await client.cache.upsert(channel: Channel(id: msg.channel_id, type: 0, name: nil, topic: nil, nsfw: nil, position: nil, parent_id: nil))
            await client.cache.add(message: msg)
            if let onMessage = client.onMessage { await onMessage(msg) }
            if let router = client.commands { await router.handleIfCommand(message: msg, client: client) }
        case .messageUpdate(let msg):
            await client.cache.upsert(user: msg.author)
            await client.cache.add(message: msg)
            if let cb = client.onMessageUpdate { await cb(msg) }
        case .messageDelete(let del):
            await client.cache.removeMessage(id: del.id)
            if let cb = client.onMessageDelete { await cb(del) }
        case .messageReactionAdd(let ev):
            if let cb = client.onReactionAdd { await cb(ev) }
        case .messageReactionRemove(let ev):
            if let cb = client.onReactionRemove { await cb(ev) }
        case .messageReactionRemoveAll(let ev):
            if let cb = client.onReactionRemoveAll { await cb(ev) }
        case .messageReactionRemoveEmoji(let ev):
            if let cb = client.onReactionRemoveEmoji { await cb(ev) }
        case .guildCreate(let guild):
            await client.cache.upsert(guild: guild)
            if let onGuildCreate = client.onGuildCreate { await onGuildCreate(guild) }
        case .channelCreate(let channel), .channelUpdate(let channel):
            await client.cache.upsert(channel: channel)
        case .channelDelete(let channel):
            await client.cache.removeChannel(id: channel.id)
        case .interactionCreate(let interaction):
            if let cid = interaction.channel_id {
                await client.cache.upsert(channel: Channel(id: cid, type: 0, name: nil, topic: nil, nsfw: nil, position: nil, parent_id: nil))
            }
            if interaction.type == 4, let ac = client.autocomplete {
                await ac.handle(interaction: interaction, client: client)
            } else if let s = client.slashCommands {
                await s.handle(interaction: interaction, client: client)
            }
        case .voiceStateUpdate(let state):
            await client._internalOnVoiceStateUpdate(state)
        case .voiceServerUpdate(let vsu):
            await client._internalOnVoiceServerUpdate(vsu)
        }
        client.eventContinuation?.yield(event)
    }
}
