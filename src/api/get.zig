const std = @import("std");

const API = @import("../api.zig");

pub fn GetResult(comptime T: type) type {
    return union(enum) {
        ok: struct {
            api: *API,
            arena: std.heap.ArenaAllocator,
            status: std.http.Status,
            item: T,

            pub fn deinit(self: @This()) void {
                self.arena.deinit();
            }
        },
        err: struct {
            api: *API,
            status: std.http.Status,
            detail: []const u8,

            pub fn deinit(self: @This()) void {
                self.api.alloc.free(self.detail);
            }
        },

        pub fn deinit(self: @This()) void {
            switch (self) {
                .ok => |r| r.deinit(),
                .err => |r| r.deinit(),
            }
        }
    };
}

/// Get an object from the API
pub fn get(self: *API, comptime T: type, id: u64) !GetResult(T) {
    const uri = try self.getObjectUri(self.alloc, T, id);
    defer self.alloc.free(uri);

    var arena = std.heap.ArenaAllocator.init(self.alloc);
    errdefer arena.deinit();

    const result = try self.request(
        .GET,
        try arena.allocator().dupe(u8, uri),
        null,
    );

    switch (result) {
        .ok => |r| {
            const item = try std.json.parseFromSliceLeaky(T, arena.allocator(), r.data, .{});

            return GetResult(T){
                .ok = .{
                    .api = self,
                    .arena = arena,
                    .status = r.status,
                    .item = item,
                },
            };
        },
        .err => |r| {
            return GetResult(T){
                .err = .{
                    .api = self,
                    .status = r.status,
                    .detail = r.detail,
                },
            };
        },
    }
}
