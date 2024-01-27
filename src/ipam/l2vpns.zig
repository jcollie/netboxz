pub const NestedL2VPN = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    identifier: ?i64,
    name: []const u8,
    slug: []const u8,
    type: struct {
        value: []const u8,
        label: []const u8,
    },
};
