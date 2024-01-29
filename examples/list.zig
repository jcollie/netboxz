const std = @import("std");

const netboxz = @import("netboxz");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const netbox = try netboxz.init(alloc, "https://demo.netbox.dev", null);
    defer netbox.deinit();

    var device_iter = try netbox.dcim().devices().list(
        .{
            .limit = 1,
            .filters = &[_]netboxz.FilterOperation{
                .{
                    .string = .{
                        .key = "name",
                        .value = "dmi",
                        .comparison = .ic,
                    },
                },
            },
        },
    );
    defer device_iter.deinit();

    while (try device_iter.next()) |result| {
        defer result.deinit();
        switch (result) {
            .ok => |r| {
                for (r.items) |device| {
                    std.debug.print("{d} {s}\n", .{ device.id, device.display });
                }
            },
            .err => |r| {
                std.debug.print("error: {} {s}\n", .{ r.status, r.detail });
                break;
            },
        }
    }

    var addr_iter = try netbox.ipam().ip_addresses().list(
        .{
            .limit = 2,
        },
    );
    defer addr_iter.deinit();

    var iter_count: usize = 0;
    while (try addr_iter.next()) |result| {
        defer result.deinit();
        switch (result) {
            .ok => |r| {
                iter_count += 1;
                std.debug.print("{d} {d}\n", .{ iter_count, r.count });
                for (r.items) |addr| {
                    std.debug.print("{d} {d} {} {s}\n", .{ iter_count, addr.id, addr.family, addr.address });
                }
            },
            .err => |r| {
                std.debug.print("error: {} {s}\n", .{ r.status, r.detail });
                break;
            },
        }
    }
}
