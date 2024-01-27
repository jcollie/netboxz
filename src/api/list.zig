const std = @import("std");
const API = @import("../api.zig");

pub fn ListIterator(comptime T: type) type {
    return struct {
        api: *API,
        arena: std.heap.ArenaAllocator,
        uris: struct {
            next: ?[]const u8,
            previous: ?[]const u8,
        },

        pub fn ListIteratorResult(comptime I: type) type {
            return union(enum) {
                ok: struct {
                    api: *API,
                    arena: std.heap.ArenaAllocator,
                    status: std.http.Status,
                    count: u64,
                    items: []I,

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

        pub fn Paginated(comptime I: type) type {
            return struct {
                count: u32,
                next: ?[]const u8,
                previous: ?[]const u8,
                results: []I,
            };
        }

        pub fn deinit(self: ListIterator(T)) void {
            self.arena.deinit();
        }

        fn processUri(
            self: *ListIterator(T),
            uri: []const u8,
        ) !ListIteratorResult(T) {
            const result = try self.api.request(.GET, uri, null);
            defer result.deinit();

            switch (result) {
                .ok => |r| {
                    var arena = std.heap.ArenaAllocator.init(self.api.alloc);
                    errdefer arena.deinit();

                    const alloc = arena.allocator();
                    const parsed = try std.json.parseFromSliceLeaky(Paginated(T), alloc, r.data, .{});

                    self.*.uris.next = if (parsed.next) |v| try self.arena.allocator().dupe(u8, v) else null;
                    self.*.uris.previous = if (parsed.previous) |v| try self.arena.allocator().dupe(u8, v) else null;

                    return .{
                        .ok = .{
                            .api = self.api,
                            .arena = arena,
                            .status = r.status,
                            .count = parsed.count,
                            .items = parsed.results,
                        },
                    };
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

        pub fn next(self: *ListIterator(T)) !?ListIteratorResult(T) {
            if (self.uris.next) |uri| return try self.processUri(uri);
            return null;
        }

        pub fn previous(self: *ListIterator(T)) !?ListIterator(T) {
            if (self.uris.previous) |uri| return try self.processUri(uri);
            return null;
        }
    };
}

// pub fn ListResult(comptime T: type) type {
//     return union(enum) {
//         ok: struct {
//             api: *API,
//             arena: std.heap.ArenaAllocator,
//             status: std.http.Status,
//             count: u64,
//             next_uri: ?[]const u8,
//             previous_uri: ?[]const u8,
//             items: []T,

//             pub fn deinit(self: @This()) void {
//                 self.arena.deinit();
//             }
//         },
//         err: struct {
//             api: *API,
//             status: std.http.Status,
//             detail: []const u8,

//             pub fn deinit(self: @This()) void {
//                 self.api.alloc.free(self.detail);
//             }
//         },

//         pub fn deinit(self: @This()) void {
//             switch (self) {
//                 .ok => |r| r.deinit(),
//                 .err => |r| r.deinit(),
//             }
//         }
//     };
// }

pub const FilterOperation = @import("filter.zig").FilterOperation;

pub const ListOptions = struct {
    offset: ?u64 = null,
    limit: ?u64 = null,
    filters: []const FilterOperation = &.{},
};

pub fn list(
    self: *API,
    comptime T: type,
    options: ListOptions,
) !ListIterator(T) {
    var arena = std.heap.ArenaAllocator.init(self.alloc);

    var uri = try std.Uri.parse(try self.getObjectUri(arena.allocator(), T, null));

    if (options.offset) |offset| {
        var buf: [32]u8 = undefined;
        const u = try std.Uri.parseWithoutScheme(try std.fmt.bufPrint(&buf, "?offset={d}", .{offset}));
        uri = try std.Uri.resolve(uri, u, true, arena.allocator());
    }

    if (options.limit) |limit| {
        var buf: [32]u8 = undefined;
        const u = try std.Uri.parseWithoutScheme(try std.fmt.bufPrint(&buf, "?limit={d}", .{limit}));
        uri = try std.Uri.resolve(uri, u, true, arena.allocator());
    }

    for (options.filters) |filter| {
        const s = try filter.format(arena.allocator());
        const u = try std.Uri.parseWithoutScheme(s);
        uri = try std.Uri.resolve(uri, u, true, arena.allocator());
    }

    var buffer = std.ArrayList(u8).init(arena.allocator());
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

    return ListIterator(T){
        .api = self,
        .arena = arena,
        .uris = .{
            .next = try buffer.toOwnedSlice(),
            .previous = null,
        },
    };
}
