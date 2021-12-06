const std = @import("std");
const assert = std.debug.assert;
const zig = std.zig;

pub fn build(b: *std.build.Builder) !void {
    try generateEntities();

    const mode = b.standardReleaseOptions();
    const lib = b.addStaticLibrary("htmlentities.zig", "src/main.zig");
    lib.setBuildMode(mode);
    lib.install();

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

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

    var allocator = arena.allocator();

    var json_parser = std.json.Parser.init(allocator, false);
    var tree = try json_parser.parse(embedded_json);

    var buffer = std.ArrayList(u8).init(allocator);
    var writer = buffer.writer();

    try writer.writeAll("pub const ENTITIES = [_]@import(\"main.zig\").Entity{\n");

    var keys = try std.ArrayList([]const u8).initCapacity(allocator, tree.root.Object.count());
    var entries_it = tree.root.Object.iterator();
    while (entries_it.next()) |entry| {
        keys.appendAssumeCapacity(entry.key_ptr.*);
    }

    std.sort.insertionSort([]const u8, keys.items, {}, strLessThan);

    for (keys.items) |key| {
        var value = tree.root.Object.get(key).?.Object;
        try std.fmt.format(writer, ".{{ .entity = \"{}\", .codepoints = ", .{zig.fmtEscapes(key)});

        var codepoints_array = value.get("codepoints").?.Array;
        if (codepoints_array.items.len == 1) {
            try std.fmt.format(writer, ".{{ .Single = {} }}, ", .{codepoints_array.items[0].Integer});
        } else {
            try std.fmt.format(writer, ".{{ .Double = [2]u32{{ {}, {} }} }}, ", .{ codepoints_array.items[0].Integer, codepoints_array.items[1].Integer });
        }

        try std.fmt.format(writer, ".characters = \"{}\" }},\n", .{zig.fmtEscapes(value.get("characters").?.String)});
    }

    try writer.writeAll("};\n");

    try buffer.append(0);

    var zig_tree = try zig.parse(allocator, buffer.items[0 .. buffer.items.len - 1 :0]);

    var out_file = try std.fs.cwd().createFile("src/entities.zig", .{});
    const formatted = try zig_tree.render(allocator);
    try out_file.writer().writeAll(formatted);
    out_file.close();
}
