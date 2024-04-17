MEMORY
{
    ram (rw)    : ORIGIN = 0x20000000, LENGTH = 20K
    flash (rx)  : ORIGIN = 0x08000000, LENGTH = 64K
}

SECTIONS
{
    .text : {
        KEEP(*(.vector_table))
        *(.text*)
    } >flash

    .ARM.exidx : {
        *(.ARM.exidx*)
    } >flash

    .rodata : {
        *(.rodata*)
    } >flash

    .data : {
        _data_start = .;
        *(.data*)
        _data_end = .;
    } >ram AT >flash
    _data_loadaddr = LOADADDR(.data);

    .bss : {
        _bss_start = .;
        *(.bss*)
        _bss_end = .;
    } >ram
}

PROVIDE(_stack = ORIGIN(ram) + LENGTH(ram));
