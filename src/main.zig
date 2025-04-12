const std = @import("std");

const entities = @import("entities");
const Entity = entities.Entity;
const Codepoints = entities.Codepoints;

fn order(lhs: entities.Entity, rhs: Entity) std.math.Order {
    return std.mem.order(u8, lhs.entity, rhs.entity);
}

pub fn lookup(entity: []const u8) ?Entity {
    const maybe_index = std.sort.binarySearch(Entity, entities.ENTITIES[0..], Entity{
        .entity = entity,
        .codepoints = .{ .Single = 0 },
        .characters = "",
    }, order);

    if (maybe_index) |index| {
        return entities.ENTITIES[index];
    }
    return null;
}

test "entities" {
    const testing = std.testing;

    try testing.expectEqual(@as(usize, 2231), entities.ENTITIES.len);

    const aelig = lookup("&AElig").?;
    try testing.expectEqualStrings("&AElig", aelig.entity);
    try testing.expectEqual(Codepoints{ .Single = 198 }, aelig.codepoints);
    try testing.expectEqualStrings("Æ", aelig.characters);

    const afr = lookup("&Afr;").?;
    try testing.expectEqualStrings("&Afr;", afr.entity);
    try testing.expectEqual(Codepoints{ .Single = 120068 }, afr.codepoints);
    try testing.expectEqualStrings("𝔄", afr.characters);

    const bnequiv = lookup("&bnequiv;").?;
    try testing.expectEqualStrings("&bnequiv;", bnequiv.entity);
    try testing.expectEqual(Codepoints{ .Double = [2]u32{ 8801, 8421 } }, bnequiv.codepoints);
    try testing.expectEqualStrings("\u{2261}\u{20E5}", bnequiv.characters);
}
