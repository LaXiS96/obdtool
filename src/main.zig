const std = @import("std");
const trace = @import("trace.zig");
const rcc = @import("rcc.zig");
const gpio = @import("gpio.zig");
const can = @import("can.zig");
const usb = @import("usb.zig");

var trace_buf: [256]u8 = undefined;

pub fn main() !void {
    rcc.setupClock_InHse8_Out72();

    const led = gpio.Gpio.new(.PC, 13).asOutput(.output_2mhz, .pushpull);

    // TODO can is on the same pins as usb, also the 512B sram is shared
    // can.start();

    // Force USB reenumeration by pulling D+ (PA12) low for >50ms
    const usb_dp = gpio.Gpio.new(.PA, 12).asOutput(.output_2mhz, .pushpull);
    usb_dp.low();
    var i: u32 = 0;
    while (i < 500_000) i += 1;
    usb_dp.deinit();

    try usb.start();

    i = 0;
    while (true) {
        i += 1;
        // if (can.read()) |msg|
        //     trace.bufPrint(&trace_buf, "{d} {x}\n", .{ i, msg.id.standard });

        try usb.Device.task(true);

        if (i % 200_000 == 0)
            if (led.read())
                led.low()
            else
                led.high();
    }
}

pub const std_options = std.Options{
    .logFn = logFn,
};

fn logFn(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_txt = comptime level.asText();
    const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
    trace.bufPrint(&trace_buf, level_txt ++ prefix2 ++ format ++ "\n", args);
}

pub fn panic(message: []const u8, _: ?*std.builtin.StackTrace, _: ?usize) noreturn {
    // TODO disable interrupts

    trace.write("PANIC: ");
    trace.write(message);
    trace.write("\n");

    var index: usize = 0;
    var iter = std.debug.StackIterator.init(@returnAddress(), null);
    while (iter.next()) |address| : (index += 1)
        trace.bufPrint(&trace_buf, "{d: >3}: 0x{x:0>8}", .{ index, address });

    while (true)
        @breakpoint();
}

extern var _data_start: u8;
extern var _data_end: u8;
extern var _bss_start: u8;
extern var _bss_end: u8;
extern const _data_loadaddr: u8;
extern const _stack: u8;

// See ARMv7-M Architecture Reference Manual B1.5
// See STM32F1 Reference Manual RM0008 10.1.2
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

export fn _start() noreturn {
    const data_len = @intFromPtr(&_data_end) - @intFromPtr(&_data_start);
    const data_load: [*]const u8 = @ptrCast(&_data_loadaddr);
    const data: [*]u8 = @ptrCast(&_data_start);
    @memcpy(data[0..data_len], data_load);

    const bss_len = @intFromPtr(&_bss_end) - @intFromPtr(&_bss_start);
    const bss: [*]u8 = @ptrCast(&_bss_start);
    @memset(bss[0..bss_len], 0);

    main() catch |err| @panic(std.fmt.bufPrint(&trace_buf, "main returned error: {s}", .{@errorName(err)}) catch &trace_buf);

    @panic("main returned");
}

export fn null_handler() void {}

export fn hard_fault_handler() void {
    @panic("hard fault");
}

export fn mem_manage_handler() void {
    @panic("memory management fault");
}

export fn bus_fault_handler() void {
    @panic("bus fault");
}

export fn usage_fault_handler() void {
    @panic("usage fault");
}
