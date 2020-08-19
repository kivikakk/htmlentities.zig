const std = @import("std");
const assert = std.debug.assert;
const testing = std.testing;

pub const Entity = struct {
    entity: []const u8,
    codepoints: Codepoints,
    characters: []const u8,
};

pub const Codepoints = union(enum) {
    Single: u32,
    Double: [2]u32,
};

pub const ENTITIES = @import("entities.zig").ENTITIES;

pub fn lookup() void {}

test "entities" {
    testing.expectEqual(@as(usize, 2231), ENTITIES.len);

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
