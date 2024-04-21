const mmio = @import("mmio.zig");
const rcc = @import("rcc.zig");
const gpio = @import("gpio.zig");

pub const CAN = struct {
    const CAN_BASE = 0x4000_6400;

    pub const MCR = mmio.Mmio(packed struct(u32) {
        INRQ: bool,
        SLEEP: bool,
        TXFP: enum(u1) { priority_by_identifier, priority_by_request_order },
        RFLM: enum(u1) { overwrite_on_overrun, discard_on_overrun },
        NART: enum(u1) { auto_retransmit, no_retransmit },
        AWUM: enum(u1) { no_auto_wake, wake_on_bus_activity },
        ABOM: enum(u1) { no_auto_recovery, auto_busoff_recovery },
        TTCM: enum(u1) { ttc_disabled, ttc_enabled },
        _reserved1: u7,
        RESET: bool,
        DBF: enum(u1) { working, freeze_while_debugging },
        _reserved2: u15,
    }).at(CAN_BASE);

    pub const MSR = mmio.Mmio(packed struct(u32) {
        INAK: bool,
        SLAK: bool,
        ERRI: bool,
        WKUI: bool,
        SLAKI: bool,
        _reserved1: u3,
        TXM: bool,
        RXM: bool,
        SAMP: u1,
        RX: u1,
        _reserved2: u20,
    }).at(CAN_BASE + 0x4);

    pub const TSR = mmio.Mmio(packed struct(u32) {
        RQCP0: bool,
        TXOK0: bool,
        ALST0: bool,
        TERR0: bool,
        _reserved1: u3,
        ABRQ0: bool,
        RQCP1: bool,
        TXOK1: bool,
        ALST1: bool,
        TERR1: bool,
        _reserved2: u3,
        ABRQ1: bool,
        RQCP2: bool,
        TXOK2: bool,
        ALST2: bool,
        TERR2: bool,
        _reserved3: u3,
        ABRQ2: bool,
        CODE: u2,
        TME0: bool,
        TME1: bool,
        TME2: bool,
        LOW0: bool,
        LOW1: bool,
        LOW2: bool,
    }).at(CAN_BASE + 0x8);

    const RFxR = packed struct(u32) {
        FMP: u2,
        _reserved1: u1,
        FULL: bool,
        FOVR: bool,
        RFOM: bool,
        _reserved2: u26,
    };
    pub const RF0R = mmio.Mmio(RFxR).at(CAN_BASE + 0x0c);
    pub const RF1R = mmio.Mmio(RFxR).at(CAN_BASE + 0x10);

    pub const BTR = mmio.Mmio(packed struct(u32) {
        BRP: u10,
        _reserved1: u6,
        TS1: u4,
        TS2: u3,
        _reserved2: u1,
        SJW: u2,
        _reserved3: u4,
        LBKM: enum(u1) { loopback_disabled, loopback_enabled },
        SILM: enum(u1) { normal, silent },
    }).at(CAN_BASE + 0x1c);

    const RIxR = packed struct(u32) {
        _reserved1: u1,
        RTR: enum(u1) { data, remote },
        IDE: enum(u1) { standard, extended },
        ID: packed union {
            EXID: u29,
            ST: packed struct {
                _: u18,
                STID: u11,
            },
        },
    };
    pub const RI0R = mmio.Mmio(RIxR).at(CAN_BASE + 0x1b0);
    pub const RI1R = mmio.Mmio(RIxR).at(CAN_BASE + 0x1c0);

    const RDTxR = packed struct(u32) {
        DLC: u4,
        _reserved1: u4,
        FMI: u8,
        TIME: u16,
    };
    pub const RDT0R = mmio.Mmio(RDTxR).at(CAN_BASE + 0x1b4);
    pub const RDT1R = mmio.Mmio(RDTxR).at(CAN_BASE + 0x1c4);

    const RDLxR = packed struct(u32) {
        DATA0: u8,
        DATA1: u8,
        DATA2: u8,
        DATA3: u8,
    };
    pub const RDL0R = mmio.Mmio(RDLxR).at(CAN_BASE + 0x1b8);
    pub const RDL1R = mmio.Mmio(RDLxR).at(CAN_BASE + 0x1c8);

    const RDHxR = packed struct(u32) {
        DATA4: u8,
        DATA5: u8,
        DATA6: u8,
        DATA7: u8,
    };
    pub const RDH0R = mmio.Mmio(RDHxR).at(CAN_BASE + 0x1bc);
    pub const RDH1R = mmio.Mmio(RDHxR).at(CAN_BASE + 0x1cc);

    pub const FMR = mmio.Mmio(packed struct(u32) {
        FINIT: bool,
        _reserved1: u7,
        CAN2SB: u6,
        _reserved2: u18,
    }).at(CAN_BASE + 0x200);

    pub const FM1R = mmio.Bits(u32).at(CAN_BASE + 0x204);
    pub const FS1R = mmio.Bits(u32).at(CAN_BASE + 0x20c);
    pub const FFA1R = mmio.Bits(u32).at(CAN_BASE + 0x214);
    pub const FA1R = mmio.Bits(u32).at(CAN_BASE + 0x21c);

    pub const FiRx: *volatile [28 * 2]u32 = @ptrFromInt(CAN_BASE + 0x240);
};

const CanMessage = struct {
    timestamp: u16,
    id: packed union {
        standard: u11,
        extended: u29,
    },
    length: u4,
    data: [8]u8,
};

// TODO baudrate parameter
pub fn start() void {
    rcc.RCC.APB2ENR.modify(.{ .AFIOEN = true, .IOPAEN = true });
    rcc.RCC.APB1ENR.modify(.{ .CANEN = true });

    // Set up GPIOs (CANTX: PA12, CANRX: PA11)
    _ = gpio.Gpio.new(.PA, 12).asOutput(.output_2mhz, .alternate_pushpull);
    gpio.Gpio.new(.PA, 11).asInput(.pull).high();

    // CAN peripheral starts in sleep mode after hardware reset
    CAN.MCR.modify(.{ .SLEEP = false });
    // Switch to initialization mode
    CAN.MCR.modify(.{ .INRQ = true });
    while (!CAN.MSR.has(.{ .INAK = true })) {}

    // Setup peripheral
    // TODO MCR

    // http://www.bittiming.can-wiki.info/ Type: bxCAN, Clock: 36MHz, max brp: 1024, SP: 87.5%, min tq: 8, max tq: 25, FD factor: undefined, SJW: 1
    // Values from calculator must be reduced by 1 when written to registers
    // See STM32F1 Reference Manual 24.7.7
    CAN.BTR.modify(.{ .BRP = 3, .TS1 = 14, .TS2 = 1, .SJW = 0 }); // 500Kbps

    // At least one filter must be setup to receive messages
    // TODO filters can be changed after entering normal mode (messages are not received if FINIT=1)
    setupFilter();

    // Switch to normal mode
    CAN.MCR.modify(.{ .INRQ = false });
    while (!CAN.MSR.has(.{ .INAK = false })) {}
}

fn setupFilter() void {
    CAN.FMR.modify(.{ .FINIT = true }); // Enter filter initialization mode

    const filter = 0;
    const filter_mask = 1 << filter;
    CAN.FM1R.clear(filter_mask); // Identifier mask
    CAN.FS1R.set(filter_mask); // Single 32bit filter
    CAN.FFA1R.clear(filter_mask); // Assign to FIFO0

    // TODO make dynamic based on filter and scale+mode (see RM Figure 230)
    CAN.FiRx[0] = 0; // Clear filter 0 ID
    CAN.FiRx[1] = 0; // Clear filter 0 mask

    CAN.FA1R.set(filter_mask); // Enable filter
    CAN.FMR.modify(.{ .FINIT = false }); // Exit filter initialization mode
}

// TODO return message as pointer in heap or struct by value?
pub fn read() ?CanMessage {
    // Two FIFOs, each FIFO can store three messages and has its own output mailbox
    if (CAN.RF0R.read().FMP > 0) {
        const ir = CAN.RI0R.read();
        const tr = CAN.RDT0R.read();
        const dhr = CAN.RDH0R.read();
        const dlr = CAN.RDL0R.read();

        const msg = CanMessage{
            .timestamp = tr.TIME,
            .id = if (ir.IDE == .standard) .{ .standard = ir.ID.ST.STID } else .{ .extended = ir.ID.EXID },
            .length = tr.DLC,
            .data = [_]u8{ dlr.DATA0, dlr.DATA1, dlr.DATA2, dlr.DATA3, dhr.DATA4, dhr.DATA5, dhr.DATA6, dhr.DATA7 },
        };

        // Release output mailbox
        CAN.RF0R.modify(.{ .RFOM = true });

        return msg;
    }

    return null;
}
