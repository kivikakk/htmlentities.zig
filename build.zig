const std = @import("std");
const assert = std.debug.assert;

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const genent = b.addExecutable(.{
        .name = "generate_entities",
        .root_source_file = b.path("src/generate_entities.zig"),
        .target = b.graph.host,
    });
    const genent_step = b.addRunArtifact(genent);
    const genent_out = genent_step.addOutputFileArg("entities.zig");

    const mod = b.addModule("htmlentities", .{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });
    mod.addAnonymousImport("entities", .{ .root_source_file = genent_out });

    const lib = b.addStaticLibrary(.{
        .name = "htmlentities.zig",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });
    lib.root_module.addAnonymousImport("entities", .{ .root_source_file = genent_out });
    b.installArtifact(lib);

    var main_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
    });
    main_tests.root_module.addAnonymousImport("entities", .{ .root_source_file = genent_out });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
