const mmio = @import("mmio.zig");
const rcc = @import("rcc.zig");

pub const GPIO = struct {
    const GPIOA_base = 0x4001_0800;
    const GPIOB_base = 0x4001_0c00;
    const GPIOC_base = 0x4001_1000;
    const GPIOD_base = 0x4001_1400;
    const GPIOE_base = 0x4001_1800;
    const GPIOF_base = 0x4001_1c00;
    const GPIOG_base = 0x4001_2000;

    const CRL_offset = 0x00;
    const CRH_offset = 0x04;
    const IDR_offset = 0x08;
    const ODR_offset = 0x0c;
    const BSRR_offset = 0x10;
    const BRR_offset = 0x14;

    // pub const GPIOA_CRL = mmio.Bits(u32).at(GPIOA_base + GPIOx_CRL_offset);
    // pub const GPIOB_CRL = mmio.Bits(u32).at(GPIOB_base + GPIOx_CRL_offset);
    // pub const GPIOC_CRL = mmio.Bits(u32).at(GPIOC_base + GPIOx_CRL_offset);
    // pub const GPIOD_CRL = mmio.Bits(u32).at(GPIOD_base + GPIOx_CRL_offset);
    // pub const GPIOE_CRL = mmio.Bits(u32).at(GPIOE_base + GPIOx_CRL_offset);
    // pub const GPIOF_CRL = mmio.Bits(u32).at(GPIOF_base + GPIOx_CRL_offset);
    // pub const GPIOG_CRL = mmio.Bits(u32).at(GPIOG_base + GPIOx_CRL_offset);

    // pub const GPIOA_CRH = mmio.Bits(u32).at(GPIOA_base + GPIOx_CRH_offset);
    // pub const GPIOB_CRH = mmio.Bits(u32).at(GPIOB_base + GPIOx_CRH_offset);
    // pub const GPIOC_CRH = mmio.Bits(u32).at(GPIOC_base + GPIOx_CRH_offset);
    // pub const GPIOD_CRH = mmio.Bits(u32).at(GPIOD_base + GPIOx_CRH_offset);
    // pub const GPIOE_CRH = mmio.Bits(u32).at(GPIOE_base + GPIOx_CRH_offset);
    // pub const GPIOF_CRH = mmio.Bits(u32).at(GPIOF_base + GPIOx_CRH_offset);
    // pub const GPIOG_CRH = mmio.Bits(u32).at(GPIOG_base + GPIOx_CRH_offset);

    // pub const GPIOA_IDR = mmio.Bits(u32).at(GPIOA_base + GPIOx_IDR_offset);
    // pub const GPIOB_IDR = mmio.Bits(u32).at(GPIOB_base + GPIOx_IDR_offset);
    // pub const GPIOC_IDR = mmio.Bits(u32).at(GPIOC_base + GPIOx_IDR_offset);
    // pub const GPIOD_IDR = mmio.Bits(u32).at(GPIOD_base + GPIOx_IDR_offset);
    // pub const GPIOE_IDR = mmio.Bits(u32).at(GPIOE_base + GPIOx_IDR_offset);
    // pub const GPIOF_IDR = mmio.Bits(u32).at(GPIOF_base + GPIOx_IDR_offset);
    // pub const GPIOG_IDR = mmio.Bits(u32).at(GPIOG_base + GPIOx_IDR_offset);

    // pub const GPIOA_ODR = mmio.Bits(u32).at(GPIOA_base + GPIOx_ODR_offset);
    // pub const GPIOB_ODR = mmio.Bits(u32).at(GPIOB_base + GPIOx_ODR_offset);
    // pub const GPIOC_ODR = mmio.Bits(u32).at(GPIOC_base + GPIOx_ODR_offset);
    // pub const GPIOD_ODR = mmio.Bits(u32).at(GPIOD_base + GPIOx_ODR_offset);
    // pub const GPIOE_ODR = mmio.Bits(u32).at(GPIOE_base + GPIOx_ODR_offset);
    // pub const GPIOF_ODR = mmio.Bits(u32).at(GPIOF_base + GPIOx_ODR_offset);
    // pub const GPIOG_ODR = mmio.Bits(u32).at(GPIOG_base + GPIOx_ODR_offset);
};

pub const Port = enum(u3) { PA, PB, PC, PD, PE, PF, PG };

pub const Gpio = struct {
    const Self = @This();

    // TODO this is not optimized for memory efficiency
    port: Port,
    port_base: usize,
    pin: u4,
    pin_mask: u16,

    const InputMode = enum(u2) { input };
    const InputConf = enum(u2) { analog, floating, pull };
    const OutputMode = enum(u2) { output_10mhz = 1, output_2mhz, output_50mhz };
    const OutputConf = enum(u2) { pushpull, opendrain, alternate_pushpull, alternate_opendrain };

    pub fn new(port: Port, pin: u4) Self {
        return Self{
            .port = port,
            .port_base = switch (port) {
                .PA => GPIO.GPIOA_base,
                .PB => GPIO.GPIOB_base,
                .PC => GPIO.GPIOC_base,
                .PD => GPIO.GPIOD_base,
                .PE => GPIO.GPIOE_base,
                .PF => GPIO.GPIOF_base,
                .PG => GPIO.GPIOG_base,
            },
            .pin = pin,
            .pin_mask = @as(u16, 1) << pin,
        };
    }

    fn setup(self: Self, mode: u2, conf: u2) void {
        _ = switch (self.port) {
            .PA => rcc.RCC.APB2ENR.modify(.{ .IOPAEN = true }),
            .PB => rcc.RCC.APB2ENR.modify(.{ .IOPBEN = true }),
            .PC => rcc.RCC.APB2ENR.modify(.{ .IOPCEN = true }),
            .PD => rcc.RCC.APB2ENR.modify(.{ .IOPDEN = true }),
            .PE => rcc.RCC.APB2ENR.modify(.{ .IOPEEN = true }),
            .PF => rcc.RCC.APB2ENR.modify(.{ .IOPFEN = true }),
            .PG => rcc.RCC.APB2ENR.modify(.{ .IOPGEN = true }),
        };

        var cr: *volatile u32 = undefined;
        var offset: u5 = undefined;
        if (self.pin > 7) {
            cr = @ptrFromInt(self.port_base + GPIO.CRH_offset);
            offset = (@as(u5, self.pin) - 8) * 4;
        } else {
            cr = @ptrFromInt(self.port_base + GPIO.CRL_offset);
            offset = @as(u5, self.pin) * 4;
        }

        var cr_value = cr.*;
        cr_value &= ~(@as(u32, 0b1111) << offset);
        cr_value |= @as(u32, (@as(u4, conf) << 2) | @as(u4, mode)) << offset;
        cr.* = cr_value;
    }

    pub fn asInput(self: Self, conf: InputConf) Self {
        setup(self, @intFromEnum(InputMode.input), @intFromEnum(conf));
        return self;
    }

    pub fn asOutput(self: Self, mode: OutputMode, conf: OutputConf) Self {
        setup(self, @intFromEnum(mode), @intFromEnum(conf));
        return self;
    }

    pub fn deinit(self: Self) void {
        self.setup(@intFromEnum(InputMode.input), @intFromEnum(InputConf.floating));
    }

    pub inline fn read(self: Self) bool {
        @setRuntimeSafety(false);
        return (@as(*volatile u32, @ptrFromInt(self.port_base + GPIO.IDR_offset)).* & self.pin_mask) > 0;
    }

    pub inline fn high(self: Self) void {
        @setRuntimeSafety(false);
        @as(*volatile u32, @ptrFromInt(self.port_base + GPIO.BSRR_offset)).* = self.pin_mask;
    }

    pub inline fn low(self: Self) void {
        @setRuntimeSafety(false);
        @as(*volatile u32, @ptrFromInt(self.port_base + GPIO.BSRR_offset)).* = @as(u32, self.pin_mask) << 16;
    }

    // TODO api to set and reset multiple gpios atomically via BSRR
};
