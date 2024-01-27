const std = @import("std");

const NetBoxZ = @import("netboxz");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const netbox = try NetBoxZ.init(alloc, "https://demo.netbox.dev", null);
    defer netbox.deinit();

    const result = try netbox.dcim().devices().get(1);
    defer result.deinit();

    switch (result) {
        .ok => |r| {
            std.debug.print("{d} {s}\n", .{ r.item.id, r.item.display });
        },
        .err => |r| {
            std.debug.print("{} {s}\n", .{ r.status, r.detail });
        },
    }
}
