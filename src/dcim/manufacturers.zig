const std = @import("std");
const NestedTag = @import("../extras/tags.zig").NestedTag;

pub const NestedManufacturer = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    name: []const u8,
    slug: []const u8,
};

pub const Manufacturer = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    name: []const u8,
    slug: []const u8,
    description: []const u8,
    tags: []NestedTag,
    custom_fields: std.json.Value,
    created: ?[]const u8,
    last_updated: ?[]const u8,
    devicetype_count: u64,
    inventoryitem_count: u64,
    platform_count: u64,

    pub const path = "dcim/manufacturers";
};

const DCIM = @import("../dcim.zig");
const Adapter = @import("../api/adapter.zig").Adapter;

pub fn manufacturers(self: DCIM) Adapter(Manufacturer) {
    return .{
        .api = self.api,
    };
}
