const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = std.zig.CrossTarget.parse(.{
            .arch_os_abi = "thumb-freestanding-none",
            .cpu_features = "cortex_m3",
        }) catch unreachable,
    });

    const optimize = b.standardOptimizeOption(.{});

    const elf = b.addExecutable(.{
        .name = "firmware.elf",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
    });
    elf.link_function_sections = true;
    elf.link_data_sections = true;
    elf.link_gc_sections = true;
    elf.setLinkerScript(.{ .path = "stm32f103c8.ld" });
    b.installArtifact(elf);

    const flash = b.addSystemCommand(&[_][]const u8{ "openocd", "-f", "openocd.cfg", "-c", "program zig-out/bin/firmware.elf verify reset exit" });
    flash.step.dependOn(b.getInstallStep());
    const flash_cmd = b.step("flash", "Flash firmware to device");
    flash_cmd.dependOn(&flash.step);
}
