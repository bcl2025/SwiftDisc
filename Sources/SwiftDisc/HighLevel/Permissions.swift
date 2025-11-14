import Foundation

public enum PermissionsUtil {
    // Compute effective permissions for a user in a channel following Discord rules.
    // - Parameters:
    //   - userId: target user id
    //   - memberRoleIds: role IDs assigned to the member
    //   - guildRoles: all roles in the guild (include @everyone)
    //   - channel: channel with permission_overwrites
    //   - everyoneRoleId: guild ID is used as the @everyone role ID in Discord; pass that value here
    // - Returns: 64-bit bitset of permissions
    public static func effectivePermissions(userId: Snowflake,
                                            memberRoleIds: [RoleID],
                                            guildRoles: [Role],
                                            channel: Channel,
                                            everyoneRoleId: RoleID) -> UInt64 {
        func perms(_ s: String?) -> UInt64 { UInt64(s ?? "0") ?? 0 }

        // 1) Base = @everyone role perms
        let everyonePerms = perms(guildRoles.first(where: { $0.id == everyoneRoleId })?.permissions)
        var allow: UInt64 = everyonePerms

        // 2) Aggregate member roles (OR)
        let rolePerms = guildRoles.filter { memberRoleIds.contains($0.id) }.reduce(UInt64(0)) { $0 | perms($1.permissions) }
        allow |= rolePerms

        // 3) Apply channel overwrites (order is important)
        let overwrites = channel.permission_overwrites ?? []
        // 3a) @everyone overwrite
        if let everyoneOW = overwrites.first(where: { $0.type == 0 && $0.id == everyoneRoleId }) {
            let deny = perms(everyoneOW.deny)
            let add = perms(everyoneOW.allow)
            allow = (allow & ~deny) | add
        }
        // 3b) Role overwrites (all roles the member has). Collect denies and allows separately then apply: removes then adds
        let roleOW = overwrites.filter { $0.type == 0 && memberRoleIds.contains($0.id) }
        if !roleOW.isEmpty {
            let deny = roleOW.reduce(UInt64(0)) { $0 | perms($1.deny) }
            let add = roleOW.reduce(UInt64(0)) { $0 | perms($1.allow) }
            allow = (allow & ~deny) | add
        }
        // 3c) Member overwrite
        if let memberOW = overwrites.first(where: { $0.type == 1 && $0.id == userId }) {
            let deny = perms(memberOW.deny)
            let add = perms(memberOW.allow)
            allow = (allow & ~deny) | add
        }
        return allow
    }
}
