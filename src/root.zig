const std = @import("std");
const testing = std.testing;
const f = @import("frame/frame.zig");

test {
    @import("std").testing.refAllDecls(@This());
}
