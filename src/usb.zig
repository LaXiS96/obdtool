const std = @import("std");
const mmio = @import("mmio.zig");
const rcc = @import("rcc.zig");
const usb = @import("vendor/usb.zig");

/// USB MMIO registers
const USB = struct {
    const USB_base = 0x4000_5c00;
    const packet_memory_base = 0x4000_6000;

    const EPnR_STAT_T = enum(u2) { disabled, stall, nak, valid };
    const EPnR_EP_TYPE_T = enum(u2) { bulk, control, isochronous, interrupt };
    const EPnR_T = packed struct(u16) {
        EA: u4,
        STAT_TX: EPnR_STAT_T, // Toggle-only
        DTOG_TX: u1, // Toggle-only
        CTR_TX: bool, // Write 1 no effect, 0 to clear
        EP_KIND: bool,
        EP_TYPE: EPnR_EP_TYPE_T,
        SETUP: bool,
        STAT_RX: EPnR_STAT_T, // Toggle-only
        DTOG_RX: u1, // Toggle-only
        CTR_RX: bool, // Write 1 no effect, 0 to clear
    };
    /// Use to mask out bits that should not be modified in a read-modify-write operation (STAT, DTOG, CTR)
    const EPnR_mask = 0b0000_1111_0000_1111;
    const EPnR_CTR_mask = 0b1000_0000_1000_0000;
    const EPnR = [8]mmio.Mmio(EPnR_T){
        mmio.Mmio(EPnR_T).at(USB_base + 0x00),
        mmio.Mmio(EPnR_T).at(USB_base + 0x04),
        mmio.Mmio(EPnR_T).at(USB_base + 0x08),
        mmio.Mmio(EPnR_T).at(USB_base + 0x0c),
        mmio.Mmio(EPnR_T).at(USB_base + 0x10),
        mmio.Mmio(EPnR_T).at(USB_base + 0x14),
        mmio.Mmio(EPnR_T).at(USB_base + 0x18),
        mmio.Mmio(EPnR_T).at(USB_base + 0x1c),
    };

    const CNTR = mmio.Mmio(packed struct(u16) {
        FRES: bool,
        PDWN: bool,
        LP_MODE: bool,
        FSUSP: bool,
        RESUME: bool,
        _reserved1: u3,
        ESOFM: bool,
        SOFM: bool,
        RESETM: bool,
        SUSPM: bool,
        WKUPM: bool,
        ERRM: bool,
        PMAOVRM: bool,
        CTRM: bool,
    }).at(USB_base + 0x40);

    const ISTR = mmio.Mmio(packed struct(u16) {
        EP_ID: u4,
        DIR: enum(u1) { in, out },
        _reserved1: u3,
        ESOF: bool,
        SOF: bool,
        RESET: bool,
        SUSP: bool,
        WKUP: bool,
        ERR: bool,
        PMAOVR: bool,
        CTR: bool,
    }).at(USB_base + 0x44);

    const DADDR = mmio.Mmio(packed struct(u16) {
        ADD: u7,
        EF: bool,
        _reserved1: u8,
    }).at(USB_base + 0x4c);

    const BTABLE: *volatile u16 = @ptrFromInt(USB_base + 0x50);
};

const BufferTableEntry = struct {
    const Self = @This();

    const COUNTn_TX_T = mmio.Mmio(packed struct(u16) {
        COUNT: u10,
        _reserved1: u6,
    });
    const COUNTn_RX_T = mmio.Mmio(packed struct(u16) {
        COUNT: u10,
        NUM_BLOCK: u5,
        BL_SIZE: enum(u1) { _2_bytes, _32_bytes },
    });

    table: *BufferTable,
    ADDRn_TX: *volatile u16,
    COUNTn_TX: COUNTn_TX_T,
    ADDRn_RX: *volatile u16,
    COUNTn_RX: COUNTn_RX_T,

    pub fn at(table: *BufferTable, address: usize) Self {
        return Self{
            .table = table,
            .ADDRn_TX = @ptrFromInt(address),
            .COUNTn_TX = COUNTn_TX_T.at(address + 4),
            .ADDRn_RX = @ptrFromInt(address + 8),
            .COUNTn_RX = COUNTn_RX_T.at(address + 12),
        };
    }

    pub fn allocateRx(self: Self) void {
        // TODO accept size parameter, calculate COUNT register based on that size
        self.ADDRn_RX.* = self.table.allocateBuffer();
        self.COUNTn_RX.write(.{
            .COUNT = 63,
            .NUM_BLOCK = 1,
            .BL_SIZE = ._32_bytes, // BL_SIZE * (NUM_BLOCK+1) = bytes
        });
    }

    pub fn allocateTx(self: Self) void {
        self.ADDRn_TX.* = self.table.allocateBuffer();
    }
};

const BufferTable = struct {
    const Self = @This();

    address: usize,
    /// Top of allocated packet memory (USB-local offset)
    pm_top: u16 = 0x40, // 64bytes are allocated to the BufferTable itself

    pub fn at(address: usize) Self {
        // TODO btable must be 8-byte aligned
        USB.BTABLE.* = @intCast(address - USB.packet_memory_base);
        return Self{ .address = address };
    }

    pub fn getEntry(self: *Self, ep_index: u3) BufferTableEntry {
        const addr = self.address + (@as(usize, ep_index) * 16);
        return BufferTableEntry.at(self, addr);
    }

    /// Returns the USB-local offset of the next free buffer in packet memory
    pub fn allocateBuffer(self: *Self) u16 {
        // TODO accept size parameter
        const offset = self.pm_top;
        self.pm_top += 0x40;
        return offset;
    }
};

const Endpoint = struct {
    const Self = @This();

    /// Index of EPnR register
    index: u3,
    /// USB endpoint address
    address: u8,

    buffer: BufferTableEntry = undefined,

    pub fn init(self: *Self, ep_type: USB.EPnR_EP_TYPE_T) void {
        self.buffer = Driver.buffer_table.getEntry(self.index);

        self.updateMasked(.{
            .EA = @as(u4, @intCast(self.address & 0x0f)),
            .EP_TYPE = ep_type,
        });

        const dir = usb.Dir.of_endpoint_addr(self.address);
        if (dir == .In) {
            self.buffer.allocateTx();
            self.updateDtogTx(0);
            self.updateStatTx(.nak);
        } else {
            self.buffer.allocateRx();
            self.updateDtogRx(0);
            self.updateStatRx(.nak);
        }
    }

    pub fn read(self: Self, buffer: []u8) !void {
        const length = self.buffer.COUNTn_RX.read().COUNT;
        if (length > buffer.len)
            return error.BufferTooSmall;

        const packet: [*]u16 = @ptrFromInt(USB.packet_memory_base + (@as(usize, self.buffer.ADDRn_RX.*) * 2));
        var i: usize = 0;
        while (i < (length & ~@as(u10, 1))) : (i += 2) {
            buffer[i] = @truncate(packet[i]);
            buffer[i + 1] = @truncate(packet[i] >> 8);
        }
        if ((length & 1) == 1) // Copy last odd byte skipped above
            buffer[i] = @truncate(packet[i]);

        self.clearCtrRx();

        // TODO restore stat_rx to valid ???
    }

    pub fn write(self: Self, buffer: []const u8) !void {
        // TODO do we need to allocate arbitrary length buffers in packet memory? or is 64bytes enough per specifications?
        if (buffer.len > 64)
            return error.BufferTooLarge;

        // Set data length within the preallocated packet buffer
        self.buffer.COUNTn_TX.modify(.{ .COUNT = @as(u10, @intCast(buffer.len)) });

        // Copy data to packet memory
        var packet: [*]u16 = @ptrFromInt(USB.packet_memory_base + (@as(usize, self.buffer.ADDRn_TX.*) * 2));
        var i: usize = 0;
        while (i < (buffer.len & ~@as(u10, 1))) : (i += 2) {
            // Packet memory is written every 2 words, the odd words are skipped (0 being even)
            packet[i] = buffer[i] | (@as(u16, buffer[i + 1]) << 8);
        }
        if ((buffer.len & 1) == 1)
            packet[i] = buffer[i];

        // Enable transmission
        self.updateStatTx(.valid);
    }

    fn updateMasked(self: Self, fields: anytype) void {
        var ep = USB.EPnR[self.index].read();
        inline for (@typeInfo(@TypeOf(fields)).Struct.fields) |field| {
            @field(ep, field.name) = @field(fields, field.name);
        }
        // Mask out toggle-only bits, set CTR bits to avoid clearing them
        const ep_new = (@as(u16, @bitCast(ep)) & USB.EPnR_mask) | USB.EPnR_CTR_mask;
        USB.EPnR[self.index].writeRaw(ep_new);
    }

    fn updateToggle(self: Self, comptime field_name: []const u8, mask: anytype, value: anytype) void {
        // Read endpoint register, masking out toggle-only bits except those we want to change
        var ep = USB.EPnR[self.index].readRaw() & (USB.EPnR_mask | (mask << @bitOffsetOf(USB.EPnR_T, field_name)));
        // XOR with the new value to get only the bits that differ, set CTR bits
        ep ^= (value << @bitOffsetOf(USB.EPnR_T, field_name)) | USB.EPnR_CTR_mask;
        USB.EPnR[self.index].writeRaw(ep);
    }

    fn updateStatRx(self: Self, value: USB.EPnR_STAT_T) void {
        self.updateToggle("STAT_RX", 0b11, @as(u16, @intFromEnum(value)));
    }

    fn updateStatTx(self: Self, value: USB.EPnR_STAT_T) void {
        self.updateToggle("STAT_TX", 0b11, @as(u16, @intFromEnum(value)));
    }

    fn updateDtogRx(self: Self, value: u1) void {
        self.updateToggle("DTOG_RX", 0b1, @as(u16, value));
    }

    fn updateDtogTx(self: Self, value: u1) void {
        self.updateToggle("DTOG_TX", 0b1, @as(u16, value));
    }

    fn clearCtrRx(self: Self) void {
        var ep = (USB.EPnR[self.index].readRaw() & USB.EPnR_mask) | USB.EPnR_CTR_mask;
        ep &= ~(@as(u16, 1) << @bitOffsetOf(USB.EPnR_T, "CTR_RX"));
        USB.EPnR[self.index].writeRaw(ep);
    }

    fn clearCtrTx(self: Self) void {
        var ep = (USB.EPnR[self.index].readRaw() & USB.EPnR_mask) | USB.EPnR_CTR_mask;
        ep &= ~(@as(u16, 1) << @bitOffsetOf(USB.EPnR_T, "CTR_TX"));
        USB.EPnR[self.index].writeRaw(ep);
    }
};

const Driver = struct {
    var buffer_table: BufferTable = undefined;

    var endpoints = [_]Endpoint{
        Endpoint{ .index = 0, .address = usb.EP0_OUT_ADDR }, // Device.EP0_OUT_IDX
        Endpoint{ .index = 0, .address = usb.EP0_IN_ADDR }, // Device.EP0_IN_IDX
    };

    pub fn usb_init_clk() void {
        rcc.RCC.APB1ENR.modify(.{ .USBEN = true });
        // TODO should wait tSTARTUP from datasheet after clearing PDWN, before clearing FRES
        USB.CNTR.modify(.{ .PDWN = false, .FRES = false });
    }

    pub fn usb_init_device(_: *usb.DeviceConfiguration) void {
        // TODO
    }

    pub fn usb_start_tx(ep_config: *usb.EndpointConfiguration, data: []const u8) void {
        // TODO next_pid_1
        const ep = endpoints[ep_config.driver_ep_index];
        ep.write(data) catch @panic("usb tx error"); // TODO DONT PANIC
    }

    pub fn usb_start_rx(_: *usb.EndpointConfiguration, _: usize) void {
        // TODO
    }

    pub fn get_interrupts() usb.InterruptStatus {
        var istr = USB.ISTR.read();

        // Clear all CTR_TX interrupts
        while (istr.CTR) {
            if (istr.DIR == .out) break;
            endpoints[istr.EP_ID].clearCtrTx(); // TODO istr.EP_ID is not the correct index, but will work for endpoint 0
            istr = USB.ISTR.read();
        }

        return usb.InterruptStatus{
            .BuffStatus = istr.CTR, // TODO vendor says SOF???
            .BusReset = istr.RESET,
            .DevConnDis = false, // TODO
            .DevSuspend = istr.SUSP,
            .DevResumeFromHost = istr.WKUP,
            .SetupReq = USB.EPnR[0].read().SETUP,
        };
    }

    pub fn get_setup_packet() usb.SetupPacket {
        var buffer: [8]u8 = undefined;
        endpoints[0].read(&buffer) catch @panic("error reading setup packet"); // TODO DONT PANIC
        return @bitCast(buffer);
    }

    pub fn bus_reset() void {
        buffer_table = BufferTable.at(USB.packet_memory_base);
        endpoints[Device.EP0_OUT_IDX].init(.control);
        endpoints[Device.EP0_IN_IDX].init(.control);

        USB.DADDR.modify(.{ .EF = true });
        USB.ISTR.modify(.{ .RESET = false });
    }

    pub fn set_address(addr: u7) void {
        USB.DADDR.modify(.{ .ADD = addr });
    }

    pub fn get_EPBIter(_: *const usb.DeviceConfiguration) usb.EPBIter {
        // TODO
        return usb.EPBIter{
            .bufbits = 0,
            .device_config = undefined,
            .next = next,
        };
    }

    fn next(_: *usb.EPBIter) ?usb.EPB {
        // TODO
        return null;
    }
};
pub const Device = usb.Usb(Driver);

var device_config = usb.DeviceConfiguration{
    .device_descriptor = &device_descriptor,
    .interface_descriptor = &interface_descriptor,
    .config_descriptor = &config_descriptor,
    .lang_descriptor = &[_]u8{},
    .descriptor_strings = &[_][]u8{},
    .endpoints = &endpoint_configs,
};

const device_descriptor = usb.DeviceDescriptor{
    .descriptor_type = .Device,
    .bcd_usb = 0x02_00,
    .device_class = 0, // TODO
    .device_subclass = 0, // TODO
    .device_protocol = 0, // TODO
    .max_packet_size0 = 0, // TODO
    .vendor = 0, // TODO
    .product = 0, // TODO
    .bcd_device = 0, // TODO
    .manufacturer_s = 0, // TODO
    .product_s = 0, // TODO
    .serial_s = 0, // TODO
    .num_configurations = 0, // TODO
};
const interface_descriptor = usb.InterfaceDescriptor{
    .descriptor_type = .Interface,
    .interface_number = 0, // TODO
    .alternate_setting = 0,
    .num_endpoints = 0, // TODO
    .interface_class = 0, // TODO
    .interface_subclass = 0, // TODO
    .interface_protocol = 0, // TODO
    .interface_s = 0, // TODO
};
const config_descriptor = usb.ConfigurationDescriptor{
    .descriptor_type = .Config,
    .total_length = 0, // TODO
    .num_interfaces = 0, // TODO
    .configuration_value = 0, // TODO
    .configuration_s = 0, // TODO
    .attributes = 0, // TODO
    .max_power = 0, // TODO
};
var endpoint_configs = [_]usb.EndpointConfiguration{
    usb.EndpointConfiguration{ .driver_ep_index = 0, .descriptor = undefined },
    usb.EndpointConfiguration{ .driver_ep_index = 1, .descriptor = undefined },
};

pub fn start() !void {
    Device.init_clk();
    try Device.init_device(&device_config);
}
