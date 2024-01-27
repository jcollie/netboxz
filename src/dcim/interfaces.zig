const std = @import("std");

const NestedCable = @import("cables.zig").NestedCable;
const NestedDevice = @import("devices.zig").NestedDevice;
const NestedL2VPNTermination = @import("../ipam/l2vpn_terminations.zig").NestedL2VPNTermination;
const NestedModule = @import("modules.zig").NestedModule;
const NestedTag = @import("../extras/tags.zig").NestedTag;
const NestedVLAN = @import("../ipam/vlans.zig").NestedVLAN;
const NestedVRF = @import("../ipam/vrfs.zig").NestedVRF;
const NestedWirelessLink = @import("wireless_links.zig").NestedWirelessLink;

const Type = struct {
    value: []const u8,
    label: []const u8,
};

pub const NestedInterface = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    device: NestedDevice,
    name: []const u8,
    cable: ?u64,
    _occupied: bool,
};

test "nested_interface" {
    const data: []const u8 =
        \\ {
        \\     "id": 33,
        \\     "url": "https://demo.netbox.dev/api/dcim/interfaces/33/",
        \\     "display": "GigabitEthernet0/0/0",
        \\     "device": {
        \\         "id": 8,
        \\         "url": "https://demo.netbox.dev/api/dcim/devices/8/",
        \\         "display": "router-1",
        \\         "name": "router-1"
        \\     },
        \\     "name": "GigabitEthernet0/0/0",
        \\     "cable": null,
        \\     "_occupied": false
        \\ }
    ;
    const parsed = try std.json.parseFromSlice(
        NestedInterface,
        std.testing.allocator,
        data,
        .{},
    );
    defer parsed.deinit();
    try std.testing.expect(parsed.value.id == 33);
    try std.testing.expect(std.mem.eql(u8, parsed.value.url, "https://demo.netbox.dev/api/dcim/interfaces/33/"));
    try std.testing.expect(std.mem.eql(u8, parsed.value.display, "GigabitEthernet0/0/0"));
    try std.testing.expect(std.mem.eql(u8, parsed.value.name, "GigabitEthernet0/0/0"));
    try std.testing.expect(parsed.value.device.id == 8);
    try std.testing.expect(parsed.value._occupied == false);
}

pub const Interface = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    device: NestedDevice,
    vdcs: []u64,
    module: ?NestedModule,
    name: []const u8,
    label: []const u8,
    type: Type,
    enabled: bool,
    parent: ?NestedInterface,
    bridge: ?NestedInterface,
    lag: ?NestedInterface,
    mtu: ?u16,
    mac_address: ?[]const u8,
    speed: ?u31,
    duplex: ?struct {
        value: []const u8,
        label: []const u8,
    },
    wwn: ?[]const u8,
    mgmt_only: bool,
    description: []const u8,
    mode: ?struct {
        value: []const u8,
        label: []const u8,
    },
    rf_role: ?struct {
        value: []const u8,
        label: []const u8,
    },
    rf_channel: ?struct {
        value: []const u8,
        label: []const u8,
    },
    poe_mode: ?struct {
        value: []const u8,
        label: []const u8,
    },
    poe_type: ?struct {
        value: []const u8,
        label: []const u8,
    },
    rf_channel_frequency: ?f64,
    rf_channel_width: ?f64,
    tx_power: ?u7,
    untagged_vlan: ?NestedVLAN,
    tagged_vlans: []NestedVLAN,
    mark_connected: bool,
    cable: ?NestedCable,
    cable_end: []const u8,
    wireless_link: ?NestedWirelessLink,
    link_peers: []std.json.Value,
    wireless_lans: []u64,
    vrf: ?NestedVRF,
    l2vpn_termination: ?NestedL2VPNTermination,
    connected_endpoints: []std.json.Value,
    connected_endpoints_type: []const u8,
    connected_endpoints_reachable: bool,
    tags: []NestedTag,
    custom_fields: std.json.Value,
    created: []const u8,
    last_updated: []const u8,
    count_ipaddresses: u64,
    count_fhrp_groups: u64,
    _occupied: bool,

    pub const path = "dcim/interfaces";
};
