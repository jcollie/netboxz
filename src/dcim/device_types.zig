const NestedManufacturer = @import("manufacturers.zig").NestedManufacturer;

pub const NestedDeviceType = struct {
    id: i64,
    url: []const u8,
    display: []const u8,
    manufacturer: NestedManufacturer,
    model: []const u8,
    slug: []const u8,
};
