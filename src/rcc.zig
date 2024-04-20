const mmio = @import("mmio.zig");

pub const RCC = struct {
    pub const CR = mmio.Mmio(packed struct(u32) {
        HSION: bool,
        HSIRDY: bool,
        _reserved1: u1,
        HSITRIM: u5,
        HSICAL: u8,
        HSEON: bool,
        HSERDY: bool,
        HSEBYP: bool,
        CSSON: bool,
        _reserved2: u4,
        PLLON: bool,
        PLLRDY: bool,
        _reserved3: u6,
    }).at(0x4002_1000);

    pub const CFGR = mmio.Mmio(packed struct(u32) {
        SW: enum(u2) { HSI, HSE, PLL },
        SWS: enum(u2) { HSI, HSE, PLL },
        HPRE: enum(u4) { no_div, div_2 = 0b1000, div_4, div_8, div_16, div_64, div_128, div_256, div_512 },
        PPRE1: enum(u3) { no_div, div_2 = 0b100, div_4, div_8, div_16 },
        PPRE2: enum(u3) { no_div, div_2 = 0b100, div_4, div_8, div_16 },
        ADCPRE: enum(u2) { div_2, div_4, div_6, div_8 },
        PLLSRC: enum(u1) { HSI_div_2, HSE },
        PLLXTPRE: enum(u1) { HSE_no_div, HSE_div_2 },
        PLLMUL: enum(u4) { mul_2, mul_3, mul_4, mul_5, mul_6, mul_7, mul_8, mul_9, mul_10, mul_11, mul_12, mul_13, mul_14, mul_15, mul_16 },
        USBPRE: enum(u1) { PLL_div_1dot5, PLL_no_div },
        _reserved1: u1,
        MCO: enum(u3) { no_out, SYSCLK_out = 0b100, HSI_out, HSE_out, PLL_div_2_out },
        _reserved2: u5,
    }).at(0x4002_1004);

    pub const AHBENR = mmio.Mmio(packed struct(u32) {
        DMA1EN: bool,
        DMA2EN: bool,
        SRAMEN: bool,
        _reserved1: u1,
        FLITFEN: bool,
        _reserved2: u1,
        CRCEN: bool,
        _reserved3: u1,
        FSMCEN: bool,
        _reserved4: u1,
        SDIOEN: bool,
        _reserved5: u21,
    }).at(0x4002_1014);

    pub const APB2ENR = mmio.Mmio(packed struct(u32) {
        AFIOEN: bool,
        _reserved1: u1,
        IOPAEN: bool,
        IOPBEN: bool,
        IOPCEN: bool,
        IOPDEN: bool,
        IOPEEN: bool,
        IOPFEN: bool,
        IOPGEN: bool,
        ADC1EN: bool,
        ADC2EN: bool,
        TIM1EN: bool,
        SPI1EN: bool,
        TIM8EN: bool,
        USART1EN: bool,
        ADC3EN: bool,
        _reserved2: u3,
        TIM9EN: bool,
        TIM10EN: bool,
        TIM11EN: bool,
        _reserved3: u10,
    }).at(0x4002_1018);

    pub const APB1ENR = mmio.Mmio(packed struct(u32) {
        TIM2EN: bool,
        TIM3EN: bool,
        TIM4EN: bool,
        TIM5EN: bool,
        TIM6EN: bool,
        TIM7EN: bool,
        TIM12EN: bool,
        TIM13EN: bool,
        TIM14EN: bool,
        _reserved1: u2,
        WWDGEN: bool,
        _reserved2: u2,
        SPI2EN: bool,
        SPI3EN: bool,
        _reserved3: u1,
        USART2EN: bool,
        USART3EN: bool,
        UART4EN: bool,
        UART5EN: bool,
        I2C1EN: bool,
        I2C2EN: bool,
        USBEN: bool,
        _reserved4: u1,
        CANEN: bool,
        _reserved5: u1,
        BKPEN: bool,
        PWREN: bool,
        DACEN: bool,
        _reserved6: u2,
    }).at(0x4002_101c);
};

pub const FLASH = struct {
    pub const ACR = mmio.Mmio(packed struct(u32) {
        LATENCY: enum(u3) { wait_states_0, wait_states_1, wait_states_2 },
        HLFCYA: u1,
        PRFTBE: u1,
        PRFTBS: u1,
        _reserved: u26,
    }).at(0x4002_2000);
};

pub var ahb_freq: u32 = 8_000_000;
pub var apb1_freq: u32 = 8_000_000;
pub var apb2_freq: u32 = 8_000_000;

pub fn setupClock_InHse8_Out72() void {
    RCC.CR.modify(.{ .HSEON = true });
    while (!RCC.CR.has(.{ .HSERDY = true })) {}

    RCC.CFGR.modify(.{
        .HPRE = .no_div, // AHB = SYSCLK / 1
        .PPRE1 = .div_2, // APB1 = AHB / 2
        .PPRE2 = .no_div, // APB2 = AHB / 1
        .ADCPRE = .div_6, // ADC = APB2 / 6
        .PLLSRC = .HSE, // HSE into PLL
        .PLLXTPRE = .HSE_no_div, // HSE / 1
        .PLLMUL = .mul_9, // HSE * 9
    });
    FLASH.ACR.modify(.{ .LATENCY = .wait_states_2 });

    RCC.CR.modify(.{ .PLLON = true });
    while (!RCC.CR.has(.{ .PLLRDY = true })) {}
    RCC.CFGR.modify(.{ .SW = .PLL }); // Switch to PLL as SYSCLK
    while (!RCC.CFGR.has(.{ .SWS = .PLL })) {}

    ahb_freq = 72_000_000;
    apb1_freq = 36_000_000;
    apb2_freq = 72_000_000;
}
