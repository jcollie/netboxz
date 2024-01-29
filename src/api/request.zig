const std = @import("std");
const API = @import("../api.zig");
const uriparser = @import("uriparser");

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

pub fn request(self: *API, method: std.http.Method, uri: []const u8, body: ?[]const u8) !Result {
    const parsed_uri = try std.Uri.parse(uri);

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
