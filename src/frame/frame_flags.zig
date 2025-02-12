// general payload flags
pub const Flag = enum(u8) {
    Control = 0x1,
    Raw = 0x4,
    JSON = 0x8,
    Msgpack = 0x10,
    Gob = 0x20,
    Error = 0x40,
    Proto = 0x80,
};

// Protocol version flag
pub const VERSION1: u8 = 0x1;

// Stream (bytes 10,11) flags
pub const Stream = enum(u8) {
    Stream = 0x1,
    Stop = 0x2,
    Ping = 0x4,
    Pong = 0x8,
};
