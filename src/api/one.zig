const std = @import("std");
const API = @import("../api.zig");

const FilterOperation = @import("filter.zig").FilterOperation;
const Paginated = @import("pagination.zig").Paginated;

pub fn OneResult(comptime T: type) type {
    return union(enum) {
        ok: struct {
            api: *API,
            arena: std.heap.ArenaAllocator,
            status: std.http.Status,
            value: T,
        },
        notfound: struct {
            api: *API,
            status: std.http.Status,
            count: u64,
        },
        toomany: struct {
            api: *API,
            status: std.http.Status,
            count: u64,
        },
        err: struct {
            api: *API,
            status: std.http.Status,
            detail: []const u8,
        },

        pub fn deinit(self: @This()) void {
            switch (self) {
                .ok => |r| r.deinit(),
                .err => |r| r.deinit(),
            }
        }
    };
}

pub fn one(
    self: *API,
    comptime T: type,
    filters: []const FilterOperation,
) !?OneResult(T) {
    var arena = std.heap.ArenaAllocator.init(self.alloc);
    defer arena.deinit();

    var uri = try std.Uri.parse(try self.getObjectUri(arena.allocator(), T, null));

    {
        const u = try std.Uri.parseWithoutScheme("?limit=1");
        uri = try std.Uri.resolve(uri, u, true, arena.allocator());
    }

    for (filters) |filter| {
        const s = try filter.format(arena.allocator());
        const u = try std.Uri.parseWithoutScheme(s);
        uri = try std.Uri.resolve(uri, u, true, arena.allocator());
    }

    var buffer = std.ArrayList(u8).init(arena.allocator());
    errdefer buffer.deinit();

    try uri.writeToStream(
        .{
            .scheme = true,
            .authority = true,
            .path = true,
            .query = true,
            .fragment = true,
        },
        buffer.writer(),
    );

    const result = try self.request(.GET, buffer.toOwnedSlice(), null);
    defer result.deinit();

    switch (result) {
        .ok => |r| {
            const xarena = std.heap.ArenaAllocator.init(self.alloc);
            const xalloc = xarena.allocator();
            const parsed = try std.json.parseFromSliceLeaky(Paginated(T), xalloc, r.data, .{});

            switch (parsed.count) {
                0 => {
                    xarena.deinit();
                    return .{
                        .notfound = .{
                            .api = self,
                            .status = r.status,
                            .count = r.count,
                        },
                    };
                },
                1 => {
                    return .{
                        .ok = .{
                            .api = self,
                            .arena = xarena,
                            .status = r.status,
                            .value = parsed.results[0],
                        },
                    };
                },
                else => {
                    xarena.deinit();
                    return .{
                        .toomany = .{
                            .api = self,
                            .status = r.status,
                            .count = r.count,
                        },
                    };
                },
            }
        },
        .err => |r| {
            return .{
                .err = .{
                    .api = self.api,
                    .status = r.status,
                    .detail = try self.api.alloc.dupe(u8, r.detail),
                },
            };
        },
    }
}
