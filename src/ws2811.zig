pub const rpi_hw_t = extern struct {
    type: u32 = @import("std").mem.zeroes(u32),
    hwver: u32 = @import("std").mem.zeroes(u32),
    periph_base: u32 = @import("std").mem.zeroes(u32),
    videocore_base: u32 = @import("std").mem.zeroes(u32),
    desc: [*c]u8 = @import("std").mem.zeroes([*c]u8),
};
pub extern fn rpi_hw_detect() [*c]const rpi_hw_t;
pub const pwm_t = extern struct {
    ctl: u32 align(1) = @import("std").mem.zeroes(u32),
    sta: u32 align(1) = @import("std").mem.zeroes(u32),
    dmac: u32 align(1) = @import("std").mem.zeroes(u32),
    resvd_0x0c: u32 align(1) = @import("std").mem.zeroes(u32),
    rng1: u32 align(1) = @import("std").mem.zeroes(u32),
    dat1: u32 align(1) = @import("std").mem.zeroes(u32),
    fif1: u32 align(1) = @import("std").mem.zeroes(u32),
    resvd_0x1c: u32 align(1) = @import("std").mem.zeroes(u32),
    rng2: u32 align(1) = @import("std").mem.zeroes(u32),
    dat2: u32 align(1) = @import("std").mem.zeroes(u32),
};
pub const pwm_pin_table_t = extern struct {
    pinnum: c_int = @import("std").mem.zeroes(c_int),
    altnum: c_int = @import("std").mem.zeroes(c_int),
};
pub const pwm_pin_tables_t = extern struct {
    count: c_int = @import("std").mem.zeroes(c_int),
    pins: [*c]const pwm_pin_table_t = @import("std").mem.zeroes([*c]const pwm_pin_table_t),
};
pub extern fn pwm_pin_alt(chan: c_int, pinnum: c_int) c_int;
pub const struct_ws2811_device = opaque {};
pub const ws2811_led_t = u32;
pub const struct_ws2811_channel_t = extern struct {
    gpionum: c_int = 0,
    invert: c_int = 0,
    count: c_int = 0,
    strip_type: c_int = 0,
    leds: [*c]ws2811_led_t = @import("std").mem.zeroes([*c]ws2811_led_t),
    brightness: u8 = 0x00,
    wshift: u8 = 0x00,
    rshift: u8 = 0x00,
    gshift: u8 = 0x00,
    bshift: u8 = 0x00,
    gamma: [*c]u8 = @import("std").mem.zeroes([*c]u8),
};
pub const ws2811_channel_t = struct_ws2811_channel_t;
pub const struct_ws2811_t = extern struct {
    render_wait_time: u64 = @import("std").mem.zeroes(u64),
    device: ?*struct_ws2811_device = @import("std").mem.zeroes(?*struct_ws2811_device),
    rpi_hw: [*c]const rpi_hw_t = @import("std").mem.zeroes([*c]const rpi_hw_t),
    freq: u32 = @import("std").mem.zeroes(u32),
    dmanum: c_int = @import("std").mem.zeroes(c_int),
    channel: [2]ws2811_channel_t = @import("std").mem.zeroes([2]ws2811_channel_t),
};
pub const ws2811_t = struct_ws2811_t;
pub const WS2811_SUCCESS: c_int = 0;
pub const WS2811_ERROR_GENERIC: c_int = -1;
pub const WS2811_ERROR_OUT_OF_MEMORY: c_int = -2;
pub const WS2811_ERROR_HW_NOT_SUPPORTED: c_int = -3;
pub const WS2811_ERROR_MEM_LOCK: c_int = -4;
pub const WS2811_ERROR_MMAP: c_int = -5;
pub const WS2811_ERROR_MAP_REGISTERS: c_int = -6;
pub const WS2811_ERROR_GPIO_INIT: c_int = -7;
pub const WS2811_ERROR_PWM_SETUP: c_int = -8;
pub const WS2811_ERROR_MAILBOX_DEVICE: c_int = -9;
pub const WS2811_ERROR_DMA: c_int = -10;
pub const WS2811_ERROR_ILLEGAL_GPIO: c_int = -11;
pub const WS2811_ERROR_PCM_SETUP: c_int = -12;
pub const WS2811_ERROR_SPI_SETUP: c_int = -13;
pub const WS2811_ERROR_SPI_TRANSFER: c_int = -14;
pub const WS2811_RETURN_STATE_COUNT: c_int = -13;
pub const ws2811_return_t = c_int;
pub extern fn ws2811_init(ws2811: [*c]ws2811_t) ws2811_return_t;
pub extern fn ws2811_fini(ws2811: [*c]ws2811_t) void;
pub extern fn ws2811_render(ws2811: [*c]ws2811_t) ws2811_return_t;
pub extern fn ws2811_wait(ws2811: [*c]ws2811_t) ws2811_return_t;
pub extern fn ws2811_get_return_t_str(state: ws2811_return_t) [*c]const u8;
pub extern fn ws2811_set_custom_gamma_factor(ws2811: [*c]ws2811_t, gamma_factor: f64) void;

pub const __RPIHW_H__ = "";
pub const RPI_HWVER_TYPE_UNKNOWN = @as(c_int, 0);
pub const RPI_HWVER_TYPE_PI1 = @as(c_int, 1);
pub const RPI_HWVER_TYPE_PI2 = @as(c_int, 2);
pub const RPI_HWVER_TYPE_PI4 = @as(c_int, 3);
pub const __PWM_H__ = "";
pub const RPI_PWM_CHANNELS = @as(c_int, 2);
pub const RPI_PWM_CTL_MSEN2 = @as(c_int, 1) << @as(c_int, 15);
pub const RPI_PWM_CTL_USEF2 = @as(c_int, 1) << @as(c_int, 13);
pub const RPI_PWM_CTL_POLA2 = @as(c_int, 1) << @as(c_int, 12);
pub const RPI_PWM_CTL_SBIT2 = @as(c_int, 1) << @as(c_int, 11);
pub const RPI_PWM_CTL_RPTL2 = @as(c_int, 1) << @as(c_int, 10);
pub const RPI_PWM_CTL_MODE2 = @as(c_int, 1) << @as(c_int, 9);
pub const RPI_PWM_CTL_PWEN2 = @as(c_int, 1) << @as(c_int, 8);
pub const RPI_PWM_CTL_MSEN1 = @as(c_int, 1) << @as(c_int, 7);
pub const RPI_PWM_CTL_CLRF1 = @as(c_int, 1) << @as(c_int, 6);
pub const RPI_PWM_CTL_USEF1 = @as(c_int, 1) << @as(c_int, 5);
pub const RPI_PWM_CTL_POLA1 = @as(c_int, 1) << @as(c_int, 4);
pub const RPI_PWM_CTL_SBIT1 = @as(c_int, 1) << @as(c_int, 3);
pub const RPI_PWM_CTL_RPTL1 = @as(c_int, 1) << @as(c_int, 2);
pub const RPI_PWM_CTL_MODE1 = @as(c_int, 1) << @as(c_int, 1);
pub const RPI_PWM_CTL_PWEN1 = @as(c_int, 1) << @as(c_int, 0);
pub const RPI_PWM_STA_STA4 = @as(c_int, 1) << @as(c_int, 12);
pub const RPI_PWM_STA_STA3 = @as(c_int, 1) << @as(c_int, 11);
pub const RPI_PWM_STA_STA2 = @as(c_int, 1) << @as(c_int, 10);
pub const RPI_PWM_STA_STA1 = @as(c_int, 1) << @as(c_int, 9);
pub const RPI_PWM_STA_BERR = @as(c_int, 1) << @as(c_int, 8);
pub const RPI_PWM_STA_GAP04 = @as(c_int, 1) << @as(c_int, 7);
pub const RPI_PWM_STA_GAP03 = @as(c_int, 1) << @as(c_int, 6);
pub const RPI_PWM_STA_GAP02 = @as(c_int, 1) << @as(c_int, 5);
pub const RPI_PWM_STA_GAP01 = @as(c_int, 1) << @as(c_int, 4);
pub const RPI_PWM_STA_RERR1 = @as(c_int, 1) << @as(c_int, 3);
pub const RPI_PWM_STA_WERR1 = @as(c_int, 1) << @as(c_int, 2);
pub const RPI_PWM_STA_EMPT1 = @as(c_int, 1) << @as(c_int, 1);
pub const RPI_PWM_STA_FULL1 = @as(c_int, 1) << @as(c_int, 0);
pub const RPI_PWM_DMAC_ENAB = @as(c_int, 1) << @as(c_int, 31);
pub inline fn RPI_PWM_DMAC_PANIC(val: anytype) @TypeOf((val & @as(c_int, 0xff)) << @as(c_int, 8)) {
    _ = &val;
    return (val & @as(c_int, 0xff)) << @as(c_int, 8);
}
pub inline fn RPI_PWM_DMAC_DREQ(val: anytype) @TypeOf((val & @as(c_int, 0xff)) << @as(c_int, 0)) {
    _ = &val;
    return (val & @as(c_int, 0xff)) << @as(c_int, 0);
}
pub const PWM_OFFSET = 0x0020c000;
pub const PWM_PERIPH_PHYS = 0x7e20c000;
pub const WS2811_TARGET_FREQ = 800000;
pub const SK6812_STRIP_RGBW = 0x18100800;
pub const SK6812_STRIP_RBGW = 0x18100008;
pub const SK6812_STRIP_GRBW = 0x18081000;
pub const SK6812_STRIP_GBRW = 0x18080010;
pub const SK6812_STRIP_BRGW = 0x18001008;
pub const SK6812_STRIP_BGRW = 0x18000810;
pub const SK6812_SHIFT_WMASK = 0xf0000000;
pub const WS2811_STRIP_RGB = 0x00100800;
pub const WS2811_STRIP_RBG = 0x00100008;
pub const WS2811_STRIP_GRB = 0x00081000;
pub const WS2811_STRIP_GBR = 0x00080010;
pub const WS2811_STRIP_BRG = @as(c_int, 0x00001008);
pub const WS2811_STRIP_BGR = @as(c_int, 0x00000810);
pub const WS2812_STRIP = WS2811_STRIP_GRB;
pub const SK6812_STRIP = WS2811_STRIP_GRB;
pub const SK6812W_STRIP = SK6812_STRIP_GRBW;
pub inline fn WS2811_RETURN_STATES(X: anytype) @TypeOf(X(-@as(c_int, 14), WS2811_ERROR_SPI_TRANSFER, "SPI transfer error")) {
    _ = &X;
    return blk: {
        _ = X(@as(c_int, 0), WS2811_SUCCESS, "Success");
        _ = X(-@as(c_int, 1), WS2811_ERROR_GENERIC, "Generic failure");
        _ = X(-@as(c_int, 2), WS2811_ERROR_OUT_OF_MEMORY, "Out of memory");
        _ = X(-@as(c_int, 3), WS2811_ERROR_HW_NOT_SUPPORTED, "Hardware revision is not supported");
        _ = X(-@as(c_int, 4), WS2811_ERROR_MEM_LOCK, "Memory lock failed");
        _ = X(-@as(c_int, 5), WS2811_ERROR_MMAP, "mmap() failed");
        _ = X(-@as(c_int, 6), WS2811_ERROR_MAP_REGISTERS, "Unable to map registers into userspace");
        _ = X(-@as(c_int, 7), WS2811_ERROR_GPIO_INIT, "Unable to initialize GPIO");
        _ = X(-@as(c_int, 8), WS2811_ERROR_PWM_SETUP, "Unable to initialize PWM");
        _ = X(-@as(c_int, 9), WS2811_ERROR_MAILBOX_DEVICE, "Failed to create mailbox device");
        _ = X(-@as(c_int, 10), WS2811_ERROR_DMA, "DMA error");
        _ = X(-@as(c_int, 11), WS2811_ERROR_ILLEGAL_GPIO, "Selected GPIO not possible");
        _ = X(-@as(c_int, 12), WS2811_ERROR_PCM_SETUP, "Unable to initialize PCM");
        _ = X(-@as(c_int, 13), WS2811_ERROR_SPI_SETUP, "Unable to initialize SPI");
        break :blk X(-@as(c_int, 14), WS2811_ERROR_SPI_TRANSFER, "SPI transfer error");
    };
}
pub const WS2811_RETURN_STATES_ENUM = @compileError("unable to translate C expr: unexpected token '='");
// ./ws2811.h:113:9
pub inline fn WS2811_RETURN_STATES_STRING(state: anytype, name: anytype, str: anytype) @TypeOf(str) {
    _ = &state;
    _ = &name;
    _ = &str;
    return str;
}
pub const TARGET_FREQ = WS2811_TARGET_FREQ;
pub const DMA = @as(c_int, 10);
pub const GPIO_PIN = @as(c_int, 18);
pub const LED_COUNT = @as(c_int, 3);
pub const STRIP_TYPE = WS2811_STRIP_GRB;
pub const ws2811_device = struct_ws2811_device;
