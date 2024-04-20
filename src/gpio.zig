const mmio = @import("mmio.zig");

pub const GPIO = struct {
    const GPIOA_BASE = 0x4001_0800;
    const GPIOB_BASE = 0x4001_0c00;
    const GPIOC_BASE = 0x4001_1000;
    const GPIOD_BASE = 0x4001_1400;
    const GPIOE_BASE = 0x4001_1800;
    const GPIOF_BASE = 0x4001_1c00;
    const GPIOG_BASE = 0x4001_2000;

    const MODE = enum(u2) { input, output_10mhz, output_2mhz, output_50mhz };
    const CNF = packed union {
        input: enum(u2) { analog, floating, pull },
        output: enum(u2) { pushpull, opendrain, alternate_pushpull, alternate_opendrain },
    };

    const GPIOx_CRL = packed struct(u32) { MODE0: MODE, CNF0: CNF, MODE1: MODE, CNF1: CNF, MODE2: MODE, CNF2: CNF, MODE3: MODE, CNF3: CNF, MODE4: MODE, CNF4: CNF, MODE5: MODE, CNF5: CNF, MODE6: MODE, CNF6: CNF, MODE7: MODE, CNF7: CNF };
    pub const GPIOA_CRL = mmio.Mmio(GPIOx_CRL).at(GPIOA_BASE);
    pub const GPIOB_CRL = mmio.Mmio(GPIOx_CRL).at(GPIOB_BASE);
    pub const GPIOC_CRL = mmio.Mmio(GPIOx_CRL).at(GPIOC_BASE);
    pub const GPIOD_CRL = mmio.Mmio(GPIOx_CRL).at(GPIOD_BASE);
    pub const GPIOE_CRL = mmio.Mmio(GPIOx_CRL).at(GPIOE_BASE);
    pub const GPIOF_CRL = mmio.Mmio(GPIOx_CRL).at(GPIOF_BASE);
    pub const GPIOG_CRL = mmio.Mmio(GPIOx_CRL).at(GPIOG_BASE);

    const GPIOx_CRH = packed struct(u32) { MODE8: MODE, CNF8: CNF, MODE9: MODE, CNF9: CNF, MODE10: MODE, CNF10: CNF, MODE11: MODE, CNF11: CNF, MODE12: MODE, CNF12: CNF, MODE13: MODE, CNF13: CNF, MODE14: MODE, CNF14: CNF, MODE15: MODE, CNF15: CNF };
    pub const GPIOA_CRH = mmio.Mmio(GPIOx_CRH).at(GPIOA_BASE + 0x04);
    pub const GPIOB_CRH = mmio.Mmio(GPIOx_CRH).at(GPIOB_BASE + 0x04);
    pub const GPIOC_CRH = mmio.Mmio(GPIOx_CRH).at(GPIOC_BASE + 0x04);
    pub const GPIOD_CRH = mmio.Mmio(GPIOx_CRH).at(GPIOD_BASE + 0x04);
    pub const GPIOE_CRH = mmio.Mmio(GPIOx_CRH).at(GPIOE_BASE + 0x04);
    pub const GPIOF_CRH = mmio.Mmio(GPIOx_CRH).at(GPIOF_BASE + 0x04);
    pub const GPIOG_CRH = mmio.Mmio(GPIOx_CRH).at(GPIOG_BASE + 0x04);

    const GPIOx_IDR = packed struct(u32) { IDR0: u1, IDR1: u1, IDR2: u1, IDR3: u1, IDR4: u1, IDR5: u1, IDR6: u1, IDR7: u1, IDR8: u1, IDR9: u1, IDR10: u1, IDR11: u1, IDR12: u1, IDR13: u1, IDR14: u1, IDR15: u1, _reserved: u16 };
    pub const GPIOA_IDR = mmio.Mmio(GPIOx_IDR).at(GPIOA_BASE + 0x08);
    pub const GPIOB_IDR = mmio.Mmio(GPIOx_IDR).at(GPIOB_BASE + 0x08);
    pub const GPIOC_IDR = mmio.Mmio(GPIOx_IDR).at(GPIOC_BASE + 0x08);
    pub const GPIOD_IDR = mmio.Mmio(GPIOx_IDR).at(GPIOD_BASE + 0x08);
    pub const GPIOE_IDR = mmio.Mmio(GPIOx_IDR).at(GPIOE_BASE + 0x08);
    pub const GPIOF_IDR = mmio.Mmio(GPIOx_IDR).at(GPIOF_BASE + 0x08);
    pub const GPIOG_IDR = mmio.Mmio(GPIOx_IDR).at(GPIOG_BASE + 0x08);

    const GPIOx_ODR = packed struct(u32) { ODR0: u1, ODR1: u1, ODR2: u1, ODR3: u1, ODR4: u1, ODR5: u1, ODR6: u1, ODR7: u1, ODR8: u1, ODR9: u1, ODR10: u1, ODR11: u1, ODR12: u1, ODR13: u1, ODR14: u1, ODR15: u1, _reserved: u16 };
    pub const GPIOA_ODR = mmio.Mmio(GPIOx_ODR).at(GPIOA_BASE + 0x0c);
    pub const GPIOB_ODR = mmio.Mmio(GPIOx_ODR).at(GPIOB_BASE + 0x0c);
    pub const GPIOC_ODR = mmio.Mmio(GPIOx_ODR).at(GPIOC_BASE + 0x0c);
    pub const GPIOD_ODR = mmio.Mmio(GPIOx_ODR).at(GPIOD_BASE + 0x0c);
    pub const GPIOE_ODR = mmio.Mmio(GPIOx_ODR).at(GPIOE_BASE + 0x0c);
    pub const GPIOF_ODR = mmio.Mmio(GPIOx_ODR).at(GPIOF_BASE + 0x0c);
    pub const GPIOG_ODR = mmio.Mmio(GPIOx_ODR).at(GPIOG_BASE + 0x0c);
};

// TODO add api
