const std = @import("std");

const API = @import("../api.zig");

const NestedCluster = @import("../virtualization/clusters.zig").NestedCluster;
const NestedConfigTemplate = @import("../extras/config_templates.zig").NestedConfigTemplate;
const NestedDeviceRole = @import("device_roles.zig").NestedDeviceRole;
const NestedDeviceType = @import("device_types.zig").NestedDeviceType;
const NestedIPAddress = @import("../ipam/ip_addresses.zig").NestedIPAddress;
const NestedLocation = @import("locations.zig").NestedLocation;
const NestedPlatform = @import("platforms.zig").NestedPlatform;
const NestedRack = @import("racks.zig").NestedRack;
const NestedSite = @import("sites.zig").NestedSite;
const NestedTag = @import("../extras/tags.zig").NestedTag;
const NestedTenant = @import("tenants.zig").NestedTenant;
const NestedVirtualChassis = @import("virtual_chassis.zig").NestedVirtualChassis;
const RackFace = @import("racks.zig").RackFace;

pub const Status = struct {
    value: []const u8,
    label: []const u8,
};

pub const Airflow = struct {
    value: []const u8,
    label: []const u8,
};

pub const NestedDevice = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    name: ?[]const u8 = null,
};

test "nested_device" {
    const data: []const u8 =
        \\{
        \\  "id": 8,
        \\  "url": "https://demo.netbox.dev/api/dcim/devices/8/",
        \\  "display": "router-1",
        \\  "name": "router-1"
        \\}
    ;
    const parsed = try std.json.parseFromSlice(
        NestedDevice,
        std.testing.allocator,
        data,
        .{},
    );
    defer parsed.deinit();
    try std.testing.expect(parsed.value.id == 8);
    try std.testing.expect(std.mem.eql(u8, parsed.value.url, "https://demo.netbox.dev/api/dcim/devices/8/"));
    try std.testing.expect(std.mem.eql(u8, parsed.value.display, "router-1"));
    try std.testing.expect(std.mem.eql(u8, parsed.value.name.?, "router-1"));
}

pub const Device = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    name: ?[]const u8 = null,
    device_type: NestedDeviceType,
    role: NestedDeviceRole,
    device_role: NestedDeviceRole,
    tenant: ?NestedTenant = null,
    platform: ?NestedPlatform = null,
    serial: []const u8,
    asset_tag: ?[]const u8 = null,
    site: NestedSite,
    location: ?NestedLocation = null,
    rack: ?NestedRack,
    position: ?f64 = null,
    face: ?RackFace = null,
    latitude: ?f64 = null,
    longitude: ?f64 = null,
    parent_device: ?NestedDevice = null,
    status: Status,
    airflow: ?Airflow = null,
    primary_ip: ?NestedIPAddress = null,
    primary_ip4: ?NestedIPAddress = null,
    primary_ip6: ?NestedIPAddress = null,
    oob_ip: ?NestedIPAddress = null,
    cluster: ?NestedCluster = null,
    virtual_chassis: ?NestedVirtualChassis = null,
    vc_position: ?u8,
    vc_priority: ?u8,
    description: []const u8,
    comments: []const u8,
    config_template: ?NestedConfigTemplate = null,
    config_context: std.json.Value,
    local_context_data: ?std.json.Value = null,
    tags: []NestedTag,
    custom_fields: std.json.Value,
    created: []const u8,
    last_updated: []const u8,
    console_port_count: u64,
    console_server_port_count: u64,
    power_port_count: u64,
    power_outlet_count: u64,
    interface_count: u64,
    front_port_count: u64,
    rear_port_count: u64,
    device_bay_count: u64,
    module_bay_count: u64,
    inventory_item_count: u64,

    pub const path = "dcim/devices";
};

const testdata = .{
    .device = @embedFile("../testdata/device.json"),
};

test "device" {
    const parsed = try std.json.parseFromSlice(
        Device,
        std.testing.allocator,
        testdata.device,
        .{
            .ignore_unknown_fields = true,
        },
    );
    defer parsed.deinit();
    try std.testing.expect(parsed.value.id == 14);
    try std.testing.expect(std.mem.eql(u8, parsed.value.url, "https://demo.netbox.dev/api/dcim/devices/14/"));
    try std.testing.expect(std.mem.eql(u8, parsed.value.display, "dmi01-akron-sw01"));
    try std.testing.expect(std.mem.eql(u8, parsed.value.name.?, "dmi01-akron-sw01"));
    try std.testing.expect(parsed.value.device_type.manufacturer.id == 3);
    try std.testing.expect(parsed.value.asset_tag == null);
    try std.testing.expect(parsed.value.site.id == 2);
    try std.testing.expect(parsed.value.rack.?.id == 1);
    try std.testing.expect(std.mem.eql(u8, parsed.value.face.?.value, "front"));
}

const DCIM = @import("../dcim.zig").DCIM;
const GetResult = @import("../api/get.zig").GetResult;
const ListIterator = @import("../api/list.zig").ListIterator;
const ListOptions = @import("../api/list.zig").ListOptions;

pub const DEVICES = struct {
    api: *API,

    pub fn get(self: DEVICES, id: u64) !GetResult(Device) {
        return try self.api.get(Device, id);
    }

    pub fn list(self: DEVICES, options: ListOptions) !ListIterator(Device) {
        return try self.api.list(Device, options);
    }
};

pub fn devices(self: DCIM) DEVICES {
    return .{
        .api = self.api,
    };
}
