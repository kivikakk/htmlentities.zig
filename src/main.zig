const std = @import("std");
const testing = std.testing;

pub const Entity = struct {
    entity: []u8,
    codepoints: Codepoints,
    characters: []u8,
};

pub const Codepoints = union(enum) {
    Single: u32,
    Double: [2]u32,
};

pub const Error = error{OutOfMemory};

// Ideally this would happen at comptime, but JSON parsing at
// comptime is not a thing (yet?).
pub fn entities(allocator: *std.mem.Allocator) Error!std.StringHashMap(Entity) {
    var p = std.json.Parser.init(allocator, false);
    defer p.deinit();

    const json = @embedFile("../entities.json");
    var tree = p.parse(json) catch |err| switch (err) {
        error.OutOfMemory => return error.OutOfMemory,
        // This should never fail otherwise.
        else => @panic("bundled entities.json did not parse"),
    };
    defer tree.deinit();

    var map = std.StringHashMap(Entity).init(allocator);
    for (tree.root.Object.items()) |entry, i| {
        var codepoints_array = &entry.value.Object.get("codepoints").?.Array;
        try map.put(entry.key, .{
            .entity = try allocator.dupe(u8, entry.key),
            .codepoints = switch (codepoints_array.items.len) {
                1 => .{ .Single = @intCast(u32, codepoints_array.items[0].Integer) },
                2 => .{
                    .Double = [_]u32{
                        @intCast(u32, codepoints_array.items[0].Integer),
                        @intCast(u32, codepoints_array.items[1].Integer),
                    },
                },
                else => unreachable,
            },
            .characters = try allocator.dupe(u8, entry.value.Object.get("characters").?.String),
        });
    }

    return map;
}

pub fn freeEntities(allocator: *std.mem.Allocator, map: *std.StringHashMap(Entity)) void {
    for (map.items()) |item| {
        allocator.free(item.value.entity);
        allocator.free(item.value.characters);
    }
    map.deinit();
}

test "entities" {
    var map = try entities(testing.allocator);
    defer freeEntities(testing.allocator, &map);

    testing.expectEqual(@as(usize, 2231), map.count());

    var aelig = map.get("&AElig").?;
    testing.expectEqualStrings("&AElig", aelig.entity);
    testing.expectEqual(Codepoints{ .Single = 198 }, aelig.codepoints);
    testing.expectEqualStrings("Æ", aelig.characters);

    var afr = map.get("&Afr;").?;
    testing.expectEqualStrings("&Afr;", afr.entity);
    testing.expectEqual(Codepoints{ .Single = 120068 }, afr.codepoints);
    testing.expectEqualStrings("𝔄", afr.characters);

    var bnequiv = map.get("&bnequiv;").?;
    testing.expectEqualStrings("&bnequiv;", bnequiv.entity);
    testing.expectEqual(Codepoints{ .Double = [2]u32{ 8801, 8421 } }, bnequiv.codepoints);
    testing.expectEqualStrings("\u{2261}\u{20E5}", bnequiv.characters);
}
