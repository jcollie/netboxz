const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    const optimize = b.standardOptimizeOption(.{});

    const module = b.addModule(
        "netboxz",
        .{
            .root_source_file = .{
                .path = "src/api.zig",
            },
            .target = target,
            .optimize = optimize,
        },
    );

    const get = b.addExecutable(
        .{
            .name = "get",
            .root_source_file = .{
                .path = "examples/get.zig",
            },
            .target = target,
            .optimize = optimize,
        },
    );
    get.root_module.addImport("netboxz", module);

    b.installArtifact(get);

    const list = b.addExecutable(
        .{
            .name = "list",
            .root_source_file = .{
                .path = "examples/list.zig",
            },
            .target = target,
            .optimize = optimize,
        },
    );
    list.root_module.addImport("netboxz", module);

    b.installArtifact(list);

    const unit_tests = b.addTest(
        .{
            .root_source_file = .{ .path = "src/api.zig" },
            .target = target,
            .optimize = optimize,
        },
    );

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
}
