const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // const lodepng_translate_step = b.addTranslateC(.{
    //     .root_source_file = b.path("include/lodepng.h"),
    //     .target = target,
    //     .optimize = optimize,
    //     .link_libc = true, // Link with libc if your C code uses it
    // });

    const cSourceFiles = &[_][]const u8{
        "lib/bluez/libbluetooth/bluetooth.c",
        "lib/bluez/libbluetooth/hci.c",
        "lib/bluez/libbluetooth/uuid.c",
        "lib/bluez/libshared/att.c",
        "lib/bluez/libshared/crypto.c",
        "lib/bluez/libshared/gatt-client.c",
        "lib/bluez/libshared/gatt-db.c",
        "lib/bluez/libshared/gatt-helpers.c",
        "lib/bluez/libshared/gatt-server.c",
        "lib/bluez/libshared/mainloop.c",
        "lib/bluez/libshared/mainloop-notify.c",
        "lib/bluez/libshared/io-mainloop.c",
        "lib/bluez/libshared/timeout-mainloop.c",
        "lib/bluez/libshared/queue.c",
        "lib/bluez/libshared/util.c",
        "lib/ble-gatt-server-wrapper.c", // the zig callback wrapper
    };

    // Add bluez bluetooth module
    const exeBluezMod = b.createModule(.{
        //.root_source_file = b.path("src/bluez.zig"), // not needed
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = false,
    });

    exeBluezMod.addCSourceFiles(.{
        .files = cSourceFiles,
        .flags = &.{},
    });
    exeBluezMod.addIncludePath(b.path("include/bluez"));
    exeBluezMod.addIncludePath(b.path("include/bluez/lib"));
    exeBluezMod.addIncludePath(b.path("include/bluez/src/shared"));
    const exeBluezLib = b.addLibrary(.{
        .name = "bluez",
        .linkage = .static,
        .root_module = exeBluezMod,
    });
    // target x86_64
    const exe = b.addExecutable(.{
        .name = "deichmanLedScreen",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    exe.linkLibC();
    exe.linkSystemLibrary("gpiod");
    exe.linkSystemLibrary("ws2811");
    exe.linkLibrary(exeBluezLib);
    exe.addIncludePath(b.path("include"));

    _ = b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the x86_64 app");
    run_step.dependOn(&run_cmd.step);

    // TARGET armv7
    const arm = b.addExecutable(.{
        .name = "deichmanLedScreen-armv7",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .arm,
                .os_tag = .linux,
                .abi = .gnueabihf,
            }),
            .optimize = optimize,
        }),
    });
    const armBluezMod = b.createModule(.{
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .arm,
            .os_tag = .linux,
            .abi = .gnueabihf,
        }),
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = false,
    });

    armBluezMod.addCSourceFiles(.{
        .files = cSourceFiles,
        .flags = &.{},
    });
    armBluezMod.addIncludePath(b.path("include/bluez"));
    armBluezMod.addIncludePath(b.path("include/bluez/lib"));
    armBluezMod.addIncludePath(b.path("include/bluez/src/shared"));
    const armBluezLib = b.addLibrary(.{
        .name = "bluez",
        .linkage = .static,
        .root_module = armBluezMod,
    });
    arm.linkLibC();
    arm.linkSystemLibrary("gpiod");
    arm.addLibraryPath(b.path("lib/armv7"));
    //arm.linkLibrary("ws2811");
    arm.addObjectFile(b.path("lib/armv7/libws2811.a"));
    arm.addIncludePath(b.path("include"));
    arm.linkLibrary(armBluezLib);

    _ = b.installArtifact(arm);
    //zigcvMod.addCSourceFile(.{ .file = b.path("libs/asyncarray.cpp"), .flags = &[_][]const u8{"-Wall","-Wextra","-std=c++11", "-stdlib=libc++" } });

    // target aarch64
    const aarch = b.addExecutable(.{
        .name = "deichmanLedScreen-aarch64",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = b.resolveTargetQuery(.{
                .cpu_arch = .aarch64,
                .os_tag = .linux,
                .abi = .gnu,
            }),
            .optimize = optimize,
        }),
    });
    const aarchBluezMod = b.createModule(.{
        .target = b.resolveTargetQuery(.{
            .cpu_arch = .aarch64,
            .os_tag = .linux,
            .abi = .gnu,
        }),
        .optimize = optimize,
        .link_libc = true,
        .link_libcpp = false,
    });

    aarchBluezMod.addCSourceFiles(.{
        .files = cSourceFiles,
        .flags = &.{},
    });
    aarchBluezMod.addIncludePath(b.path("include/bluez"));
    aarchBluezMod.addIncludePath(b.path("include/bluez/lib"));
    aarchBluezMod.addIncludePath(b.path("include/bluez/src/shared"));
    const aarchBluezLib = b.addLibrary(.{
        .name = "bluez",
        .linkage = .static,
        .root_module = aarchBluezMod,
    });
    aarch.linkLibC();
    aarch.linkSystemLibrary("gpiod");
    aarch.addLibraryPath(b.path("lib/aarch64"));
    aarch.addObjectFile(b.path("lib/aarch64/libws2811.a"));
    aarch.addIncludePath(b.path("include"));
    aarch.linkLibrary(aarchBluezLib);
    _ = b.installArtifact(aarch);

}
