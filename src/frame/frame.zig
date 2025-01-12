const std = @import("std");
const assert = std.debug.assert;
const fl = @import("frame_flags.zig");
const testing = std.testing;

// WORD represents the 32bit word in bytes
// Used as a step in the header options
const WORD: u8 = 4;

const Frame = struct {
    const Self = @This();
    // payload is a variable length array of bytes
    payload: std.ArrayList(u8),
    // header is a fixed length array of 12 bytes
    header: [52]u8,

    pub fn init(alloc: std.mem.Allocator) !*Frame {
        const f = try alloc.create(Frame);
        f.payload = std.ArrayList(u8).init(alloc);
        // init with zeros
        f.header = [_]u8{0} ** 52;
        // save default header len of 3
        f.header[0] = f.header[0] | 3;

        return f;
    }

    pub fn from_bytes(alloc: std.mem.Allocator, data: []u8) !*Frame {
        const f = try alloc.create(Frame);
        f.payload = std.ArrayList(u8).init(alloc);
        // copy 12 bytes of data directly into the header
        // note: we do not copy options here
        @memcpy(f.header[0..12], data[0..12]);
        // reset 10th and 11th byte to 0
        f.header[10] = 0;
        f.header[11] = 0;
        return f;
    }

    pub fn read_version(self: Self) u8 {
        return self.header[0] >> 4;
    }

    pub fn write_version(self: *Self, version: u8) void {
        if (version > 15) {
            @panic("version must be between 0 and 15");
        }

        self.header[0] = (version << 4 | self.header[0]);
    }

    pub fn read_flags(self: Self) u8 {
        return self.header[1];
    }

    pub fn write_flags(self: Self, flags: []u8) void {
        for (flags) |flag| {
            self.header[1] = self.header[1] | flag;
        }
    }

    pub fn set_stream_flag(self: *Self) void {
        self.header[10] = self.header[10] | fl.Stream.Stream;
    }

    pub fn is_stream(self: Self) bool {
        return self.header[10] & fl.Stream.Stream != 0;
    }

    fn read_hl(self: Self) u8 {
        return self.header[0] & 0x0F;
    }

    fn increment_hl(self: *Self) void {
        const hl = self.read_hl();
        if (hl == 15) {
            @panic("header len should be less than 15 to increment");
        }

        self.header[0] = hl + 1;
    }

    pub fn write_options(self: *Self, options: []u32) void {
        if (options.len == 0) {
            return;
        }

        if (options.len > 10) {
            @panic("options must be less than 40 bytes");
        }

        if (self.read_hl() == 15) {
            @panic("header len could not be equal to 15 to write options");
        }

        var step: usize = 12;
        for (options) |option| {
            self.header[step] = self.header[step] | @as(u8, @truncate(option));
            self.header[step + 1] = self.header[step + 1] | (@as(u8, @truncate(option >> 8)));
            self.header[step + 2] = self.header[step + 2] | (@as(u8, @truncate(option >> 16)));
            self.header[step + 3] = self.header[step + 3] | (@as(u8, @truncate(option >> 24)));

            step += WORD;
            self.increment_hl();
        }
    }

    // read options from the header, can return null if there are no options
    pub fn read_options(self: Self, alloc: std.mem.Allocator) !?[]u32 {
        const ol = self.read_hl();
        if (ol <= 3) {
            return null;
        }

        const lb: u8 = 12;
        // 3 is the default
        const optsLen: u8 = ol - 3;

        if (optsLen * WORD > 40) {
            @panic("options length must be less than 40 bytes (10 4-bytes words)");
        }

        // allocate an array of 10 u32
        var options = try alloc.alloc(u32, 10);
        // zero out the options
        @memset(options, 0);

        var i: u8 = 0;
        var j: usize = 0;

        while (i != optsLen * WORD) {
            options[j] = options[j] | @as(u32, self.header[lb + i]);
            options[j] = options[j] | (@as(u32, self.header[lb + i + 1]) << 8);
            options[j] = options[j] | (@as(u32, self.header[lb + i + 2]) << 16);
            options[j] = options[j] | (@as(u32, self.header[lb + i + 3]) << 24);
            i += WORD;
            j += 1;
        }

        return options;
    }
};

test "write options" {
    const alloc = std.testing.allocator;
    const f = try Frame.init(alloc);
    defer alloc.destroy(f);

    var opts = [_]u32{ 123, 1234, 11, 112, 123, 12333, 1235, 123155, 1235, 5555 };
    f.write_options(opts[0..]);

    const readOpts = try f.read_options(alloc);

    if (readOpts) |readopts| {
        defer alloc.free(readopts);

        try testing.expect(readopts.len == 10);
        for (opts, 0..) |opt, i| {
            try testing.expect(readopts[i] == opt);
        }
    } else {
        std.debug.print("readOpts is null\n");
        testing.expect(false);
    }
}

test "write version" {
    const alloc = std.testing.allocator;
    const f = try Frame.init(alloc);
    defer alloc.destroy(f);
    f.write_version(3);

    try testing.expect(f.read_version() == 3);
}

test "init frame" {
    const alloc = std.testing.allocator;
    const f = try Frame.init(alloc);
    defer alloc.destroy(f);
}

test "read_header" {
    const alloc = std.testing.allocator;

    var data = [_]u8{ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 };
    const f = try Frame.from_bytes(alloc, &data);
    defer alloc.destroy(f);

    try testing.expect(f.header.len == 52);
    try testing.expect(f.header[1] == 1);
    try testing.expect(f.payload.items.len == 0);
}
