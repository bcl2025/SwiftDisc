# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic Versioning.

## [0.5.0] - 2025-11-11

### Added
- Embeds: extended model (author, footer icon, thumbnail, image, timestamp, fields).
- Slash commands: options support; list/delete; bulk overwrite (global and guild).
- CI: macOS and Windows build/test workflow.

### Changed
- Gateway: unified URLSession WebSocket adapter across platforms (Windows path enabled).
- README: bumped to 0.5.0; expanded embeds details; documented full slash command management; Phase 4 core items updated.

### Notes
- Platform-specific optimizations remain pending.

## [0.4.0] - 2025-11-11

### Added
- Embeds support:
  - Send messages with embeds.
  - Send interaction responses with embeds (type 4 ChannelMessageWithSource).
- Minimal Slash Commands:
  - Create global and guild application commands.
  - Continue to handle interactions via existing gateway path.

### Changed
- README: Bumped to 0.4.0; documented embeds and minimal slash command creation.

### Notes
- Full slash command option schemas and typed responders are planned.
- Voice features remain pending.

## [0.3.0] - 2025-11-11

### Added
- Phase 3 high-level API foundations:
  - Callback adapters on `DiscordClient` (`onReady`, `onMessage`, `onGuildCreate`).
  - Minimal prefix command framework (`CommandRouter`) with registration and argument parsing.
  - Presence update helper bridging to Gateway presence op.
  - Intelligent caching start: bounded recent messages per channel in `Cache`.

### Changed
- Gateway: Implemented resume when `session_id` and `seq` are present; reconnect on opcode 7 and network errors.
- README: Professionalized header with buttons and badges. Roadmap updated to reflect Phase 3 progress. Version bumped to 0.3.0.
- Docs: Expanded high-level API section to include callbacks, commands, caching, and presence.

### Notes
- Slash commands support is planned; prefix commands shipped first for early adopters.

## [0.2.0] - 2025-11-11

### Added
- REST Phase 2 maturity:
  - Per-route rate limiting with automatic retries and global limit handling.
  - Retry/backoff for 429 and 5xx, with exponential backoff.
  - Detailed API error decoding (message/code) and improved HTTP error reporting.
  - New models: Guild, Interaction, Webhook.
  - Initial endpoint coverage: Channels, Guilds, Interactions, Webhooks.
- DiscordClient: Convenience REST methods for channels (get/modify, delete message), guild (get), interactions (create response), webhooks (create/execute).

### Changed
- README: Bumped version to 0.2.0 and marked Phase 2 roadmap items complete with REST details.
- Developer docs: Expanded REST section for per-route buckets, error decoding, endpoints.
- Install guide: Updated SPM version references to 0.2.0.

### Notes
- Additional REST endpoints will continue to be added; report priorities via Issues.

## [0.1.0] - 2025-11-11

### Added
- Gateway Phase 1 completion: Identify, Resume, and Reconnect logic.
- Heartbeat ACK tracking with jitter and improved backoff.
- Comprehensive intent support with clarified docs.
- Priority event coverage: READY, MESSAGE_CREATE, GUILD_CREATE, INTERACTION_CREATE.
- Initial sharding support and presence updates.

### Changed
- README updated to reflect 0.1.0 release, Phase 1 completion, and gateway notes.
- Developer docs updated to include resume/reconnect and expanded event coverage.

### Notes
- Windows WebSocket adapter remains planned if Foundation’s WebSocket is unavailable.

## [0.1.0-alpha] - 2025-11-11

### Added
- Initial Swift package scaffold with cross-platform targets (iOS, macOS, tvOS, watchOS, Windows intent).
- REST: Basic GET/POST, JSON encoding/decoding, simple rate limiter, error types.
- Models: Snowflake, User, Channel, Message.
- Gateway: Opcodes/models, intents, Identify/Heartbeat scaffolding, READY and MESSAGE_CREATE handling, AsyncSequence event stream.
- WebSocket abstraction with URLSession adapter and Windows placeholder.
- README with Quick Start, intents notes, roadmap, and reference to discord.py.
- .gitignore and SwiftDiscDocs.txt developer documentation.
- InstallGuide.txt with step-by-step installation and usage.
- Minimal in-memory cache wired to events (users/channels/guilds).
- Additional events: GUILD_CREATE, CHANNEL_CREATE/UPDATE/DELETE, INTERACTION_CREATE.
- Heartbeat ACK tracking with basic reconnect/backoff.

### Notes
- Windows WebSocket adapter to be implemented if Foundation’s WebSocket is unavailable.
