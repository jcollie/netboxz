const NestedL2VPN = @import("l2vpns.zig").NestedL2VPN;

pub const NestedL2VPNTermination = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    l2vpn: NestedL2VPN,
};
