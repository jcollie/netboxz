pub const NestedLocation = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    name: []const u8,
    slug: []const u8,
    _depth: u64,
};
