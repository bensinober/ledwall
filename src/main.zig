const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const net = std.net;
const posix = std.posix;
const gpiod = @import("gpiod.zig");
const ssd1305 = @import("ssd1305.zig");
//const ws281x = @import("ws281x.zig");
const ws2811 = @import("ws2811.zig");
const img = @import("img.zig");

const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const time = std.time;

var display: ssd1305.Display = undefined;
var spiBus: ssd1305.SpiBus = undefined;

const HALL_PIN = 23; // TODO: add hall sensor
const LEDSTRIP_LENGTH = 50; // = img height
const LEDSTRIP_PIN_A = 18; // GPIO18 (12)
const LEDSTRIP_PIN_B = 13; // GPIO13(33)
//const LEDSTRIP_PIN = 28; // =18 = GPIO4_D4 = pin 3*8+4 = 28

const BTN_A_PIN = 17; // pin 13 -> GPIO17
//const BTN_B_PIN = 18; // pin 15 -> GPIO18
const ROT_A_PIN = 5; // pin 29 -> GPIO5
const ROT_B_PIN = 6; // pin 31 -> GPIO6

const Control = struct {
    const Self = @This();

    chip: ?*gpiod.struct_gpiod_chip,
    led: ?*gpiod.struct_gpiod_line,
    btnA: ?*gpiod.struct_gpiod_line,
    rotA: ?*gpiod.struct_gpiod_line,
    rotB: ?*gpiod.struct_gpiod_line,

    pub fn init(chip: ?*gpiod.struct_gpiod_chip) Self {
        // led
        const ledLine = gpiod.gpiod_chip_get_line(chip, HALL_PIN); // gpiod_chip_get_lines for bulk
        const baLine = gpiod.gpiod_chip_get_line(chip, BTN_A_PIN);
        const raLine = gpiod.gpiod_chip_get_line(chip, ROT_A_PIN);
        const rbLine = gpiod.gpiod_chip_get_line(chip, ROT_B_PIN);
        _ = gpiod.gpiod_line_request_output(ledLine, "ledblink", 0);
        const buttonConfig = &gpiod.gpiod_line_request_config{
            .consumer = "hologlobe",
            .request_type = gpiod.GPIOD_LINE_REQUEST_DIRECTION_INPUT,
            .flags = gpiod.GPIOD_LINE_REQUEST_FLAG_BIAS_PULL_UP,
        };
        _ = gpiod.gpiod_line_request(baLine, buttonConfig, 1);
        //_ = gpiod.gpiod_line_request_falling_edge_events(baLine, "buttons");
        _ = gpiod.gpiod_line_request_input(raLine, "rota");
        _ = gpiod.gpiod_line_request_input(rbLine, "rotb");
        return Self{
            .chip = chip,
            .led = ledLine,
            .btnA = baLine,
            .rotA = raLine,
            .rotB = rbLine,
        };
    }
    pub fn deinit(self: Self) void {
        _ = gpiod.gpiod_line_release(self.led);
    }

    pub fn led_blink(self: Self) void {
        std.debug.print("blinking led\n", .{});
        _ = gpiod.gpiod_line_set_value(self.led, 1);
        std.Thread.sleep(200 * 1000 * 1000); // 200ms
        _ = gpiod.gpiod_line_set_value(self.led, 0);
    }

    // TOOD: bulk register buttons and listen for falling edge
    pub fn pollButtonEvents(self: *Self) !void {
        var press: u3 = 0;
        const ba = gpiod.gpiod_line_get_value(self.btnA);
        if (ba == 0) {
            press = 1;
        }
        if (press > 0) {
            self.led_blink();

            switch (press) {
                1 => {
                    //try synth.selectPrevSoundFont();
                },
                else => {
                    std.debug.print("Unknown button\n", .{});
                },
            }
        }
    }
};

// convert pixel to u32 and insert in led channel
// pixel is rgb, ws2811 lib handles conversion to grb
fn setPixel(ledstrip: [*c]ws2811.ws2811_t, chan: usize, idx: usize, pixel: [4]u8) void {
    const val1: u32 = (@as(u32, pixel[0]) << 24) | (@as(u32, pixel[1]) << 16) | (@as(u32, pixel[2]) << 8) | @as(u32, pixel[3]);
    //const val2: u32 = std.mem.readPackedInt(u32, pixel[0..4], 0, .big);
    //std.debug.print("pixel: {x}, bigend: 0x{x:0>8}, 0x{x:0>8}\n", .{ pixel, val1, val2 });
    ledstrip.*.channel[chan].leds[idx] = val1;
}

// transform png data [][4]u8 to row slice matrix prepared for led strip length
fn imgbytes2matrix(bytes: []const u8) ![img.ROWS][img.COLS][4]u8 {
    var stream = std.io.fixedBufferStream(bytes);
    const reader = stream.reader();
    var mat: [img.ROWS][img.COLS][4]u8 = undefined;
    var pixel: [4]u8 = undefined; // in bigendian MSB format
    outer: for (0..img.ROWS) |i| {
        for (0..img.COLS) |j| {
            const bytes_read = try reader.read(pixel[0..]);
            if (bytes_read == 0) {
                break :outer; // no more data
            }
            mat[i][j] = pixel;
            //setPixel(ledstrip, 0, i, pixel);
            //setPixel(ledstrip, 1, i, pixel);
        }
        //_ = ws2811.ws2811_render(ledstrip); // show row
    }
    return mat;
}

// render img to two strips, split in half, display in each channel
// source image is 50x100 24bit, rotated and
fn renderImg(ledstrip: [*c]ws2811.ws2811_t, mat: [img.ROWS][img.COLS][4]u8) void {
    const half = img.ROWS / 2; // split rows in two, one for each strip
    for (0..half) |i| {
        for (0..img.COLS) |j| {
            setPixel(ledstrip, 0, j, mat[i][j]);
            setPixel(ledstrip, 1, j, mat[i + half][j]);
        }
        _ = ws2811.ws2811_render(ledstrip); // show row
        //std.Thread.sleep(325000); // sleep 350us to balance frame rate of 5Hz
    }
}

fn lightAllLeds(ledstrip: [*c]ws2811.ws2811_t, col: u32) void {
    var i: usize = 0;
    var j: usize = 0;
    while (i < LEDSTRIP_LENGTH) : (i += 1) {
        ledstrip.*.channel[0].leds[i] = col;
    }
    while (j < LEDSTRIP_LENGTH) : (j += 1) {
        ledstrip.*.channel[1].leds[j] = col;
    }
    _ = ws2811.ws2811_render(ledstrip);
}
// Get WIFI IP address by fake UDP connection
pub fn getLocalAddress(alloc: Allocator) ![]const u8 {
    const addr = try std.net.Address.parseIp("1.1.1.1", 0);
    const sock = try posix.socket(posix.AF.INET, posix.SOCK.DGRAM, posix.IPPROTO.UDP);
    defer posix.close(sock);
    try posix.connect(sock, &addr.any, addr.getOsSockLen());

    var address: net.Address = undefined;
    var len: posix.socklen_t = @sizeOf(net.Address);
    try posix.getsockname(sock, &address.any, &len);
    const out = try std.fmt.allocPrint(alloc, "{any}", .{address});
    return out;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    // Prints to stderr, shortcut based on `std.io.getStdErr()`
    std.debug.print("Testing zig for hologlobe Magic!.\n", .{});

    const addr = try getLocalAddress(allocator);
    std.debug.print("hologlobe IP addr: {s}\n", .{addr});

    const controlChip = gpiod.gpiod_chip_open_by_name("gpiochip0");
    // ws281x
    // const ledChip = gpiod.gpiod_chip_open_by_name("gpiochip4");
    // var ledCtrl = ws281x.WS281x.init(ledChip, LEDSTRIP_PINA);
    // defer ledCtrl.deinit();
    // ledCtrl.showColor(0xff, 0xff, 0xa0);
    // ledCtrl.sendReset();

    // ws2811
    var ledstrip = ws2811.ws2811_t{
        .render_wait_time = 0,
        .device = null,
        .rpi_hw = null,
        .freq = 800000,
        .dmanum = 10,
        .channel = [2]ws2811.ws2811_channel_t{
            ws2811.ws2811_channel_t{
                .gpionum = LEDSTRIP_PIN_A,
                .invert = 0,
                .count = LEDSTRIP_LENGTH,
                .strip_type = ws2811.WS2811_STRIP_GRB,
                .leds = null,
                .brightness = 20,
                .wshift = 0x00,
                .rshift = 0x00,
                .gshift = 0x00,
                .bshift = 0x00,
                .gamma = null,
            },
            ws2811.ws2811_channel_t{
                .gpionum = LEDSTRIP_PIN_B,
                .invert = 0,
                .count = LEDSTRIP_LENGTH,
                .strip_type = ws2811.WS2811_STRIP_GRB,
                .leds = null,
                .brightness = 20,
                .wshift = 0x00,
                .rshift = 0x00,
                .gshift = 0x00,
                .bshift = 0x00,
                .gamma = null,
            },
        },
    };
    _ = ws2811.ws2811_init(&ledstrip);
    defer ws2811.ws2811_fini(&ledstrip);
    const imgMatrix = try imgbytes2matrix(&img.DATA);

    var timer = std.time.Timer.start() catch |err| {
        std.debug.print("err: {any}\n", .{err});
        return;
    };
    // Startup, blink red, green and blue
    lightAllLeds(&ledstrip, 0xff0000);
    std.debug.print("ns spent on green cycle: {}\n", .{timer.lap()});
    std.Thread.sleep(500 * 1000 * 1000);
    timer.reset();
    lightAllLeds(&ledstrip, 0x00ff00);
    std.debug.print("ns spent on red cycle: {}\n", .{timer.lap()});
    std.Thread.sleep(500 * 1000 * 1000);
    timer.reset();
    lightAllLeds(&ledstrip, 0x0000ff);
    std.debug.print("ns spent on blue cycle: {}\n", .{timer.lap()});
    std.Thread.sleep(500 * 1000 * 1000);
    lightAllLeds(&ledstrip, 0x000000);
    std.Thread.sleep(1000 * 1000 * 1000);

    // SPI AND DISPLAY INIT
    const arch = @import("builtin").target.cpu.arch;
    if (arch != std.Target.Cpu.Arch.x86_64) {
        const fd = try fs.openFileAbsolute("/dev/spidev0.0", fs.File.OpenFlags{
            .mode = .read_write,
        });
        defer fd.close();
        const spiDev = ssd1305.SPIDevice{
            .fd = fd,
            .speedHz = 4000000, // 125000000 Hz max, but +7Mhz will probably give blank
            .csChange = 0,
            .mode = 0x04, // MODE_3
            .bpw = 8,
            .delayUsecs = 0,
        };

        // spi, dc, rst, cs
        spiBus = ssd1305.SpiBus.init(spiDev, 25, 24, 8);
        std.debug.print("ssd1305 spi bus initiated\n", .{});
        const config = ssd1305.Config{
            .Width = 128,
            .Height = 32,
            .Rotation = 2, // 180 degrees
            .VccState = ssd1305.EXTERNALVCC,
        };
        display = try ssd1305.Display.init(allocator, config, &spiBus);

        // Initialize display registry
        try display.initReg();
        std.Thread.sleep(200 * 1000 * 1000); // 200ms
        // Turn on the OLED display
        display.Command(ssd1305.DISPLAYON);
        std.debug.print("ssd1305 display initiated!\n", .{});

        // print logo
        try display.SetBuffer(logoBuffer, buflen);
        display.Display();
        std.Thread.sleep(1 * 1000 * 1000 * 1000); // 1s

        // show local ip on display
        display.ClearDisplay();
        display.writeLine(addr, 0);
        display.Display();
        std.Thread.sleep(2 * 1000 * 1000 * 1000); // 1s

        // start
        display.ClearDisplay();
        display.writeLine("  < PROG >  < INSTR >", 0);
        display.Display();

        // we need to hold GPIO and Display allocated until exit
        defer spiBus.deinit();
        defer display.deinit();
    }

    // GPIO handling - only for raspberry pi
    if (@import("builtin").target.cpu.arch != std.Target.Cpu.Arch.x86_64) {
        var control = Control.init(controlChip);
        control.led_blink();
        std.debug.print("first blink done\n", .{});
        while (true) {
            //try control.pollButtonEvents();
            const start = try std.time.Instant.now();
            renderImg(&ledstrip, imgMatrix);
            const end = try std.time.Instant.now();
            std.debug.print("ns spent on full render: {}\n", .{end.since(start)});
            std.Thread.sleep(1000 * 1000); // 1ms
        }
    } else {
        std.Thread.sleep(180 * 1000 * 1000 * 1000);
    }
}

const SSD1305_LCDHEIGHT = 32;
const SSD1305_LCDWIDTH = 128;
const buflen = SSD1305_LCDHEIGHT * SSD1305_LCDWIDTH / 8;
var logoBuffer: [buflen]u8 = [buflen]u8{
    // 'paels-128x32', 128x32px (16 x 32 bytes x 8 bits)
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x40, 0xa0, 0xa0, 0xd0, 0x10, 0x70, 0x40, 0x30, 0xa0, 0x20, 0xc0, 0x90, 0xb0, 0x60,
    0x20, 0x60, 0x60, 0xa0, 0xe0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0xe0, 0xb0, 0x20, 0x10, 0x10,
    0x20, 0x40, 0x50, 0x70, 0xd0, 0xc0, 0x90, 0x90, 0x20, 0x20, 0x10, 0xd0, 0xd0, 0x00, 0x90, 0xf0,
    0xe0, 0x20, 0xe0, 0x00, 0x00, 0x00, 0x00, 0x20, 0x60, 0x30, 0x00, 0x60, 0x30, 0xa0, 0xc0, 0xf0,
    0xb0, 0x60, 0x20, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x40, 0x60, 0x20, 0xb0, 0x10, 0xe0,
    0x60, 0xd0, 0x80, 0xe0, 0x90, 0x60, 0x60, 0xe0, 0x30, 0xe0, 0xe0, 0x60, 0xc0, 0xc0, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x08, 0xcd, 0xb5, 0x98, 0x46, 0x69, 0x89, 0x36, 0x7b, 0x82, 0x40, 0xc0, 0x80, 0x23,
    0xb5, 0xdc, 0x63, 0x29, 0xd8, 0xf7, 0x24, 0x00, 0x00, 0x00, 0xe8, 0x6b, 0x8b, 0x26, 0x12, 0x19,
    0x39, 0x23, 0xde, 0x63, 0x21, 0xc1, 0x01, 0xa1, 0xa1, 0x21, 0x01, 0x20, 0xa1, 0xe1, 0x81, 0xc0,
    0xc1, 0x02, 0x01, 0x00, 0x00, 0x00, 0x80, 0x64, 0x45, 0x89, 0xeb, 0x24, 0xb5, 0x4b, 0xfc, 0xf6,
    0x1f, 0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x05, 0x31, 0x1c, 0xe7, 0xa1, 0x5a, 0x5b,
    0xcf, 0xdc, 0x30, 0x60, 0xe0, 0xc0, 0xc1, 0xc5, 0xc6, 0x86, 0x05, 0x07, 0x07, 0x03, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x10, 0xf6, 0xf6, 0x89, 0x6e, 0xa9, 0xd1, 0x37, 0xed, 0x73, 0x02, 0x03, 0x03, 0x03,
    0x02, 0x01, 0x01, 0x01, 0x01, 0x00, 0x00, 0xc0, 0x28, 0x2e, 0x23, 0x48, 0x59, 0x33, 0xf3, 0x07,
    0x06, 0x03, 0x4f, 0xaa, 0x89, 0x5c, 0xf2, 0x82, 0x42, 0x03, 0x43, 0xc0, 0x83, 0x02, 0x62, 0x83,
    0xc0, 0x40, 0xc0, 0x80, 0x00, 0x60, 0x4d, 0xb1, 0x3c, 0x89, 0xb0, 0xcf, 0x59, 0x7f, 0xdf, 0x84,
    0x80, 0x80, 0x80, 0x80, 0x80, 0x80, 0x00, 0x80, 0x80, 0x80, 0x80, 0x00, 0xf0, 0x10, 0x31, 0x81,
    0xf0, 0xf2, 0x81, 0x83, 0x82, 0x85, 0x05, 0x6d, 0x91, 0x9f, 0xe7, 0xb7, 0xff, 0xde, 0x78, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x02, 0x03, 0x07, 0x03, 0x03, 0x03, 0x07, 0x07, 0x01, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x03, 0x03, 0x03, 0x03, 0x02, 0x03, 0x07, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x03, 0x03, 0x02, 0x06, 0x05, 0x05, 0x06, 0x04, 0x04, 0x07, 0x06, 0x04, 0x06,
    0x04, 0x03, 0x03, 0x00, 0x00, 0x00, 0x03, 0x03, 0x06, 0x06, 0x01, 0x06, 0x02, 0x03, 0x06, 0x02,
    0x01, 0x03, 0x03, 0x03, 0x06, 0x03, 0x03, 0x07, 0x07, 0x07, 0x00, 0x00, 0x03, 0x02, 0x07, 0x03,
    0x04, 0x03, 0x03, 0x07, 0x07, 0x06, 0x03, 0x03, 0x03, 0x03, 0x06, 0x03, 0x01, 0x01, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
};
