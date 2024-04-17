const std = @import("std");
const trace = @import("trace.zig");

var trace_buf: [256]u8 = undefined;

pub fn main() !void {
    var i: u32 = 0;
    while (true) {
        i += 1;
        trace.bufPrint(&trace_buf, "{d}\n", .{i});
    }
}

extern var _data_start: u8;
extern var _data_end: u8;
extern var _bss_start: u8;
extern var _bss_end: u8;
extern const _data_loadaddr: u8;
extern const _stack: u8;

// See ARMv7-M Architecture Reference Manual B1.5
const VectorHandler = *const fn () callconv(.C) void;
export const vector_table: extern struct {
    stack_pointer: *const u8 = &_stack,
    reset: *const fn () callconv(.C) noreturn = _start,
    nmi: VectorHandler = null_handler,
    hard_fault: VectorHandler = hard_fault_handler,
    mem_manage: VectorHandler = mem_manage_handler,
    bus_fault: VectorHandler = bus_fault_handler,
    usage_fault: VectorHandler = usage_fault_handler,
    _reserved1: [4]usize = [_]usize{ 0, 0, 0, 0 },
    sv_call: VectorHandler = null_handler,
    debug_monitor: VectorHandler = null_handler,
    _reserved2: usize = 0,
    pend_sv: VectorHandler = null_handler,
    systick: VectorHandler = null_handler,
} linksection(".vector_table") = .{};

export fn _start() callconv(.C) noreturn {
    const data_len = @intFromPtr(&_data_end) - @intFromPtr(&_data_start);
    const data_load: [*]const u8 = @ptrCast(&_data_loadaddr);
    const data: [*]u8 = @ptrCast(&_data_start);
    @memcpy(data[0..data_len], data_load);

    const bss_len = @intFromPtr(&_bss_end) - @intFromPtr(&_bss_start);
    const bss: [*]u8 = @ptrCast(&_bss_start);
    @memset(bss[0..bss_len], 0);

    // TODO log on panic via SWO trace (std logFn ?)
    main() catch @panic("main returned");

    while (true)
        @breakpoint();
}

export fn null_handler() void {}

export fn hard_fault_handler() void {
    trace.write("hard fault");
    while (true) {
        @breakpoint();
    }
}

export fn mem_manage_handler() void {
    trace.write("memory management fault");
    while (true) {
        @breakpoint();
    }
}

export fn bus_fault_handler() void {
    trace.write("bus fault");
    while (true) {
        @breakpoint();
    }
}

export fn usage_fault_handler() void {
    trace.write("usage fault");
    while (true) {
        @breakpoint();
    }
}
