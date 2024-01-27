const NestedModuleBay = @import("module_bays.zig").NestedModuleBay;

pub const NestedModule = struct {
    id: u64,
    url: []const u8,
    display: []const u8,
    device: u64,
    module_bay: NestedModuleBay,
};
