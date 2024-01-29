const std = @import("std");

const DeviceInterface = @import("../dcim/interfaces.zig").Interface;
const NestedDeviceInterface = @import("../dcim/interfaces.zig").NestedInterface;
const NestedTags = @import("../extras/tags.zig").NestedTag;
const NestedTenant = @import("../dcim/tenants.zig").NestedTenant;
const NestedVRF = @import("vrfs.zig").NestedVRF;

const Status = struct {
    value: []const u8,
    label: []const u8,
};

const Role = struct {
    value: []const u8,
    label: []const u8,
};

pub const NestedIPAddress = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    family: u64,
    address: []const u8,
};

const Family = union(enum) {
    v4: []const u8,
    v6: []const u8,

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
        const value = try std.json.innerParse(std.json.Value, allocator, source, options);
        return @This().jsonParseFromValue(allocator, value, options);
    }

    pub fn jsonParseFromValue(_: std.mem.Allocator, source: std.json.Value, _: std.json.ParseOptions) !@This() {
        switch (source) {
            .object => |v| {
                if (v.get("value")) |value| {
                    switch (value) {
                        .integer => |version| {
                            const label = if (v.get("label")) |i| i.string else "";
                            switch (version) {
                                4 => return .{ .v4 = label },
                                6 => return .{ .v6 = label },
                                else => return error.UnexpectedToken,
                            }
                        },
                        else => return error.UnexpectedToken,
                    }
                } else return error.UnexpectedToken;
            },
            else => return error.UnexpectedToken,
        }
    }
};

test "family-v4" {
    const data =
        \\{
        \\  "value": 4,
        \\  "label": "IPv4",
        \\}
    ;
    const result = try std.json.parseFromSlice(Family, std.testing.allocator, data, .{});
    try std.testing.expectEqual(result.value, Family.v4);
    try std.testing.expectEqualSlices(u8, result.value.v4, "IPv4");
}

pub fn isObjectURI(comptime T: type, uri: []const u8) bool {
    if (std.mem.indexOf(u8, uri, T.path)) |index| {
        const ending = uri[index + T.path.len ..];
        if (ending.len < 3) return false;
        if (ending[0] != '/') return false;
        if (ending[ending.len - 1] != '/') return false;
        for (ending[1 .. ending.len - 1]) |c| if (!std.ascii.isDigit(c)) return false;
        return true;
    }
    return false;
}

pub const AssignedObject = union(enum) {
    device_interface: NestedDeviceInterface,

    pub fn jsonParse(allocator: std.mem.Allocator, source: anytype, options: std.json.ParseOptions) !@This() {
        const value = try std.json.innerParse(std.json.Value, allocator, source, options);
        // defer parsed.deinit();
        return @This().jsonParseFromValue(allocator, value, options);
    }

    pub fn jsonParseFromValue(allocator: std.mem.Allocator, source: std.json.Value, options: std.json.ParseOptions) !@This() {
        switch (source) {
            .object => |v| {
                if (v.get("url")) |inner| {
                    switch (inner) {
                        .string => |uri| {
                            if (isObjectURI(DeviceInterface, uri)) {
                                const value = try std.json.parseFromValueLeaky(
                                    NestedDeviceInterface,
                                    allocator,
                                    source,
                                    options,
                                );
                                return .{
                                    .device_interface = value,
                                };
                            }
                            return error.UnexpectedToken;
                        },
                        else => return error.UnexpectedToken,
                    }
                } else {
                    return error.UnexpectedToken;
                }
            },
            else => return error.UnexpectedToken,
        }
    }
};

pub const IPAddress = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    family: Family,
    address: []const u8,
    vrf: ?NestedVRF,
    tenant: ?NestedTenant,
    status: Status,
    role: ?Role,
    assigned_object_type: ?[]const u8,
    assigned_object_id: ?u64,
    assigned_object: ?AssignedObject,
    nat_inside: ?NestedIPAddress,
    nat_outside: []NestedIPAddress,
    dns_name: []const u8,
    description: []const u8,
    comments: []const u8,
    tags: []NestedTags,
    custom_fields: std.json.Value,
    created: []const u8,
    last_updated: []const u8,

    pub const path = "ipam/ip-addresses";
};

// const testdata = .{
//     .ip_address_1 = @embedFile("testdata/ip-address-1.json"),
//     .ip_address_2 = @embedFile("testdata/ip-address-2.json"),
// };

test "ip-address-1" {
    const parsed = try std.json.parseFromSlice(
        IPAddress,
        std.testing.allocator,
        @embedFile("testdata/ip-address-1.json"),
        .{},
    );
    defer parsed.deinit();
    try std.testing.expect(parsed.value.id == 31);
    try std.testing.expect(std.mem.eql(u8, parsed.value.url, "https://demo.netbox.dev/api/ipam/ip-addresses/31/"));
    try std.testing.expect(std.mem.eql(u8, parsed.value.display, "172.16.0.1/24"));
    try std.testing.expect(std.mem.eql(u8, parsed.value.address, "172.16.0.1/24"));
    try std.testing.expect(parsed.value.vrf.?.id == 1);
    try std.testing.expect(parsed.value.tenant == null);
    try std.testing.expect(parsed.value.assigned_object_type == null);
    try std.testing.expect(parsed.value.assigned_object_id == null);
    try std.testing.expect(parsed.value.assigned_object == null);
    try std.testing.expect(std.mem.eql(u8, parsed.value.status.value, "active"));
}

test "ip-address-2" {
    // const raw = try std.json.parseFromSlice(
    //     std.json.Value,
    //     std.testing.allocator,
    //     @embedFile("testdata/ip-address-2.json"),
    //     .{},
    // );
    // defer raw.deinit();
    const parsed = try std.json.parseFromSlice(
        IPAddress,
        std.testing.allocator,
        @embedFile("testdata/ip-address-2.json"),
        .{},
    );
    defer parsed.deinit();
    try std.testing.expect(parsed.value.id == 19639);
    try std.testing.expect(std.mem.eql(u8, parsed.value.url, "https://demo.netbox.dev/api/ipam/ip-addresses/19639/"));
    try std.testing.expect(std.mem.eql(u8, parsed.value.display, "2001:db8:0:fffe::b/127"));
    try std.testing.expect(std.mem.eql(u8, parsed.value.address, "2001:db8:0:fffe::b/127"));
    try std.testing.expect(parsed.value.vrf == null);
    try std.testing.expect(parsed.value.tenant == null);
    try std.testing.expect(std.mem.eql(u8, parsed.value.assigned_object_type.?, "dcim.interface"));
    try std.testing.expect(parsed.value.assigned_object_id.? == 33);
    try std.testing.expect(parsed.value.assigned_object.?.DeviceInterface.id == 33);
    try std.testing.expect(std.mem.eql(u8, parsed.value.status.value, "active"));
}

const IPAM = @import("../ipam.zig");
const Adapter = @import("../api/adapter.zig").Adapter;

pub fn ip_addresses(self: IPAM) Adapter(IPAddress) {
    return .{
        .api = self.api,
    };
}
