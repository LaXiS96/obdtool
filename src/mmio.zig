const std = @import("std");

pub fn Mmio(comptime PackedT: type) type {
    _ = switch (@bitSizeOf(PackedT)) {
        8, 16, 32 => true,
        else => @compileError("non-aligned bit size"),
    };

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

pub fn Bits(comptime IntT: type) type {
    _ = switch (@bitSizeOf(IntT)) {
        8, 16, 32 => true,
        else => @compileError("non-aligned bit size"),
    };

    if (@typeInfo(IntT) != .Int) @compileError("IntT must be an integer type");

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

        /// Sets bits that are 1 in bit_mask
        pub inline fn set(self: Self, bit_mask: IntT) void {
            self.raw.* |= bit_mask;
        }

        /// Clears bits that are 1 in bit_mask
        pub inline fn clear(self: Self, bit_mask: IntT) void {
            self.raw.* &= ~bit_mask;
        }
    };
}
