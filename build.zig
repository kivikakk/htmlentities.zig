const std = @import("std");
const assert = std.debug.assert;
const zig = std.zig;

pub fn build(b: *std.Build) !void {
    try generateEntities();

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("htmlentities", .{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });

    const lib = b.addStaticLibrary(.{
        .name = "htmlentities.zig",
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
        .target = target,
    });
    b.installArtifact(lib);

    var main_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .optimize = optimize,
    });

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}

const embedded_json = @embedFile("entities.json");

fn strLessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.lessThan(u8, lhs, rhs);
}

fn generateEntities() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var tree = try std.json.parseFromSlice(std.json.Value, allocator, embedded_json, .{});

    var buffer = std.ArrayList(u8).init(allocator);
    var writer = buffer.writer();

    try writer.writeAll("pub const ENTITIES = [_]@import(\"main.zig\").Entity{\n");

    var keys = try std.ArrayList([]const u8).initCapacity(allocator, tree.value.object.count());
    var entries_it = tree.value.object.iterator();
    while (entries_it.next()) |entry| {
        keys.appendAssumeCapacity(entry.key_ptr.*);
    }

    std.mem.sortUnstable([]const u8, keys.items, {}, strLessThan);

    for (keys.items) |key| {
        var value = tree.value.object.get(key).?.object;
        try std.fmt.format(writer, ".{{ .entity = \"{}\", .codepoints = ", .{zig.fmtEscapes(key)});

        const codepoints_array = value.get("codepoints").?.array;
        if (codepoints_array.items.len == 1) {
            try std.fmt.format(writer, ".{{ .Single = {} }}, ", .{codepoints_array.items[0].integer});
        } else {
            try std.fmt.format(writer, ".{{ .Double = [2]u32{{ {}, {} }} }}, ", .{ codepoints_array.items[0].integer, codepoints_array.items[1].integer });
        }

        try std.fmt.format(writer, ".characters = \"{}\" }},\n", .{zig.fmtEscapes(value.get("characters").?.string)});
    }

    try writer.writeAll("};\n");

    try buffer.append(0);

    var zig_tree = try zig.Ast.parse(allocator, buffer.items[0 .. buffer.items.len - 1 :0], .zig);

    var out_file = try std.fs.cwd().createFile("src/entities.zig", .{});
    const formatted = try zig_tree.render(allocator);
    try out_file.writer().writeAll(formatted);
    out_file.close();
}
