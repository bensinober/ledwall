// https://wp.josh.com/2014/05/13/ws2812-neopixels-are-not-so-finicky-once-you-get-to-know-them/
// https://www.embeddedrelated.com/showarticle/528.php
const std = @import("std");
const gpiod = @import("gpiod.zig");
const archIsAarch64 = @import("builtin").target.cpu.arch == .aarch64;
const archIsX86_64 = @import("builtin").target.cpu.arch == .x86_64;
const archIsArm = @import("builtin").target.cpu.arch == .arm;
const GPIO0_BASE = 0xff220000;
const GPIO1_BASE = 0xff230000;
const GPIO2_BASE = 0xff240000;
const GPIO3_BASE = 0xff250000;
const GPIO4_BASE = 0xff260000;
// const gpiod = @cImport({
//     @cInclude("gpiod.h");
// });
const PIXELS = 3; // Number of pixels in the string
//const LED_PIN = 16;
const NS_PER_SEC = 1000000000.0;
const F_CPU = 1500000000.0; // 1.5 GHz
const CPU_FREQ_GHZ = 1.5;
const AARCH_CPU_FREQ_GHZ = 0.8;
const nsPerCycle: f64 = NS_PER_SEC / F_CPU;

// see how to drive ws2812 LEDS - 1.25us pulses
// 0 bit: 0.40us HI, 0.85us LO
// 1 bit: 0.80us HI, 0.45us LO
// added a bit extra for stability
// 0 bit pulse in ns
const T0_HIGH_NS = 400;
const T0_LOW_NS = 900;
// 1 bit pulse in ns
const T1_HIGH_NS = 900;
const T1_LOW_NS = 600;

// These values depend on which pin your string is connected to and what board you are using
// More info on how to find these at http://www.arduino.cc/en/Reference/PortManipulation

// Width of the low gap between bits to cause a frame to latch (= light leds)
const LED_PAUSE_NS = 250000; // = 250 us

pub const WS281x = struct {
    const Self = @This();

    chip: ?*gpiod.struct_gpiod_chip,
    dataPin: ?*gpiod.struct_gpiod_line,

    pub fn init(chip: ?*gpiod.struct_gpiod_chip, dataPin: c_uint) Self {
        std.debug.print("ws281x data pin: {any}\n", .{dataPin});
        const dp = gpiod.gpiod_chip_get_line(chip, dataPin);
        _ = gpiod.gpiod_line_request_output(dp, "ws281x", 0);
        return Self{
            .chip = chip,
            .dataPin = dp,
        };
    }

    fn sendByte(self: *Self, byte: u8) void {
        var i: u3 = 0; // start from LSB and reverse
        //std.debug.print("BITS: {b}\n", .{byte});
        while (true) {
            const bit = (byte >> i) & 1;
            const lsbBit: bool = @bitCast((bit & 1) == 1);
            self.sendBit(lsbBit);
            if (i == 7) break; // Stop after processing the MSB
            i += 1;
        }
    }
    fn sendBit(self: *Self, bit: bool) void {
        //std.debug.print("BIT: {}\n", .{bit});
        if (bit) {
            _ = gpiod.gpiod_line_set_value(self.dataPin, 1);
            delay08();
            //inlineDelayNS(T1_HIGH_NS);
            _ = gpiod.gpiod_line_set_value(self.dataPin, 0);
            delay04();
            //inlineDelayNS(T1_LOW_NS);
        } else {
            _ = gpiod.gpiod_line_set_value(self.dataPin, 1);
            //inlineDelayNS(T0_HIGH_NS);
            delay04();
            _ = gpiod.gpiod_line_set_value(self.dataPin, 0);
            delay08();
            //inlineDelayNS(T0_LOW_NS);
        }
    }
    pub fn sendPixel(self: *Self, r: u8, g: u8, b: u8) void {
        self.sendByte(g); // Neopixel wants colors in green then red then blue order
        self.sendByte(r);
        self.sendByte(b);
    }

    pub fn showColor(self: *Self, r: u8, g: u8, b: u8) void {
        for (0..PIXELS) |_| {
            self.sendPixel(r, g, b);
        }
        self.show();
    }
    pub fn show(_: *Self) void {
        std.time.sleep(LED_PAUSE_NS + 1); // 250us
    }

    pub fn sendReset(self: *Self) void {
        _ = gpiod.gpiod_line_set_value(self.dataPin, 0);
        for (0..100) |_| {
            delay08();
        }
    }

    pub fn deinit(self: *Self) void {
        _ = gpiod.gpiod_line_release(self.dataPin);
    }
};

fn delay04() void {
    var timer = std.time.Timer.start() catch |err| {
        std.debug.print("err: {any}\n", .{err});
        return;
    };
    _ = asm volatile ("nop");
    const t = timer.lap();
    std.debug.print("wanted 400ns - real: {}\n", .{t});
}
fn delay08() void {
    _ = asm volatile ("nop\nnop");
}
// general purpose for an assembly loop of NOPS for accurate timing
fn delayNops(ops: u32) void {
    _ = asm volatile (
        // Assembly instructions for the loop
        // Input: 'in' constraint for counter
        // Output: 'out' constraint for result
        // Clobber list: Registers modified by the assembly that aren't inputs/outputs
            \\ loop_start:
            \\    nop
            \\    dec %[counter]
            \\    jnz loop_start
            :
            : [counter] "+r" (ops), // In/Out constraints for read/write general purpose counter
        );
}
fn inlineDelayNS(ns: u64) void {
    var current: u64 = 0;
    var start: u64 = 0;
    const target_delta_clocks: u64 = @divFloor(ns, 300);
    var timer = std.time.Timer.start() catch |err| {
        std.debug.print("err: {any}\n", .{err});
        return;
    };
    if (archIsX86_64) {
        _ = asm volatile (
            \\ rdtsc                   // Read Time-Stamp Counter into EDX:EAX
            \\ shl $32, %%rdx          // Shift EDX (high bits) to the upper part of a 64-bit value
            \\ or %%rdx, %%rax         // Combine RAX (low bits) and RDX into RAX
            : [start] "={rax}" (start), // Output: tsc gets the value of RAX
            :
            : .{ .rdx = true }
        );
        while (true) {
            _ = asm volatile (
                \\ rdtsc                   // Read Time-Stamp Counter into EDX:EAX
                \\ shl $32, %%rdx          // Shift EDX (high bits) to the upper part of a 64-bit value
                \\ or %%rdx, %%rax         // Combine RAX (low bits) and RDX into RAX
                : [current] "={rax}" (current), // Output: tsc gets the value of RAX
                :
                : .{ .rdx = true }
            );
            if ((current - start) > target_delta_clocks) {
                break;
            }
        }
    } else if (archIsAarch64) {
        _ = asm volatile (
            \\ mrs %[start], cntvct_el0
            : [start] "=r" (start), // Output: tsc gets the value of RAX
            :
            : .{ .memory = true }
        );
        while (true) {
            _ = asm volatile (
                \\ mrs %[current], cntvct_el0
                : [current] "=r" (current), // Output: tsc gets the value of RAX
                :
                : .{ .memory = true }
            );
            if ((current - start) > target_delta_clocks) {
                break;
            }
        }
    } else {
        std.debug.print("unknown arch: {}\n", .{@import("builtin").target.cpu.arch});
    }
    const t = timer.lap();
    std.debug.print("spent: {} clocks - wanted: {} clocks - wanted: {} ns - real: {}\n", .{ current - start, target_delta_clocks, ns, t });
}

// #define NS_PER_SEC (1000000000L)          // Note that this has to be SIGNED since we want to be able to check for negative values of derivatives
// #define CYCLES_PER_SEC (F_CPU)
// #define NS_PER_CYCLE ( NS_PER_SEC / CYCLES_PER_SEC )
// #define NS_TO_CYCLES(n) ( (n) / NS_PER_CYCLE )

// These values are for the pin that connects to the Data Input pin on the LED strip. They correspond to...

// Arduino Yun:     Digital Pin 8
// DueMilinove/UNO: Digital Pin 12
// Arduino MeagL    PWM Pin 4

// You'll need to look up the port/bit combination for other boards.

// Note that you could also include the DigitalWriteFast header file to not need to to this lookup.
