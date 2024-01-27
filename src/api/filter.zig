const std = @import("std");

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
