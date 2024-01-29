const std = @import("std");
const NestedConfigTemplate = @import("../extras/config_templates.zig").NestedConfigTemplate;
const NestedTags = @import("../extras/tags.zig").NestedTags;

pub const NestedDeviceRole = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    name: []const u8,
    slug: []const u8,
};

pub const DeviceRole = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    name: []const u8,
    slug: []const u8,
    color: []const u8,
    vm_role: bool,
    config_template: NestedConfigTemplate,
    description: []const u8,
    tags: []NestedTags,
    custom_fields: std.json.Value,
    created: ?[]const u8,
    last_updated: ?[]const u8,
    device_count: u64,
    virtualmachine_count: u64,

    const path = "dcim/device-roles";
};

const DCIM = @import("../dcim.zig");
const Adapter = @import("../api/adapter.zig").Adapter;

pub fn devices(self: DCIM) Adapter(DeviceRole) {
    return .{
        .api = self.api,
    };
}
