const std = @import("std");

const API = @import("api.zig");

api: *API,

pub fn init(self: *API) @This() {
    return .{
        .api = self,
    };
}

pub const device_roles = @import("dcim/device_roles.zig").device_roles;
pub const devices = @import("dcim/devices.zig").devices;
pub const device_types = @import("dcim/device_types.zig").device_types;
pub const manufacturers = @import("dcim/manufacturers.zig").manufacturers;
