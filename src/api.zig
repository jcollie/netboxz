const std = @import("std");

const API = @This();

pub const Device = @import("dcim/devices.zig").Device;
pub const IPAddress = @import("ipam/ip_addresses.zig").IPAddress;

alloc: std.mem.Allocator,
uri: []const u8,
client: std.http.Client,
headers: std.http.Headers,

pub const dcim = @import("dcim.zig").dcim;
pub const ipam = @import("ipam.zig").ipam;

pub fn init(alloc: std.mem.Allocator, uri: []const u8, token: ?[]const u8) !*API {
    _ = try std.Uri.parse(uri);
    const api = try alloc.create(API);
    api.*.alloc = alloc;
    api.*.uri = try api.alloc.dupe(u8, uri);

    api.*.client = std.http.Client{ .allocator = alloc };
    api.*.headers = std.http.Headers{
        .allocator = alloc,
        .owned = true,
    };
    if (token) |tok| try api.addToken(tok);

    try api.headers.append("Accept", "application/json");
    return api;
}

pub fn addToken(self: *API, token: []const u8) !void {
    self.removeToken();
    var buf: [256]u8 = undefined;
    const auth = try std.fmt.bufPrint(&buf, "Token {s}", .{token});
    try self.headers.append("Authorization", auth);
}

pub fn removeToken(self: *API) void {
    _ = self.headers.delete("Authorization");
}

pub fn deinit(self: *API) void {
    const alloc = self.alloc;
    self.headers.deinit();
    self.client.deinit();
    alloc.free(self.uri);
    alloc.destroy(self);
}

pub const Result = union(enum) {
    ok: struct {
        api: *API,
        status: std.http.Status,
        data: []const u8,

        pub fn deinit(self: @This()) void {
            self.api.alloc.free(self.data);
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

fn request(self: *API, method: std.http.Method, uri: []const u8, body: ?[]const u8) !Result {
    const parsed_uri = try std.Uri.parse(uri);
    std.debug.print("{}\n", .{parsed_uri});

    var headers = try self.headers.clone(self.alloc);
    if (body) |_| {
        try headers.append("Content-Type", "application/json");
    }
    defer headers.deinit();

    var req = try self.client.open(method, parsed_uri, headers, .{});
    defer req.deinit();

    if (body) |d| {
        req.transfer_encoding = .{ .content_length = d.len };
    }

    try req.send(.{});
    if (body) |d| {
        try req.writeAll(d);
        try req.finish();
    }
    try req.wait();

    var buffer = std.ArrayList(u8).init(self.alloc);
    errdefer buffer.deinit();

    while (true) {
        var buf: [8192]u8 = undefined;
        const len = try req.reader().read(&buf);
        if (len == 0) break;
        try buffer.appendSlice(buf[0..len]);
    }

    const data = try buffer.toOwnedSlice();
    std.debug.print("{s}\n", .{data});

    if (req.response.status.class() != .success) {
        var parsed = try std.json.parseFromSlice(
            struct {
                detail: []const u8,
            },
            self.alloc,
            data,
            .{},
        );
        defer parsed.deinit();
        return .{
            .err = .{
                .api = self,
                .status = req.response.status,
                .detail = try self.alloc.dupe(u8, parsed.value.detail),
            },
        };
    }

    return .{
        .ok = .{
            .api = self,
            .status = req.response.status,
            .data = data,
        },
    };
}

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

fn getByUri(self: *API, comptime T: type, uri: []const u8) !GetResult(T) {
    var arena = std.heap.ArenaAllocator.init(self.alloc);

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

/// Get an object from the API
pub fn get(self: *API, comptime T: type, id: u64) !GetResult(T) {
    // var uri = self.uri;

    // var buf: [32]u8 = undefined;
    // const id_string = try std.fmt.bufPrint(&buf, "/{d}/", .{id});

    // uri.path = try std.mem.concat(
    //     self.alloc,
    //     u8,
    //     &[_][]const u8{
    //         self.uri.path,
    //         if (std.mem.endsWith(u8, self.uri.path, "/")) "" else "/",
    //         "api/",
    //         T.path,
    //         id_string,
    //     },
    // );
    // defer self.alloc.free(uri.path);

    const uri = try self.getUriForObject(self.alloc, T, id);
    defer self.alloc.free(uri);

    return try self.getByUri(T, uri);
}

pub fn Paginated(comptime T: type) type {
    return struct {
        count: u32,
        next: ?[]const u8,
        previous: ?[]const u8,
        results: []T,
    };
}

pub fn ListIterator(comptime T: type) type {
    return struct {
        api: *API,
        arena: std.heap.ArenaAllocator,
        next_uri: ?[]const u8,
        previous_uri: ?[]const u8,

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

        pub fn deinit(self: ListIterator(T)) void {
            self.arena.deinit();
        }

        pub fn next(self: *ListIterator(T)) !?ListIteratorResult(T) {
            if (self.next_uri) |uri| {
                const result = try self.api.listByUri(T, uri);
                defer result.deinit();
                switch (result) {
                    .ok => |r| {
                        self.*.next_uri = if (r.next_uri) |v| try self.arena.allocator().dupe(u8, v) else null;
                        self.*.previous_uri = if (r.previous_uri) |v| try self.arena.allocator().dupe(u8, v) else null;
                        return .{
                            .ok = .{
                                .api = r.api,
                                .arena = r.arena,
                                .status = r.status,
                                .count = r.count,
                                .items = r.items,
                            },
                        };
                    },
                    .err => |r| {
                        self.*.next_uri = null;
                        self.*.next_uri = null;
                        return .{
                            .err = .{
                                .api = r.api,
                                .status = r.status,
                                .detail = r.detail,
                            },
                        };
                    },
                }
            }
            return null;
        }

        pub fn previous(self: *ListIterator(T)) !?ListIterator(T) {
            if (self.previous_uri) |uri| {
                const result = try self.api.listByUri(T, uri);
                defer result.deinit();
                switch (result) {
                    .ok => |r| {
                        self.*.next_uri = if (r.next_uri) |v| try self.arena.allocator().dupe(u8, v) else null;
                        self.*.previous_uri = if (r.previous_uri) |v| try self.arena.allocator().dupe(u8, v) else null;
                        return .{
                            .ok = .{
                                .api = r.api,
                                .arena = r.arena,
                                .status = r.status,
                                .count = r.count,
                                .items = r.items,
                            },
                        };
                    },
                    .err => |r| {
                        self.*.next_uri = null;
                        self.*.next_uri = null;
                        return .{
                            .err = .{
                                .api = r.api,
                                .status = r.status,
                                .detail = r.detail,
                            },
                        };
                    },
                }
            }
            return null;
        }
    };
}

pub fn NumericFilter(comptime T: type) type {
    switch (@typeInfo(T)) {
        .Int, .Float => {},
        else => @compileError("NumericFilter is only supported for numeric types, not " ++ @typeName(T)),
    }

    return struct {
        key: []const u8,
        value: T,
        comparison: std.math.CompareOperator = .eq,

        pub fn format(self: @This(), alloc: std.mem.Allocator) ![]const u8 {
            return try std.fmt.allocPrint(
                alloc,
                "?{s}{s}{s}={d}",
                .{
                    self.key,
                    switch (self.comparison) {
                        .eq => "",
                        else => "__",
                    },
                    switch (self.comparison) {
                        .eq => "",
                        .neq => "n",
                        else => @tagName(self.comparison),
                    },
                    self.value,
                },
            );
        }
    };
}

pub const StringFilter = struct {
    key: []const u8,
    value: []const u8,
    comparison: enum {
        eq,
        neq,
        ic,
        nic,
        isw,
        nisw,
        iew,
        niew,
        ie,
        nie,
        empty,
    } = .eq,

    pub fn format(self: @This(), alloc: std.mem.Allocator) ![]const u8 {
        return try std.fmt.allocPrint(
            alloc,
            "?{s}{s}{s}={s}",
            .{
                self.key,
                switch (self.comparison) {
                    .eq => "",
                    else => "__",
                },
                switch (self.comparison) {
                    .eq => "",
                    .neq => "n",
                    else => @tagName(self.comparison),
                },
                self.value,
            },
        );
    }
};

pub const OtherFilter = struct {
    key: []const u8,
    value: u64,
    comparison: enum {
        eq,
        neq,
    } = .eq,

    pub fn format(self: @This(), alloc: std.mem.Allocator) ![]const u8 {
        return try std.fmt.allocPrint(
            alloc,
            "?{s}{s}={d}",
            .{
                self.key,
                switch (self.comparison) {
                    .eq => "",
                    .neq => "__n",
                },
                self.value,
            },
        );
    }
};

pub const FilterOperation = union(enum) {
    i64: NumericFilter(i64),
    u64: NumericFilter(i64),
    f64: NumericFilter(f64),
    string: StringFilter,
    other: OtherFilter,

    pub fn format(self: FilterOperation, alloc: std.mem.Allocator) ![]const u8 {
        return switch (self) {
            .i64 => |f| try f.format(alloc),
            .u64 => |f| try f.format(alloc),
            .f64 => |f| try f.format(alloc),
            .string => |f| try f.format(alloc),
            .other => |f| try f.format(alloc),
        };
    }
};

pub fn ListResult(comptime T: type) type {
    return union(enum) {
        ok: struct {
            api: *API,
            arena: std.heap.ArenaAllocator,
            status: std.http.Status,
            count: u64,
            next_uri: ?[]const u8,
            previous_uri: ?[]const u8,
            items: []T,

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

pub fn listByUri(
    self: *API,
    comptime T: type,
    uri: []const u8,
) !ListResult(T) {
    const result = try self.request(.GET, uri, null);
    defer result.deinit();

    switch (result) {
        .ok => |r| {
            var arena = std.heap.ArenaAllocator.init(self.alloc);
            const alloc = arena.allocator();
            const parsed = try std.json.parseFromSliceLeaky(Paginated(T), alloc, r.data, .{});
            return .{
                .ok = .{
                    .api = self,
                    .arena = arena,
                    .status = r.status,
                    .count = parsed.count,
                    .next_uri = parsed.next,
                    .previous_uri = parsed.previous,
                    .items = parsed.results,
                },
            };
        },
        .err => |r| {
            return .{
                .err = .{
                    .api = self,
                    .status = r.status,
                    .detail = try self.alloc.dupe(u8, r.detail),
                },
            };
        },
    }
}

pub const ListOptions = struct {
    offset: ?u64 = null,
    limit: ?u64 = null,
    filters: []const FilterOperation = &.{},
};

pub fn getUriForObject(self: *API, allocater: std.mem.Allocator, comptime T: type, id: ?u64) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(self.alloc);
    const alloc = arena.allocator();
    defer arena.deinit();

    var uri = try std.Uri.parse(try alloc.dupe(u8, self.uri));

    if (id) |i| {
        var buf: [32]u8 = undefined;
        const ref = try std.Uri.parseWithoutScheme(try std.fmt.bufPrint(&buf, "api/" ++ T.path ++ "/{d}/", .{i}));
        uri = try std.Uri.resolve(uri, ref, true, alloc);
    } else {
        const ref = try std.Uri.parseWithoutScheme("api/" ++ T.path ++ "/");
        uri = try std.Uri.resolve(uri, ref, true, alloc);
    }

    var buffer = std.ArrayList(u8).init(alloc);
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

    return try allocater.dupe(u8, try buffer.toOwnedSlice());
}

pub fn list(
    self: *API,
    comptime T: type,
    options: ListOptions,
) !ListIterator(T) {
    var arena = std.heap.ArenaAllocator.init(self.alloc);

    var uri = try std.Uri.parse(try self.getUriForObject(arena.allocator(), T, null));

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
        .next_uri = try buffer.toOwnedSlice(),
        .previous_uri = null,
    };
}
