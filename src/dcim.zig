const std = @import("std");

const API = @import("api.zig");

pub const DCIM = struct {
    api: *API,

    pub const devices = @import("dcim/devices.zig").devices;
};

pub fn dcim(self: *API) DCIM {
    return .{
        .api = self,
    };
}
