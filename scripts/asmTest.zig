const std = @import("std");
const time = std.time;
const Timer = time.Timer;
const NS_PER_SEC = 1000000000.0;
const CPU_FREQ_GHZ = 1.5;
const ARM_CPU_FREQ_GHZ = 0.8;
const F_CPU = 1000000000.0; // 500 MHz
// ns_per_clock = 1000000000 / HZ
//const loop400ns = 400 * 800 / (F_CPU / 1000);

// cycles = ns * (cpu freq Hz / 1,000,000,000)
// 450 * (3,000,000,000 / 1,000,000,000) = 450 * 3 = 1350
// 16MHz Arduino Uno 1 clock cycle 62.5ns.

// x86_64 ns timer
fn x86inlineDelayNS(ns: u64) void {
    var current: u64 = 0;
    var start: u64 = 0;
    const nsf: f64 = @floatFromInt(ns);
    const target_delta_clocks: u64 = @intFromFloat(nsf * CPU_FREQ_GHZ);
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
    std.debug.print("elapsed: {} ns - wanted: {} ns - clocks: {}\n", .{ current - start, ns, target_delta_clocks });
}

// aarch64  ns timer
fn aarch64InlineDelayNS(ns: u32) void {
    var current: u32 = 0;
    var start: u32 = 0;
    const nsf: f64 = @floatFromInt(ns);
    const target_delta_clocks: u64 = @intFromFloat(nsf * ARM_CPU_FREQ_GHZ);
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
    std.debug.print("elapsed: {} ns - wanted: {} ns - clocks: {}\n", .{ current - start, ns, target_delta_clocks });
}

fn delay04() void {
    for (0..10) |_| {
        _ = asm volatile ("nop\nnop\nnop");
    }
}

fn delay08() void {
    for (0..20) |_| {
        _ = asm volatile ("nop");
    }
}

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

fn delayWait(ns: u32) !void {
    var timer = try time.Timer.start();
    while (true) {
        if (timer.read() > ns) {
            break;
        }
    }
    const t = timer.lap();
    std.debug.print("waited: {} ns\n", .{t});
}

fn aarch64_ticks() u64 {
    return asm volatile ("mrs %[ret], CNTVCT_EL0"
        : [ret] "=r" (-> u64),
    );
}

// assembly for reading clock timestamp in ns
fn x86_64_ticks() u64 {
    return asm volatile (
        \\ rdtsc                   // Read Time-Stamp Counter into EDX:EAX
        \\ shl $32, %%rdx          // Shift EDX (high bits) to the upper part of a 64-bit value
        \\ or %%rdx, %%rax         // Combine RAX (low bits) and RDX into RAX
        : [ret] "={rax}" (-> u64), // Output: tsc gets the value of RAX
        :
        : .{ .rdx = true }
    );
}

pub fn main() !void {
    const arch = @import("builtin").target.cpu.arch;

    const nsPerCycle: f64 = NS_PER_SEC / F_CPU;
    const nops400ns: u32 = @divFloor(400.0, nsPerCycle);
    const nops800ns: u32 = @divFloor(800.0, nsPerCycle);
    std.debug.print("ns per clock: {d:.3} \n", .{nsPerCycle});
    std.debug.print("loops for 400ns: {d} \n", .{nops400ns});
    std.debug.print("loops for 800ns: {d} \n", .{nops800ns});
    var i: usize = 0;
    while (i < 10) : (i += 1) {
        //var timer = try Timer.start();
        //const start = x86_64_ticks();
        //delayNops(20);
        //delay04();
        //delay08();
        if (arch == std.Target.Cpu.Arch.x86_64) {
            x86inlineDelayNS(450);
            x86inlineDelayNS(850);
        } else {
            aarch64InlineDelayNS(450);
            aarch64InlineDelayNS(850);
        }
        //const end = x86_64_ticks();
        //std.debug.print("ellapsed cycles: {} ns\n", .{end - start});
        //delayNops(nops400ns);
        //const t = timer.lap();
        //std.debug.print("delayNops: {} ns\n", .{t});
        //try delayWait(200);
        time.sleep(1000 * 1000 * 1000);
    }
}
