const std = @import("std");
const API = @import("api.zig");

api: *API,

pub const ip_addresses = @import("ipam/ip_addresses.zig").ip_addresses;

pub fn init(self: *API) @This() {
    return .{
        .api = self,
    };
}
