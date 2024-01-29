const API = @import("../api.zig");

const GetResult = @import("get.zig").GetResult;
const ListIterator = @import("list.zig").ListIterator;
const ListOptions = @import("list.zig").ListOptions;

pub fn Adapter(comptime T: type) type {
    return struct {
        api: *API,

        pub fn get(self: @This(), id: u64) !GetResult(T) {
            return try self.api.get(T, id);
        }

        pub fn list(self: @This(), options: ListOptions) !ListIterator(T) {
            return try self.api.list(T, options);
        }
    };
}
