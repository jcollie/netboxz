const std = @import("std");

pub const API = @This();

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

pub const request = @import("api/request.zig").request;

pub const get = @import("api/get.zig").get;
pub const ListOptions = @import("api/list.zig").ListOptions;
pub const ListIterator = @import("api/list.zig").ListIterator;
pub const FilterOperation = @import("api/list.zig").FilterOperation;
pub const list = @import("api/list.zig").list;

pub fn getObjectUri(self: *API, allocater: std.mem.Allocator, comptime T: type, id: ?u64) ![]const u8 {
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
