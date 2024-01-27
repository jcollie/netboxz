const std = @import("std");

const API = @import("api.zig");

const Device = @import("dcim/devices.zig").Device;

pub const DCIM = struct {
    api: *API,

    pub const DEVICES = struct {
        api: *API,

        pub fn get(self: DEVICES, id: u64) !API.GetResult(Device) {
            return try self.api.get(Device, id);
        }

        pub fn list(self: DEVICES, options: API.ListOptions) !API.ListIterator(Device) {
            return try self.api.list(Device, options);
        }
    };

    pub fn devices(self: DCIM) DEVICES {
        return .{
            .api = self.api,
        };
    }
};

pub fn dcim(self: *API) DCIM {
    return .{
        .api = self,
    };
}
