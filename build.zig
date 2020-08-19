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

fn generateEntities() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var json_parser = std.json.Parser.init(&arena.allocator, false);
    var tree = try json_parser.parse(embedded_json);

    var zig_tree = try zig.parse(&arena.allocator,
        \\pub const ENTITIES = [_]@import("main.zig").Entity{
        \\  .{
        \\    .entity = "entity",
        \\    .codepoints = .{ .Single = 1 },
        \\    .characters = "characters",
        \\  },
        \\  .{
        \\    .entity = "entity",
        \\    .codepoints = .{ .Double = [2]u32{ 1, 2 } },
        \\    .characters = "characters",
        \\  },
        \\};
    );

    var decls = zig_tree.root_node.decls();
    assert(decls.len == 1);

    var var_decl = decls[0].castTag(.VarDecl) orelse @panic("not VarDecl");
    std.debug.print("init_node: {}\n", .{var_decl.getTrailer("init_node")});

    var array_decl = var_decl.getTrailer("init_node") orelse @panic("no init_node");
    var array_init = array_decl.castTag(.ArrayInitializer) orelse @panic("not ArrayInitializer");

    var list = array_init.list();
    assert(list.len == 2);

    var single = list[0];
    var double = list[1];

    var entities = tree.root.Object.items();

    var new_array = try zig.ast.Node.ArrayInitializer.alloc(&arena.allocator, entities.len);
    new_array.* = .{
        .base = .{ .tag = .ArrayInitializer },
        .rtoken = array_init.rtoken,
        .list_len = entities.len,
        .lhs = array_init.lhs,
    };

    var i: usize = 0;
    while (i < entities.len) : (i += 1)
        new_array.list()[i] = if (i % 2 == 0) single else double;

    var_decl.setTrailer("init_node", &new_array.base);

    var out_file = try std.fs.cwd().createFile("src/entities.zig", .{});
    _ = try zig.render(&arena.allocator, out_file.writer(), zig_tree);

    //     var map = std.StringHashMap(Entity).init(allocator);
    //     for (tree.root.Object.items()) |entry, i| {
    //         var codepoints_array = &entry.value.Object.get("codepoints").?.Array;
    //         try map.put(entry.key, .{
    //             .entity = try allocator.dupe(u8, entry.key),
    //             .codepoints = switch (codepoints_array.items.len) {
    //                 1 => .{ .Single = @intCast(u32, codepoints_array.items[0].Integer) },
    //                 2 => .{
    //                     .Double = [_]u32{
    //                         @intCast(u32, codepoints_array.items[0].Integer),
    //                         @intCast(u32, codepoints_array.items[1].Integer),
    //                     },
    //                 },
    //                 else => unreachable,
    //             },
    //             .characters = try allocator.dupe(u8, entry.value.Object.get("characters").?.String),
    //         });
    //     }
    //
    //     return map;
}
