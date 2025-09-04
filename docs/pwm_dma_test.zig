const std = @import("std");

pub export var virt_gpio_regs: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque);
pub export var virt_dma_regs: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque);
pub export var virt_pwm_regs: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque);
pub export var mbox_fd: c_int = @import("std").mem.zeroes(c_int);
pub export var dma_mem_h: c_int = @import("std").mem.zeroes(c_int);
pub export var bus_dma_mem: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque);
pub const MEM_FLAG_DISCARDABLE: c_int = 1;
pub const MEM_FLAG_NORMAL: c_int = 0;
pub const MEM_FLAG_DIRECT: c_int = 4;
pub const MEM_FLAG_COHERENT: c_int = 8;
pub const MEM_FLAG_ZERO: c_int = 16;
pub const MEM_FLAG_NO_INIT: c_int = 32;
pub const MEM_FLAG_HINT_PERMALOCK: c_int = 64;
pub const MEM_FLAG_L1_NONALLOCATING: c_int = 12;
pub const VC_ALLOC_FLAGS = c_uint;
pub const VC_MSG = extern struct {
    len: u32 = @import("std").mem.zeroes(u32),
    req: u32 = @import("std").mem.zeroes(u32),
    tag: u32 = @import("std").mem.zeroes(u32),
    blen: u32 = @import("std").mem.zeroes(u32),
    dlen: u32 = @import("std").mem.zeroes(u32),
    uints: [27]u32 = @import("std").mem.zeroes([27]u32),
};
pub export var dma_regstrs: [10][*c]u8 = [10][*c]u8{
    "DMA CS",
    "CB_AD",
    "TI",
    "SRCE_AD",
    "DEST_AD",
    "TFR_LEN",
    "STRIDE",
    "NEXT_CB",
    "DEBUG",
    "",
};
pub const DMA_CB = extern struct {
    ti: u32 = @import("std").mem.zeroes(u32),
    srce_ad: u32 = @import("std").mem.zeroes(u32),
    dest_ad: u32 = @import("std").mem.zeroes(u32),
    tfr_len: u32 = @import("std").mem.zeroes(u32),
    stride: u32 = @import("std").mem.zeroes(u32),
    next_cb: u32 = @import("std").mem.zeroes(u32),
    debug: u32 = @import("std").mem.zeroes(u32),
    unused: u32 = @import("std").mem.zeroes(u32),
};
pub export var virt_dma_mem: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque);
pub export var virt_clk_regs: ?*anyopaque = @import("std").mem.zeroes(?*anyopaque);
pub export fn gpio_mode(arg_pin: c_int, arg_mode: c_int) void {
    var pin = arg_pin;
    _ = &pin;
    var mode = arg_mode;
    _ = &mode;
    var reg: [*c]u32 = @as([*c]u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_gpio_regs))) +% @as(u32, @bitCast(@as(c_int, 0))))) + @as(usize, @bitCast(@as(isize, @intCast(@divTrunc(pin, @as(c_int, 10))))));
    _ = &reg;
    var shift: u32 = @as(u32, @bitCast(@import("std").zig.c_translation.signedRemainder(pin, @as(c_int, 10)) * @as(c_int, 3)));
    _ = &shift;
    reg.* = (reg.* & @as(u32, @bitCast(~(@as(c_int, 7) << @intCast(shift))))) | @as(u32, @bitCast(mode << @intCast(shift)));
}
pub export fn gpio_out(arg_pin: c_int, arg_val: c_int) void {
    var pin = arg_pin;
    _ = &pin;
    var val = arg_val;
    _ = &val;
    var reg: [*c]u32 = @as([*c]u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_gpio_regs))) +% @as(u32, @bitCast(if (val != 0) @as(c_int, 28) else @as(c_int, 40))))) + @as(usize, @bitCast(@as(isize, @intCast(@divTrunc(pin, @as(c_int, 32))))));
    _ = &reg;
    reg.* = @as(u32, @bitCast(@as(c_int, 1) << @intCast(@import("std").zig.c_translation.signedRemainder(pin, @as(c_int, 32)))));
}
pub export fn gpio_in(arg_pin: c_int) u8 {
    var pin = arg_pin;
    _ = &pin;
    var reg: [*c]u32 = @as([*c]u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_gpio_regs))) +% @as(u32, @bitCast(@as(c_int, 52))))) + @as(usize, @bitCast(@as(isize, @intCast(@divTrunc(pin, @as(c_int, 32))))));
    _ = &reg;
    return @as(u8, @bitCast(@as(u8, @truncate((reg.* >> @intCast(@import("std").zig.c_translation.signedRemainder(pin, @as(c_int, 32)))) & @as(u32, @bitCast(@as(c_int, 1)))))));
}
pub export fn enable_dma() void {
    @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_dma_regs))) +% @as(u32, @bitCast(@as(c_int, 4080))))).* |= @as(u32, @bitCast(@as(u32, @bitCast(@as(c_int, 1) << @intCast(5)))));
    @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_dma_regs))) +% @as(u32, @bitCast(@as(c_int, 5) * @as(c_int, 256))))).* = @as(u32, @bitCast(@as(c_int, 1) << @intCast(31)));
}
pub export fn start_dma(arg_cbp: [*c]DMA_CB) void {
    var cbp = arg_cbp;
    _ = &cbp;
    @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_dma_regs))) +% @as(u32, @bitCast((@as(c_int, 5) * @as(c_int, 256)) + @as(c_int, 4))))).* = (@as(u32, @intCast(@intFromPtr(cbp))) -% @as(u32, @intCast(@intFromPtr(virt_dma_mem)))) +% @as(u32, @intCast(@intFromPtr(bus_dma_mem)));
    @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_dma_regs))) +% @as(u32, @bitCast(@as(c_int, 5) * @as(c_int, 256))))).* = 2;
    @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_dma_regs))) +% @as(u32, @bitCast((@as(c_int, 5) * @as(c_int, 256)) + @as(c_int, 32))))).* = 7;
    @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_dma_regs))) +% @as(u32, @bitCast(@as(c_int, 5) * @as(c_int, 256))))).* = 1;
}
pub export fn stop_dma() void {
    if (virt_dma_regs != null) {
        @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_dma_regs))) +% @as(u32, @bitCast(@as(c_int, 5) * @as(c_int, 256))))).* = @as(u32, @bitCast(@as(c_int, 1) << @intCast(31)));
    }
}
pub export fn init_pwm(arg_freq: c_int) void {
    var freq = arg_freq;
    _ = &freq;
    stop_pwm();
    if ((@as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_pwm_regs))) +% @as(u32, @bitCast(@as(c_int, 4))))).* & @as(u32, @bitCast(@as(c_int, 256)))) != 0) {
        // TODO: _ = printf("PWM bus error\n");
        @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_pwm_regs))) +% @as(u32, @bitCast(@as(c_int, 4))))).* = @as(u32, @bitCast(@as(c_int, 256)));
    }
    var divi: c_int = @divTrunc(@as(c_int, 250000) * @as(c_int, 1000), freq);
    _ = &divi;
    @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_clk_regs))) +% @as(u32, @bitCast(@as(c_int, 160))))).* = @as(u32, @bitCast(@as(c_int, 1509949440) | (@as(c_int, 1) << @intCast(5))));
    while ((@as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_clk_regs))) +% @as(u32, @bitCast(@as(c_int, 160))))).* & @as(u32, @bitCast(@as(c_int, 1) << @intCast(7)))) != 0) {}
    @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_clk_regs))) +% @as(u32, @bitCast(@as(c_int, 164))))).* = @as(u32, @bitCast(@as(c_int, 1509949440) | (divi << @intCast(12))));
    @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_clk_regs))) +% @as(u32, @bitCast(@as(c_int, 160))))).* = @as(u32, @bitCast((@as(c_int, 1509949440) | @as(c_int, 6)) | (@as(c_int, 1) << @intCast(4))));
    while ((@as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_clk_regs))) +% @as(u32, @bitCast(@as(c_int, 160))))).* & @as(u32, @bitCast(@as(c_int, 1) << @intCast(7)))) == @as(u32, @bitCast(@as(c_int, 0)))) {}
    std.time.sleep(100 * 1000); // _ = usleep(@as(__useconds_t, @bitCast(@as(c_int, 100))));
    @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_pwm_regs))) +% @as(u32, @bitCast(@as(c_int, 16))))).* = @as(u32, @bitCast(@as(c_int, 20000)));
    @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_pwm_regs))) +% @as(u32, @bitCast(@as(c_int, 24))))).* = @as(u32, @bitCast(@divTrunc(@as(c_int, 20000), @as(c_int, 2))));
    gpio_mode(@as(c_int, 18), @as(c_int, 2));
}
pub export fn start_pwm() void {
    @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_pwm_regs))) +% @as(u32, @bitCast(@as(c_int, 0))))).* = @as(u32, @bitCast((@as(c_int, 1) << @intCast(5)) | @as(c_int, 1)));
}
pub export fn stop_pwm() void {
    if (virt_pwm_regs != null) {
        @as([*c]volatile u32, @ptrFromInt(@as(u32, @intCast(@intFromPtr(virt_pwm_regs))) +% @as(u32, @bitCast(@as(c_int, 0))))).* = 0;
        std.time.sleep(100 * 1000); // _ = usleep(@as(__useconds_t, @bitCast(@as(c_int, 100))));
    }
}
pub export fn main(arg_argc: c_int, arg_argv: [*c][*c]u8) c_int {
    var argc = arg_argc;
    _ = &argc;
    var argv = arg_argv;
    _ = &argv;
    // _ = signal(@as(c_int, 2), &terminate);
    virt_gpio_regs = map_segment(@as(?*anyopaque, @ptrFromInt(@as(c_int, 1056964608) + @as(c_int, 2097152))), @as(c_int, 4096));
    virt_dma_regs = map_segment(@as(?*anyopaque, @ptrFromInt(@as(c_int, 1056964608) + @as(c_int, 28672))), @as(c_int, 4096));
    virt_pwm_regs = map_segment(@as(?*anyopaque, @ptrFromInt(@as(c_int, 1056964608) + @as(c_int, 2146304))), @as(c_int, 4096));
    virt_clk_regs = map_segment(@as(?*anyopaque, @ptrFromInt(@as(c_int, 1056964608) + @as(c_int, 1052672))), @as(c_int, 4096));
    enable_dma();
    gpio_mode(@as(c_int, 21), @as(c_int, 1));
    gpio_out(@as(c_int, 21), @as(c_int, 1));
    mbox_fd = open_mbox();
    if ((((blk: {
        const tmp = @as(c_int, @bitCast(alloc_vc_mem(mbox_fd, @as(u32, @bitCast(@as(c_int, 4096))), @as(c_uint, @bitCast(MEM_FLAG_DIRECT | MEM_FLAG_ZERO)))));
        dma_mem_h = tmp;
        break :blk tmp;
    }) <= @as(c_int, 0)) or ((blk: {
        const tmp = lock_vc_mem(mbox_fd, dma_mem_h);
        bus_dma_mem = tmp;
        break :blk tmp;
    }) == null)) or ((blk: {
        const tmp = map_segment(@as(?*anyopaque, @ptrFromInt(@as(u32, @intCast(@intFromPtr(bus_dma_mem))) & ~@as(c_uint, 3221225472))), @as(c_int, 4096));
        virt_dma_mem = tmp;
        break :blk tmp;
    }) == null)) {
        _ = printf("Error: can't allocate uncached memory\n");
        terminate(@as(c_int, 0));
    }
    _ = printf("VC mem handle %u, phys %p, virt %p\n", dma_mem_h, bus_dma_mem, virt_dma_mem);
    _ = dma_test_mem_transfer();
    dma_test_led_flash(@as(c_int, 21));
    dma_test_pwm_trigger(@as(c_int, 21));
    terminate(@as(c_int, 0));
    return 0;
}
pub const PHYS_REG_BASE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x3F000000, .hex);
pub const BUS_REG_BASE = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x7E000000, .hex);
pub const DEBUG = @as(c_int, 0);
pub const LED_PIN = @as(c_int, 21);
pub const PWM_FREQ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 100000, .decimal);
pub const PWM_RANGE = @as(c_int, 20000);
pub const USE_VC_CLOCK_SET = @as(c_int, 0);
pub const PAGE_SIZE = @as(c_int, 0x1000);
pub inline fn PAGE_ROUNDUP(n: anytype) @TypeOf(if (@import("std").zig.c_translation.MacroArithmetic.rem(n, PAGE_SIZE) == @as(c_int, 0)) n else (n + PAGE_SIZE) & ~(PAGE_SIZE - @as(c_int, 1))) {
    _ = &n;
    return if (@import("std").zig.c_translation.MacroArithmetic.rem(n, PAGE_SIZE) == @as(c_int, 0)) n else (n + PAGE_SIZE) & ~(PAGE_SIZE - @as(c_int, 1));
}
pub const DMA_MEM_SIZE = PAGE_SIZE;
pub const GPIO_BASE = PHYS_REG_BASE + @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x200000, .hex);
pub const GPIO_MODE0 = @as(c_int, 0x00);
pub const GPIO_SET0 = @as(c_int, 0x1c);
pub const GPIO_CLR0 = @as(c_int, 0x28);
pub const GPIO_LEV0 = @as(c_int, 0x34);
pub inline fn VIRT_GPIO_REG(a: anytype) [*c]u32 {
    _ = &a;
    return @import("std").zig.c_translation.cast([*c]u32, @import("std").zig.c_translation.cast(u32, virt_gpio_regs) + a);
}
pub inline fn BUS_GPIO_REG(a: anytype) @TypeOf(((GPIO_BASE - PHYS_REG_BASE) + BUS_REG_BASE) + @import("std").zig.c_translation.cast(u32, a)) {
    _ = &a;
    return ((GPIO_BASE - PHYS_REG_BASE) + BUS_REG_BASE) + @import("std").zig.c_translation.cast(u32, a);
}
pub const GPIO_IN = @as(c_int, 0);
pub const GPIO_OUT = @as(c_int, 1);
pub const GPIO_ALT0 = @as(c_int, 4);
pub const GPIO_ALT2 = @as(c_int, 6);
pub const GPIO_ALT3 = @as(c_int, 7);
pub const GPIO_ALT4 = @as(c_int, 3);
pub const GPIO_ALT5 = @as(c_int, 2);
pub inline fn BUS_PHYS_ADDR(a: anytype) ?*anyopaque {
    _ = &a;
    return @import("std").zig.c_translation.cast(?*anyopaque, @import("std").zig.c_translation.cast(u32, a) & ~@import("std").zig.c_translation.promoteIntLiteral(c_int, 0xC0000000, .hex));
}
pub const DMA_MEM_FLAGS = MEM_FLAG_DIRECT | MEM_FLAG_ZERO;
pub const DMA_CHAN = @as(c_int, 5);
pub const DMA_PWM_DREQ = @as(c_int, 5);
pub const DMA_BASE = PHYS_REG_BASE + @as(c_int, 0x007000);
pub const DMA_CS = DMA_CHAN * @as(c_int, 0x100);
pub const DMA_CONBLK_AD = (DMA_CHAN * @as(c_int, 0x100)) + @as(c_int, 0x04);
pub const DMA_TI = (DMA_CHAN * @as(c_int, 0x100)) + @as(c_int, 0x08);
pub const DMA_SRCE_AD = (DMA_CHAN * @as(c_int, 0x100)) + @as(c_int, 0x0c);
pub const DMA_DEST_AD = (DMA_CHAN * @as(c_int, 0x100)) + @as(c_int, 0x10);
pub const DMA_TXFR_LEN = (DMA_CHAN * @as(c_int, 0x100)) + @as(c_int, 0x14);
pub const DMA_STRIDE = (DMA_CHAN * @as(c_int, 0x100)) + @as(c_int, 0x18);
pub const DMA_NEXTCONBK = (DMA_CHAN * @as(c_int, 0x100)) + @as(c_int, 0x1c);
pub const DMA_DEBUG = (DMA_CHAN * @as(c_int, 0x100)) + @as(c_int, 0x20);
pub const DMA_ENABLE = @as(c_int, 0xff0);
pub const VIRT_DMA_REG = @compileError("unable to translate C expr: unexpected token 'volatile'");
// pwm_dma_test.c:124:9
pub const DMA_CB_DEST_INC = @as(c_int, 1) << @as(c_int, 4);
pub const DMA_CB_SRC_INC = @as(c_int, 1) << @as(c_int, 8);
pub inline fn BUS_DMA_MEM(a: anytype) @TypeOf((@import("std").zig.c_translation.cast(u32, a) - @import("std").zig.c_translation.cast(u32, virt_dma_mem)) + @import("std").zig.c_translation.cast(u32, bus_dma_mem)) {
    _ = &a;
    return (@import("std").zig.c_translation.cast(u32, a) - @import("std").zig.c_translation.cast(u32, virt_dma_mem)) + @import("std").zig.c_translation.cast(u32, bus_dma_mem);
}
pub const PWM_BASE = PHYS_REG_BASE + @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x20C000, .hex);
pub const PWM_CTL = @as(c_int, 0x00);
pub const PWM_STA = @as(c_int, 0x04);
pub const PWM_DMAC = @as(c_int, 0x08);
pub const PWM_RNG1 = @as(c_int, 0x10);
pub const PWM_DAT1 = @as(c_int, 0x14);
pub const PWM_FIF1 = @as(c_int, 0x18);
pub const PWM_RNG2 = @as(c_int, 0x20);
pub const PWM_DAT2 = @as(c_int, 0x24);
pub const VIRT_PWM_REG = @compileError("unable to translate C expr: unexpected token 'volatile'");
// pwm_dma_test.c:158:9
pub inline fn BUS_PWM_REG(a: anytype) @TypeOf(((PWM_BASE - PHYS_REG_BASE) + BUS_REG_BASE) + @import("std").zig.c_translation.cast(u32, a)) {
    _ = &a;
    return ((PWM_BASE - PHYS_REG_BASE) + BUS_REG_BASE) + @import("std").zig.c_translation.cast(u32, a);
}
pub const PWM_CTL_RPTL1 = @as(c_int, 1) << @as(c_int, 2);
pub const PWM_CTL_USEF1 = @as(c_int, 1) << @as(c_int, 5);
pub const PWM_DMAC_ENAB = @as(c_int, 1) << @as(c_int, 31);
pub const PWM_ENAB = @as(c_int, 1);
pub const PWM_PIN = @as(c_int, 18);
pub const PWM_OUT = @as(c_int, 1);
pub const CLK_BASE = PHYS_REG_BASE + @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x101000, .hex);
pub const CLK_PWM_CTL = @as(c_int, 0xa0);
pub const CLK_PWM_DIV = @as(c_int, 0xa4);
pub const VIRT_CLK_REG = @compileError("unable to translate C expr: unexpected token 'volatile'");
// pwm_dma_test.c:172:9
pub const CLK_PASSWD = @import("std").zig.c_translation.promoteIntLiteral(c_int, 0x5a000000, .hex);
pub const CLOCK_KHZ = @import("std").zig.c_translation.promoteIntLiteral(c_int, 250000, .decimal);
pub const PWM_CLOCK_ID = @as(c_int, 0xa);
pub const FAIL = @compileError("unable to translate C expr: unexpected token '{'");
