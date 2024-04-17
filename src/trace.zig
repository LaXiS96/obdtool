const std = @import("std");

// Note: the tracing subsystem is enabled by the connected debugger as needed

// See Cortex-M3 Technical Reference Manual 9.3
// On Cortex-M3 there are only 32 stimulus ports = one TER
const ITM_BASE_ADDR = 0xe000_0000;
const ITM_STIM: *volatile [32]u32 = @ptrFromInt(ITM_BASE_ADDR);
const ITM_TER: *volatile u32 = @ptrFromInt(ITM_BASE_ADDR + 0xe00);
const STIM_FIFOREADY: u32 = 1 << 0;

inline fn isStimEnabled(stim_port: u5) bool {
    return ITM_TER.* & (@as(u32, 1) << stim_port) != 0;
}

fn send8_blocking(stim_port: u5, c: u8) void {
    if (!isStimEnabled(stim_port))
        return;

    while (ITM_STIM[stim_port] & STIM_FIFOREADY == 0) {}
    ITM_STIM[stim_port] = c;
}

pub fn allocPrint(allocator: std.mem.Allocator, comptime fmt: []const u8, args: anytype) void {
    if (!isStimEnabled(0))
        return;

    const slice = std.fmt.allocPrint(allocator, fmt, args) catch return;
    defer allocator.free(slice);
    for (slice) |c|
        send8_blocking(0, c);
}

pub fn bufPrint(buf: []u8, comptime fmt: []const u8, args: anytype) void {
    if (!isStimEnabled(0))
        return;

    const slice = std.fmt.bufPrint(buf, fmt, args) catch return;
    for (slice) |c|
        send8_blocking(0, c);
}

pub fn write(str: []const u8) void {
    if (!isStimEnabled(0))
        return;

    for (str) |c|
        send8_blocking(0, c);
}
