pub fn Paginated(comptime T: type) type {
    return struct {
        count: u64,
        next: ?[]const u8,
        previous: ?[]const u8,
        results: []T,
    };
}
