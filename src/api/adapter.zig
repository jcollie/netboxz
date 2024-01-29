const API = @import("../api.zig");

const GetResult = @import("get.zig").GetResult;
const ListIterator = @import("list.zig").ListIterator;
const ListOptions = @import("list.zig").ListOptions;
const FilterOperation = @import("filter.zig").FilterOperation;
const OneResult = @import("one.zig").OneResult;

pub fn Adapter(comptime T: type) type {
    return struct {
        api: *API,

        pub fn get(self: @This(), id: u64) !GetResult(T) {
            return try self.api.get(T, id);
        }

        pub fn one(self: @This(), filter: []FilterOperation) !OneResult(T) {
            return try self.api.one(T, filter);
        }

        pub fn list(self: @This(), options: ListOptions) !ListIterator(T) {
            return try self.api.list(T, options);
        }
    };
}
