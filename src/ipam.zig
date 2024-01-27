const std = @import("std");

const API = @import("api.zig");
const IPAddress = @import("ipam/ip_addresses.zig").IPAddress;

pub const IPAM = struct {
    api: *API,

    pub const IP_ADDRESSES = struct {
        api: *API,

        pub fn get(self: IP_ADDRESSES, id: u64) !API.GetResult(IPAddress) {
            return try self.api.get(IPAddress, id);
        }

        pub fn list(self: IP_ADDRESSES, options: API.ListOptions) !API.ListIterator(IPAddress) {
            return try self.api.list(IPAddress, options);
        }
    };

    pub fn ip_addresses(self: IPAM) IP_ADDRESSES {
        return .{
            .api = self.api,
        };
    }
};

pub fn ipam(self: *API) IPAM {
    return IPAM{
        .api = self,
    };
}
