pub const NestedRack = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    name: []const u8,
};

pub const RackFace = struct {
    value: []const u8,
    label: []const u8,
};
