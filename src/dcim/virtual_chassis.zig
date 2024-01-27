const NestedDevice = @import("devices.zig").NestedDevice;

pub const NestedVirtualChassis = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    name: []const u8,
    master: NestedDevice,
};
