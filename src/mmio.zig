const std = @import("std");

pub fn Mmio(comptime PackedT: type) type {
    const size = @bitSizeOf(PackedT);
    if (size % 8 != 0)
        @compileError("size must be divisible by 8!");

    if (!std.math.isPowerOfTwo(size / 8))
        @compileError("size must encode a power of two number of bytes!");

    const BackingT = @typeInfo(PackedT).Struct.backing_integer orelse @compileError("PackedT must be a packed struct");

    return struct {
        const Self = @This();

        raw: *volatile BackingT,

        pub fn at(address: usize) Self {
            return Self{ .raw = @ptrFromInt(address) };
        }

        pub inline fn read(self: Self) PackedT {
            return @bitCast(self.raw.*);
        }

        pub inline fn write(self: Self, value: PackedT) void {
            self.raw.* = @bitCast(value);
        }

        // TODO can we make the fields parameter aware of PackedT? maybe std.meta.FieldEnum? something like typescript's Partial<T>
        pub inline fn modify(self: Self, fields: anytype) void {
            var value = self.read();
            inline for (@typeInfo(@TypeOf(fields)).Struct.fields) |field| {
                @field(value, field.name) = @field(fields, field.name);
            }
            self.write(value);
        }

        pub inline fn has(self: Self, fields: anytype) bool {
            const value = self.read();
            inline for (@typeInfo(@TypeOf(fields)).Struct.fields) |field| {
                if (@field(value, field.name) != @field(fields, field.name))
                    return false;
            }
            return true;
        }
    };
}

pub fn Raw(comptime IntT: type) type {
    return struct {
        const Self = @This();

        raw: *volatile IntT,

        pub fn at(address: usize) Self {
            return Self{ .raw = @ptrFromInt(address) };
        }

        pub inline fn read(self: Self) IntT {
            return self.raw.*;
        }

        pub inline fn write(self: Self, value: IntT) void {
            self.raw.* = value;
        }

        /// Sets bits that are 1 in bitMask
        pub inline fn set(self: Self, bitMask: IntT) void {
            self.raw.* |= bitMask;
        }

        /// Clears bits that are 1 in bitMask
        pub inline fn clear(self: Self, bitMask: IntT) void {
            self.raw.* &= ~bitMask;
        }
    };
}
