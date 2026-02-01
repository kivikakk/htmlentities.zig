const std = @import("std");
const zig = std.zig;

const embedded_json = @embedFile("entities.json");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const alloc = arena.allocator();

    const args = try std.process.argsAlloc(alloc);
    if (args.len != 2) std.debug.panic("wrong number of arguments", .{});

    const out_file_path = args[1];

    var tree = try std.json.parseFromSlice(
        std.json.Value,
        alloc,
        embedded_json,
        .{},
    );

    var buffer = std.array_list.Managed(u8).init(alloc);
    var writer = buffer.writer();

    try writer.writeAll(
        \\pub const Entity = struct {
        \\    entity: []const u8,
        \\    codepoints: Codepoints,
        \\    characters: []const u8,
        \\};
        \\
        \\pub const Codepoints = union(enum) {
        \\    Single: u32,
        \\    Double: [2]u32,
        \\};
        \\
        \\pub const ENTITIES = [_]Entity{
        \\
    );

    var keys = try std.ArrayList([]const u8).initCapacity(
        alloc,
        tree.value.object.count(),
    );

    var entries_it = tree.value.object.iterator();
    while (entries_it.next()) |entry| {
        keys.appendAssumeCapacity(entry.key_ptr.*);
    }

    std.mem.sortUnstable([]const u8, keys.items, {}, strLessThan);

    for (keys.items) |key| {
        var value = tree.value.object.get(key).?.object;

        try std.fmt.format(
            writer,
            ".{{ .entity = \"{s}\", .codepoints = ",
            .{try escapeString(alloc, key)},
        );

        const codepoints_array = value.get("codepoints").?.array;
        if (codepoints_array.items.len == 1) {
            try std.fmt.format(
                writer,
                ".{{ .Single = {} }}, ",
                .{codepoints_array.items[0].integer},
            );
        } else {
            try std.fmt.format(
                writer,
                ".{{ .Double = [2]u32{{ {}, {} }} }}, ",
                .{
                    codepoints_array.items[0].integer,
                    codepoints_array.items[1].integer,
                },
            );
        }

        try std.fmt.format(
            writer,
            ".characters = \"{s}\" }},\n",
            .{try escapeString(alloc, value.get("characters").?.string)},
        );
    }

    try writer.writeAll("};\n");

    try buffer.append(0);

    const formatted = f: {
        var zig_tree = try zig.Ast.parse(
            alloc,
            buffer.items[0 .. buffer.items.len - 1 :0],
            .zig,
        );

        defer zig_tree.deinit(alloc);
        break :f try zig_tree.renderAlloc(alloc);
    };

    var out_file = std.fs.cwd().createFile(out_file_path, .{}) catch |err| std.debug.panic(
        "unable to open '{s}': {s}",
        .{ out_file_path, @errorName(err) },
    );

    defer out_file.close();
    try out_file.writeAll(formatted);
}

fn strLessThan(_: void, lhs: []const u8, rhs: []const u8) bool {
    return std.mem.lessThan(u8, lhs, rhs);
}

pub fn escapeString(alloc: std.mem.Allocator, bytes: []const u8) ![]const u8 {
    var w: std.Io.Writer.Allocating = .init(alloc);
    errdefer w.deinit();
    try std.zig.stringEscape(bytes, &w.writer);
    return w.written();
}
