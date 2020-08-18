# htmlentities.zig

The bundled [`entities.json`](/entities.json) is sourced from <https://www.w3.org/TR/html5/entities.json>.

Modelled on [Philip Jackson's `entities` crate](https://github.com/p-jackson/entities) for Rust.

## Overview

The core datatypes are:

```zig
pub const Entity = struct {
    entity: []u8,
    codepoints: Codepoints,
    characters: []u8,
};

pub const Codepoints = union(enum) {
    Single: u32,
    Double: [2]u32,
};
```

There are two functions exposed:

```zig
pub fn entities(allocator: *std.mem.Allocator) !std.StringHashMap(Entity)
pub fn freeEntities(allocator: *std.mem.Allocator, map: *std.StringHashMap(Entity)) void
```

## Usage

build.zig:

```zig
    exe.addPackagePath("htmlentities", "vendor/htmlentities.zig/src/main.zig");
```

main.zig:

```zig
const std = @import("std");
const htmlentities = @import("htmlentities");

pub fn main() !void {
    var entities = try htmlentities.entities(std.testing.allocator);
    defer htmlentities.freeEntities(std.testing.allocator, &entities);
    
    var eacute = entities.get("&eacute;").?;
    std.debug.print("eacute: {}\n", .{eacute});
}
```

Output:

```
eacute: Entity{ .entity = &eacute;, .codepoints = Codepoints{ .Single = 233 }, .characters = é }
```

## Help wanted

I'd love to make the work of this comptime and not require allocation from the user at runtime.  Codegen would be fine too.
