const std = @import("std");
const mem = std.mem;
const gpiod = @import("gpiod.zig");
const fs = std.fs;
const ioctl = std.os.linux.ioctl;
const Allocator = mem.Allocator;

const DisplayError = error{
    BufferOverflow,
    OutOfBounds,
};

const SSD1305_LCDHEIGHT = 32;
const SSD1305_LCDWIDTH = 128;
var bufSize: usize = 512; // TODO: set bufSize dynamic? now it is 128 * 32 = 512 hardcoded

// SSD1305 Registers from adafruit ssd1305
// https://github.com/chilledoj/ssd1305
const SSD1305_I2C_ADDRESS = 0x3C; // 011110+SA0+RW - 0x3C or 0x3D

const SSD1305_SETLOWCOLUMN = 0x00;
const SSD1305_SETHIGHCOLUMN = 0x10;
const SSD1305_MEMORYMODE = 0x20;
const SSD1305_SETCOLADDR = 0x21;
const SSD1305_SETPAGEADDR = 0x22;
const SSD1305_SETSTARTLINE = 0x40;
const SSD1305_SETCONTRAST = 0x81;
const SSD1305_SETBRIGHTNESS = 0x82;
const SSD1305_CHARGEPUMP = 0x8D;
const SSD1305_SETLUT = 0x91;
const SSD1305_SEGREMAP = 0xA0;
const SSD1305_DISPLAYALLON_RESUME = 0xA4;
const SSD1305_DISPLAYALLON = 0xA5;
const SSD1305_NORMALDISPLAY = 0xA6;
const SSD1305_INVERTDISPLAY = 0xA7;
const SSD1305_SETMULTIPLEX = 0xA8;
const SSD1305_DISPLAYDIM = 0xAC;
const SSD1305_MASTERCONFIG = 0xAD;
const SSD1305_DISPLAYOFF = 0xAE;
const SSD1305_DISPLAYON = 0xAF;
const SSD1305_SETPAGESTART = 0xB0;
const SSD1305_COMSCANINC = 0xC0;
const SSD1305_COMSCANDEC = 0xC8;
const SSD1305_SETDISPLAYOFFSET = 0xD3;
const SSD1305_SETDISPLAYCLOCKDIV = 0xD5;
const SSD1305_SETAREACOLOR = 0xD8;
const SSD1305_SETPRECHARGE = 0xD9;
const SSD1305_SETCOMPINS = 0xDA;
const SSD1305_SETVCOMLEVEL = 0xDB;
// scroll
const SSD1305_ACTIVATESCROLL = 0x2F;
const SSD1305_DEACTIVATESCROLL = 0x2E;
const SSD1305_SETVERTICALSCROLLAREA = 0xA3;
const SSD1305_RIGHTHORIZONTALSCROLL = 0x26;
const SSD1305_LEFTHORIZONTALSCROLL = 0x27;
const SSD1305_VERTICALANDRIGHTHORIZONTALSCROLL = 0x29;
const SSD1305_VERTICALANDLEFTHORIZONTALSCROLL = 0x2A;

pub const DISPLAYON = 0xAF;

// Config is the configuration for the display
pub const EXTERNALVCC: u8 = 0x1; // VCCState external Voltage
pub const SWITCHCAPVCC: u8 = 0x2; // VCCState internal
pub const Config = struct {
    Width: i16,
    Height: i16,
    Rotation: i16, // 0: normal, 1: 90 deg, 2: 180 deg, 3: 270 deg
    VccState: u8, // ssd1305.EXTERNALVCC (1: ext) ssd1305.SWITCHCAPVCC (2: internal)
};

pub const Colour = struct {
    R: u8,
    G: u8,
    B: u8,
    A: u8,
};

// SPI driven Display
pub const Display = struct {
    const Self = @This();

    allocator: Allocator,
    bus: *SpiBus,
    buffer: []u8,
    width: i16,
    height: i16,
    bufferSize: usize,
    vccState: u8,
    canReset: bool,
    rotation: i16,

    // Configure initializes the display with default configuration
    pub fn init(allocator: Allocator, cfg: Config, bus: *SpiBus) !Self {
        // if (cfg.Height == 32) {
        //  bufSize = 512; // 128 * 32 / 8
        // } else {
        //  bufSize = 1024; // 128 * 64 / 8
        // }
        //const bufSize = @intCast(usize, @divFloor(cfg.Width * cfg.Height, 8)); // floored division
        //var buffer: ?[]u8 = null;
        //var buffer = std.mem.zeroes([bufSize]u8);
        const buffer = try allocator.alloc(u8, bufSize);
        errdefer {
            if (buffer) |value| allocator.free(value);
        }

        var canReset: bool = false;
        if (cfg.Width != 128) {
            canReset = true;
        }
        if (cfg.Height != 64) {
            canReset = true;
        }
        // Hardware Reset
        bus.dcToggle(true);
        bus.configure();
        std.Thread.sleep(100); // 100us
        return Self{
            .allocator = allocator,
            .bus = bus,
            .buffer = buffer,
            .width = cfg.Width,
            .height = cfg.Height,
            .bufferSize = bufSize,
            .vccState = cfg.VccState,
            .canReset = canReset,
            .rotation = cfg.Rotation,
        };
    }

    // init 128x32 oled display
    pub fn initReg(self: *Self) !void {
        self.Command(SSD1305_DISPLAYOFF); // 0xae (0xac = dim)

        self.Command(SSD1305_SETDISPLAYCLOCKDIV); //--set display clock divide ratio/oscillator frequency
        self.Command(0x80); // Set display clock ratio: 0xd5, 0xf0 (was 0x80)
        self.Command(SSD1305_SEGREMAP | 0x01); // 0x00 will invert
        self.Command(SSD1305_SETMULTIPLEX); //--set multiplex ratio(1 to 64)
        self.Command(0x1F); // Setmultiplex 0xa8, 0x3f (was 0x3f) // height - 1
        self.Command(SSD1305_SETDISPLAYOFFSET);
        self.Command(0x00); // Set display offset 0xd3, 0x40 // was 0x40
        self.Command(SSD1305_MASTERCONFIG);
        self.Command(0x8E); // Set master config: external vcc supply
        self.Command(SSD1305_SETAREACOLOR); // 0xd8
        self.Command(0x05);
        self.Command(SSD1305_MEMORYMODE); // 0x20
        self.Command(0x00);
        self.Command(SSD1305_SETSTARTLINE | 0x0);
        self.Command(0x2e); // deactivate scrolling ?
        self.Command(SSD1305_COMSCANDEC);
        self.Command(SSD1305_SETCOMPINS);
        self.Command(0x12); //--set com pins hardware configuration 0xda, 0x12
        self.Command(SSD1305_SETLUT); // memory bank BANK0 colors A,B,C off
        self.Command(0x3f);
        self.Command(0x3f);
        self.Command(0x3f);
        self.Command(0x3f);
        self.Command(SSD1305_SETCONTRAST);
        self.Command(0x2f); // Setcontrast 0x81, 0x2f (was 0x32) // max = 0xff
        self.Command(SSD1305_SETPRECHARGE); // 0xd9
        self.Command(0xd2); // 0xd9, 0xf1 (was 0xc2)
        self.Command(SSD1305_SETVCOMLEVEL);
        self.Command(0x34); //--set vcom level 0xdb, 0x08 (was 0x08)
        self.Command(SSD1305_NORMALDISPLAY); //--set normal display // 0xA6
        self.Command(SSD1305_DISPLAYALLON_RESUME); // output follows ram content
        self.Command(SSD1305_CHARGEPUMP); //
        self.Command(0x10); // charge pump for external vcc

        //self.Command(SSD1305_SETLOWCOLUMN | 0x0);
        //self.Command(SSD1305_SETHIGHCOLUMN | 0x0);
        //self.Command(SSD1305_SETBRIGHTNESS);
        //self.Command(0x10); // Setcontrast 0x82, 0x10

        std.Thread.sleep(100 * 1000 * 1000); // 100ms
        self.Command(SSD1305_DISPLAYON); // 0xaf
    }

    // ClearBuffer clears the image buffer
    pub fn ClearBuffer(self: *Self, chFill: u8) void {
        const limit = self.buffer.len;
        var i: usize = 0;
        while (i < limit) : (i += 1) {
            self.buffer[i] = chFill;
        }
    }

    // ClearDisplay clears the image buffer and clear the display
    pub fn ClearDisplay(self: *Self) void {
        self.ClearBuffer(0x00);
        self.Display();
    }
    // FillDisplay fills the image buffer
    pub fn FillDisplay(self: *Self) void {
        self.ClearBuffer(0xFF);
        self.Display();
    }

    pub fn Invert(self: *Self, i: bool) void {
        if (i == true) {
            self.Command(SSD1305_INVERTDISPLAY);
        } else {
            self.Command(SSD1305_NORMALDISPLAY);
        }
    }

    // Display sends the whole buffer to the screen's buffer
    // 4 rows of u8 = 32 lines
    // TODO: handle rotate
    pub fn Display(self: *Self) void {
        //std.debug.print("Display buffer : {any}\n", .{self.buffer});
        std.Thread.sleep(50 * 1000 * 1000); // 50ms needed for display to sync
        var row: u8 = 0;
        while (row < 4) : (row += 1) {
            self.Command(SSD1305_SETPAGESTART + row);
            self.Command(SSD1305_SETLOWCOLUMN | 0x0); // Offset right in pixles
            self.Command(SSD1305_SETHIGHCOLUMN | 0x0); // Offset top in pixles
            self.bus.dcToggle(true);
            //std.os.nanosleep(0, 1 * 1000 * 1000); // 1Hz
            var num: u16 = 0;
            while (num < SSD1305_LCDWIDTH) : (num += 1) {
                self.Data(self.buffer[@as(u16, row) * SSD1305_LCDWIDTH + num]);
            }
        }
    }

    // Command is a helper function to write a command to the display
    pub fn Command(self: *Self, cmd: u8) void {
        //std.debug.print("SPI BUS CMD: {any}\n", .{cmd});
        self.Tx(cmd, true);
    }

    // Data is a helper function to write data to the display
    fn Data(self: *Self, data: u8) void {
        self.Tx(data, false);
    }
    // Tx sends data/command to the display
    fn Tx(self: *Self, data: u8, isCommand: bool) void {
        self.bus.tx(data, isCommand);
    }

    // SetPixel enables or disables a pixel in the buffer
    // color.RGBA{0, 0, 0, 255} is consider transparent, anything else
    // with enable a pixel on the screen
    // For OLED this is a bit overkill, but...
    pub fn SetPixel(self: *Self, x: i16, y: i16, c: Colour) void {
        if (x < 0) {
            return;
        }
        if (x > self.width) {
            return;
        }
        if (y < 0) {
            return;
        }
        if (y > self.height) {
            return;
        }

        var xx: i16 = x;
        var yy: i16 = y;
        // rotate
        if (self.rotation == 0) {} else if (self.rotation == 1) {
            // swapped x, y
            yy = x;
            xx = self.width - y - 1;
        } else if (self.rotation == 2) {
            //xx = self.width - x - 1;
            yy = self.height - y - 1;
        } else if (self.rotation == 3) {
            // swap x, y
            xx = y;
            yy = self.height - x - 1;
        }
        const page: i16 = 3 - @divFloor(yy, 8); // vertical pos
        const pos: usize = @as(usize, @intCast((SSD1305_LCDWIDTH * page + xx))); // horizontal pos
        const chBx: i16 = @mod(yy, 8);
        const chTemp: u8 = @as(u8, 1) <<| @as(i16, (7 - chBx));
        if (c.R > 0) {
            self.buffer[pos] |= chTemp;
        } else if (c.G > 0) {
            self.buffer[pos] |= chTemp;
        } else if (c.B > 0) {
            self.buffer[pos] |= chTemp;
        } else {
            self.buffer[pos] &= chTemp; // bit off
        }
    }

    // GetPixel returns if the specified pixel is on (true) or off (false)
    fn GetPixel(self: *Self, x: i16, y: i16) bool {
        if (x < 0) {
            return false;
        } else if (x >= self.width) {
            return false;
        } else if (y < 0) {
            return false;
        } else if (y >= self.height) {
            return false;
        }
        const page = 3 - y / 8;
        if (self.buffer[SSD1305_LCDWIDTH * page + x] >> @as(u8, (y % 8) & 0x1) == 1) {
            return true;
        }
        return false;
    }

    // SetBuffer changes the whole buffer at once
    pub fn SetBuffer(self: *Self, buffer: [512]u8, len: usize) !void {
        if (@as(usize, @intCast(len)) != self.bufferSize) {
            std.debug.print("error caught\n", .{});
            return DisplayError.BufferOverflow;
        }
        var i: usize = 0;
        while (i < self.bufferSize) : (i += 1) {
            self.buffer[i] = buffer[i];
        }
        return;
    }

    // Size returns the current size of the display.
    fn Size(self: Self) struct { w: i16, h: i16 } {
        return .{
            .width = self.width,
            .heght = self.height,
        };
    }

    // drawing a bitmap involves a pos top left x,y, a byte slice, a width + height, and a colour (basically anything in monochrome)
    // each byte is 8 pixels wide, so we just loop bits until end of width/height
    pub fn DrawBitmap(self: *Self, x0: i16, y0: i16, bmp: []const u8, w: u8, h: u8) void {
        //const byteWidth: usize = @divFloor((w + 7), 8); // how many bytes per row? = bitmap scanline pad (width + 7 / 8)
        //std.debug.print("FOO: {any} {any} {any} {any} {any} {any}\n", .{x, y, bmp, byteWidth, w, h});
        var line: u8 = 0;
        var y: u8 = 0;
        var srcMask: u8 = 0x80;
        var pos: u8 = 0;
        while (y < h) : (y += 1) {
            var x: u8 = 0;
            line = bmp[pos >> 3];
            while (x < w) : (x += 1) {
                //if (line & 0x80 > 0) {
                if (line & srcMask > 0) {
                    self.SetPixel(x0 + x, y0 + y, Colour{ .R = 100, .G = 0, .B = 0, .A = 0 });
                    srcMask >>= 1;
                    if (srcMask == 0) {
                        srcMask = 0x80;
                        pos += 1; // (y * byteWidth) + (x / 8);
                        line = bmp[pos];
                    }
                }
                line = line << 1;
            }
        }
    }

    // pub fn DrawBitmap(self: Self, x0: i16, y0: i16, bmp: []const u8, _: u8, _: u8) void {
    //  var i: i8 = 0;
    //     while (i < 5) : (i += 1) { // Char bitmap = 5 columns
    //      var line = bmp[@intCast(usize, i)];
    //      var j: i8 = 0;
    //      while (j < 8) : (j += 1) {
    //          if (line & 1 > 0) {
    //              self.SetPixel(x0 + i, y0 + j, Colour{ .R = 100, .G = 0, .B = 0, .A = 0});
    //          }
    //          line >>= 1;
    //         }
    //     }
    // }

    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
    }

    // write fixed width string (cursor 6x8) to display buffer. rows 0-3, cols 0-21 (128/6)
    // TODO : newline, overflow string, etc.
    pub fn writeString(self: *Self, str: []const u8, row: i16, col: i16, len: usize) void {
        var change: u8 = 0; // tmp for registering if update is needed
        const fontW: i16 = 6;
        const fontH: i16 = 8;
        const colLength = @divTrunc(self.width, fontW); // 21
        const rowLength = @divTrunc(self.height, fontH); // 4
        // for simplicity we only allow positive row/col
        if (row > rowLength - 1) {
            return;
        } else if (col > colLength - 1) {
            return;
        }
        // Write the data into the display buffer - while checking the written data is an actual change to the buffer
        const startPos: usize = @as(usize, @intCast((row * self.width) + col));
        //std.debug.print("startPos {d} {d}\n", .{ colLength, startPos });
        var i: usize = 0;
        while (i < len) : (i += 1) {
            const offset: usize = @as(usize, @intCast((i * fontW)));
            var j: u8 = 0;
            while (j < fontW) : (j += 1) {
                // place the string characters through the lookup table*/
                const cur_dat = self.buffer[startPos + offset + j];
                const char: u16 = str[i] - 32; // we dont include the 32 first chars in the font table
                const new_dat: u8 = font5x7[char * fontW + j];
                if (cur_dat != new_dat) {
                    change += 1;
                    self.buffer[startPos + offset + j] = new_dat;
                }
            }
        }
        if (change > 0) {
            // Ssd1306_dirty_mark(row, row_end, col_adjusted, col_end);
        }
    }

    pub fn writeLine(self: *Self, str: []const u8, row: i16) void {
        const fontW: i16 = 6;
        const colLength = @divTrunc(self.width, fontW); // 21
        const startPos: usize = @as(usize, @intCast(row * self.width));
        var i: usize = 0;
        while (i < colLength) : (i += 1) {
            const offset: usize = @as(usize, @intCast(i * fontW));
            var j: u8 = 0;
            while (j < fontW) : (j += 1) {
                const cur_dat = self.buffer[startPos + offset + j];
                if (i < str.len) {
                    const char: u16 = str[i] - 32; // we dont include the 32 first chars in the font table
                    const new_dat: u8 = font5x7[char * fontW + j];
                    if (cur_dat != new_dat) {
                        self.buffer[startPos + offset + j] = new_dat;
                    }
                } else {
                    self.buffer[startPos + offset + j] = font5x7[0]; // space
                }
            }
        }
    }
};

// SPI message struct

const spi_IOC_MAGIC = "k";
const spi_CPHA = 0x01;
const spi_CPOL = 0x02;

const spi_MODE_0 = 0;
const spi_MODE_1 = spi_CPHA;
const spi_MODE_2 = spi_CPOL;
const spi_MODE_3 = spi_CPOL | spi_CPHA;

const spi_CS_HIGH = 0x04;
const spi_LSB_FIRST = 0x08;
const spi_3WIRE = 0x10;
const spi_LOOP = 0x20;
const spi_NO_CS = 0x40;
const spi_READY = 0x80;
const spi_TX_DUAL = 0x100;
const spi_TX_QUAD = 0x200;
const spi_RX_DUAL = 0x400;
const spi_RX_QUAD = 0x800;

const spi_IOC_MESSAGE_base = 0x40006B00;
const spi_IOC_MESSAGE_incr = 0x200000;

// Read / Write of SPI mode (spi_MODE_0..spi_MODE_3) (limited to 8 bits);
const spi_IOC_RD_MODE = 0x80016B01;
const spi_IOC_WR_MODE = 0x40016B01;

// Read / Write SPI bit justification;
const spi_IOC_RD_LSB_FIRST = 0x80016B02;
const spi_IOC_WR_LSB_FIRST = 0x40016B02;

// Read / Write SPI device word length (1..N);
const spi_IOC_RD_BITS_PER_WORD = 0x80016B03;
const spi_IOC_WR_BITS_PER_WORD = 0x40016B03;

// Read / Write SPI device default max speed Hz;
const spi_IOC_RD_MAX_SPEED_HZ = 0x80046B04;
const spi_IOC_WR_MAX_SPEED_HZ = 0x40046B04;

// Read / Write of the SPI mode field;
const spi_IOC_RD_MODE32 = 0x80046B05;
const spi_IOC_WR_MODE32 = 0x40046B05;

pub fn spi_IOC_MESSAGE(n: u32) u32 {
    return spi_IOC_MESSAGE_base + n * spi_IOC_MESSAGE_incr;
}

const SPIIOCTransfer = struct {
    txBuf: u64, // ptr to xfer buffer
    rxBuf: u64, // ptr to recv buffer // .tx_buf = @bitCast(__u64, @as(c_ulonglong, @intCast(c_ulong, @ptrToInt(tx)))),
    len: usize, //u32
    speedHz: u32,
    delayUsecs: u16, // delay before next transfer
    bitsPerWord: u8,
    csChange: u8,
    //txNbits: u8,
    //rxNbits: u8,
    //wordDelayUsecs: u8,
    //pad: u8,
};

// SPI Device struct
pub const SPIDevice = struct {
    fd: fs.File, // file descriptor
    speedHz: u32, // SPI speed in Hz
    csChange: u8, // Chip select pin
    mode: u32,
    bpw: u8,
    delayUsecs: u16,
};

pub const SpiBus = struct {
    const Self = @This();

    device: SPIDevice,
    chip: ?*gpiod.struct_gpiod_chip,
    dcPin: ?*gpiod.struct_gpiod_line,
    rstPin: ?*gpiod.struct_gpiod_line,
    csPin: ?*gpiod.struct_gpiod_line,

    pub fn init(device: SPIDevice, dcPin: c_uint, rstPin: c_uint, csPin: c_uint) Self {
        const chp = gpiod.gpiod_chip_open_by_name("gpiochip0");
        std.debug.print("ssd1305 dc pin: {any}\n", .{dcPin});
        std.debug.print("ssd1305 rst pin: {any}\n", .{rstPin});
        std.debug.print("ssd1305 cs pin: {any}\n", .{csPin});
        const dc = gpiod.gpiod_chip_get_line(chp, dcPin);
        const rst = gpiod.gpiod_chip_get_line(chp, rstPin);
        const cs = gpiod.gpiod_chip_get_line(chp, csPin);
        _ = gpiod.gpiod_line_request_output(dc, "ssd1305", 0);
        _ = gpiod.gpiod_line_request_output(rst, "ssd1305", 0);
        _ = gpiod.gpiod_line_request_output(cs, "ssd1305", 0);
        return Self{
            .device = device,
            .chip = chp,
            .dcPin = dc,
            .rstPin = rst,
            .csPin = cs,
        };
    }

    // configure configures some pins with the SPI bus ( RESET )
    pub fn configure(self: *Self) void {
        _ = gpiod.gpiod_line_set_value(self.csPin, 0);
        _ = gpiod.gpiod_line_set_value(self.dcPin, 0);
        _ = gpiod.gpiod_line_set_value(self.rstPin, 0);

        _ = gpiod.gpiod_line_set_value(self.rstPin, 1);
        std.Thread.sleep(100 * 1000 * 1000); // 100ms
        _ = gpiod.gpiod_line_set_value(self.rstPin, 0);
        std.Thread.sleep(100 * 1000 * 1000); // 100ms
        _ = gpiod.gpiod_line_set_value(self.csPin, 1);
        _ = gpiod.gpiod_line_set_value(self.dcPin, 0);
        _ = gpiod.gpiod_line_set_value(self.rstPin, 1);
    }

    // tx sends data to the display (SPIBus implementation)
    pub fn tx(self: *Self, data: u8, isCommand: bool) void {
        if (isCommand == true) {
            _ = gpiod.gpiod_line_set_value(self.csPin, 1);
            _ = gpiod.gpiod_line_set_value(self.csPin, 0);
            _ = gpiod.gpiod_line_set_value(self.dcPin, 0);

            _ = self.Transfer(data);
            _ = gpiod.gpiod_line_set_value(self.csPin, 1);
        } else {
            _ = gpiod.gpiod_line_set_value(self.csPin, 1);
            _ = gpiod.gpiod_line_set_value(self.dcPin, 1);
            _ = gpiod.gpiod_line_set_value(self.csPin, 0);

            _ = self.Transfer(data);
            _ = gpiod.gpiod_line_set_value(self.csPin, 1);
        }
    }

    pub fn Transfer(self: *Self, data: u8) void {
        //std.debug.print("Sending data to wire: {any}\n", .{data});
        _ = gpiod.gpiod_line_set_value(self.csPin, 0);
        var rcv: u8 = 0x00;
        const tr = SPIIOCTransfer{
            .txBuf = @intFromPtr(&data), // @bitCast(__u64, @as(c_ulonglong, @intCast(c_ulong, @ptrToInt( [*c]const u8 )))),
            .rxBuf = @intFromPtr(&rcv),
            .len = @as(usize, 1),
            .speedHz = self.device.speedHz,
            .delayUsecs = self.device.delayUsecs,
            .bitsPerWord = self.device.bpw,
            .csChange = 0,
            //.txNbits = 8,
            //.rxNbits = 8,
            //.wordDelayUsecs = 0,
            //.pad = 0,
        };
        // send pointer to spi device for transfer
        if (ioctl(self.device.fd.handle, spi_IOC_MESSAGE(1), @intFromPtr(&tr)) < 0) {
            std.debug.print("ioctl failed, errno: {any}\n", .{tr});
        }
    }

    pub fn dcToggle(self: *Self, hilo: bool) void {
        if (hilo == true) {
            _ = gpiod.gpiod_line_set_value(self.dcPin, 1);
        } else {
            _ = gpiod.gpiod_line_set_value(self.dcPin, 0);
        }
    }
    pub fn deinit(self: *Self) void {
        _ = gpiod.gpiod_line_release(self.dcPin);
        _ = gpiod.gpiod_line_release(self.rstPin);
        _ = gpiod.gpiod_line_release(self.csPin);
        _ = gpiod.gpiod_chip_close(self.chip);
    }
};

const font5x7 = [_]u8{ // 128 x 6 bytes
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // sp
    0x00, 0x00, 0x00, 0x2f, 0x00, 0x00, // !
    0x00, 0x00, 0x07, 0x00, 0x07, 0x00, // "
    0x00, 0x14, 0x7f, 0x14, 0x7f, 0x14, // #
    0x00, 0x24, 0x2a, 0x7f, 0x2a, 0x12, // $
    0x00, 0x62, 0x64, 0x08, 0x13, 0x23, // %
    0x00, 0x36, 0x49, 0x55, 0x22, 0x50, // &
    0x00, 0x00, 0x05, 0x03, 0x00, 0x00, // '
    0x00, 0x00, 0x1c, 0x22, 0x41, 0x00, // (
    0x00, 0x00, 0x41, 0x22, 0x1c, 0x00, // )
    0x00, 0x14, 0x08, 0x3E, 0x08, 0x14, // *
    0x00, 0x08, 0x08, 0x3E, 0x08, 0x08, // +
    0x00, 0x00, 0x00, 0xA0, 0x60, 0x00, // ,
    0x00, 0x08, 0x08, 0x08, 0x08, 0x08, // -
    0x00, 0x00, 0x60, 0x60, 0x00, 0x00, // .
    0x00, 0x20, 0x10, 0x08, 0x04, 0x02, // /
    0x00, 0x3E, 0x51, 0x49, 0x45, 0x3E, // 0
    0x00, 0x00, 0x42, 0x7F, 0x40, 0x00, // 1
    0x00, 0x42, 0x61, 0x51, 0x49, 0x46, // 2
    0x00, 0x21, 0x41, 0x45, 0x4B, 0x31, // 3
    0x00, 0x18, 0x14, 0x12, 0x7F, 0x10, // 4
    0x00, 0x27, 0x45, 0x45, 0x45, 0x39, // 5
    0x00, 0x3C, 0x4A, 0x49, 0x49, 0x30, // 6
    0x00, 0x01, 0x71, 0x09, 0x05, 0x03, // 7
    0x00, 0x36, 0x49, 0x49, 0x49, 0x36, // 8
    0x00, 0x06, 0x49, 0x49, 0x29, 0x1E, // 9
    0x00, 0x00, 0x36, 0x36, 0x00, 0x00, // :
    0x00, 0x00, 0x56, 0x36, 0x00, 0x00, // ;
    0x00, 0x08, 0x14, 0x22, 0x41, 0x00, // <
    0x00, 0x14, 0x14, 0x14, 0x14, 0x14, // =
    0x00, 0x00, 0x41, 0x22, 0x14, 0x08, // >
    0x00, 0x02, 0x01, 0x51, 0x09, 0x06, // ?
    0x00, 0x32, 0x49, 0x59, 0x51, 0x3E, // @
    0x00, 0x7C, 0x12, 0x11, 0x12, 0x7C, // A
    0x00, 0x7F, 0x49, 0x49, 0x49, 0x36, // B
    0x00, 0x3E, 0x41, 0x41, 0x41, 0x22, // C
    0x00, 0x7F, 0x41, 0x41, 0x22, 0x1C, // D
    0x00, 0x7F, 0x49, 0x49, 0x49, 0x41, // E
    0x00, 0x7F, 0x09, 0x09, 0x09, 0x01, // F
    0x00, 0x3E, 0x41, 0x49, 0x49, 0x7A, // G
    0x00, 0x7F, 0x08, 0x08, 0x08, 0x7F, // H
    0x00, 0x00, 0x41, 0x7F, 0x41, 0x00, // I
    0x00, 0x20, 0x40, 0x41, 0x3F, 0x01, // J
    0x00, 0x7F, 0x08, 0x14, 0x22, 0x41, // K
    0x00, 0x7F, 0x40, 0x40, 0x40, 0x40, // L
    0x00, 0x7F, 0x02, 0x0C, 0x02, 0x7F, // M
    0x00, 0x7F, 0x04, 0x08, 0x10, 0x7F, // N
    0x00, 0x3E, 0x41, 0x41, 0x41, 0x3E, // O
    0x00, 0x7F, 0x09, 0x09, 0x09, 0x06, // P
    0x00, 0x3E, 0x41, 0x51, 0x21, 0x5E, // Q
    0x00, 0x7F, 0x09, 0x19, 0x29, 0x46, // R
    0x00, 0x46, 0x49, 0x49, 0x49, 0x31, // S
    0x00, 0x01, 0x01, 0x7F, 0x01, 0x01, // T
    0x00, 0x3F, 0x40, 0x40, 0x40, 0x3F, // U
    0x00, 0x1F, 0x20, 0x40, 0x20, 0x1F, // V
    0x00, 0x3F, 0x40, 0x38, 0x40, 0x3F, // W
    0x00, 0x63, 0x14, 0x08, 0x14, 0x63, // X
    0x00, 0x07, 0x08, 0x70, 0x08, 0x07, // Y
    0x00, 0x61, 0x51, 0x49, 0x45, 0x43, // Z
    0x00, 0x00, 0x7F, 0x41, 0x41, 0x00, // [
    0x00, 0x55, 0x2A, 0x55, 0x2A, 0x55, // backslash
    0x00, 0x00, 0x41, 0x41, 0x7F, 0x00, // ]
    0x00, 0x04, 0x02, 0x01, 0x02, 0x04, // ^
    0x00, 0x40, 0x40, 0x40, 0x40, 0x40, // _
    0x00, 0x00, 0x01, 0x02, 0x04, 0x00, // '
    0x00, 0x20, 0x54, 0x54, 0x54, 0x78, // a
    0x00, 0x7F, 0x48, 0x44, 0x44, 0x38, // b
    0x00, 0x38, 0x44, 0x44, 0x44, 0x20, // c
    0x00, 0x38, 0x44, 0x44, 0x48, 0x7F, // d
    0x00, 0x38, 0x54, 0x54, 0x54, 0x18, // e
    0x00, 0x08, 0x7E, 0x09, 0x01, 0x02, // f
    0x00, 0x18, 0xA4, 0xA4, 0xA4, 0x7C, // g
    0x00, 0x7F, 0x08, 0x04, 0x04, 0x78, // h
    0x00, 0x00, 0x44, 0x7D, 0x40, 0x00, // i
    0x00, 0x40, 0x80, 0x84, 0x7D, 0x00, // j
    0x00, 0x7F, 0x10, 0x28, 0x44, 0x00, // k
    0x00, 0x00, 0x41, 0x7F, 0x40, 0x00, // l
    0x00, 0x7C, 0x04, 0x18, 0x04, 0x78, // m
    0x00, 0x7C, 0x08, 0x04, 0x04, 0x78, // n
    0x00, 0x38, 0x44, 0x44, 0x44, 0x38, // o
    0x00, 0xFC, 0x24, 0x24, 0x24, 0x18, // p
    0x00, 0x18, 0x24, 0x24, 0x18, 0xFC, // q
    0x00, 0x7C, 0x08, 0x04, 0x04, 0x08, // r
    0x00, 0x48, 0x54, 0x54, 0x54, 0x20, // s
    0x00, 0x04, 0x3F, 0x44, 0x40, 0x20, // t
    0x00, 0x3C, 0x40, 0x40, 0x20, 0x7C, // u
    0x00, 0x1C, 0x20, 0x40, 0x20, 0x1C, // v
    0x00, 0x3C, 0x40, 0x30, 0x40, 0x3C, // w
    0x00, 0x44, 0x28, 0x10, 0x28, 0x44, // x
    0x00, 0x1C, 0xA0, 0xA0, 0xA0, 0x7C, // y
    0x00, 0x44, 0x64, 0x54, 0x4C, 0x44, // z
    0x00, 0x00, 0x08, 0x77, 0x41, 0x00, // {
    0x00, 0x00, 0x00, 0x63, 0x00, 0x00, // ¦
    0x00, 0x00, 0x41, 0x77, 0x08, 0x00, // }
    0x00, 0x08, 0x04, 0x08, 0x08, 0x04, // ~
    0x00, 0x3A, 0x40, 0x40, 0x20, 0x7A, // ü, !!! Important: this must be special_char[0] !!!
    0x00, 0x3D, 0x40, 0x40, 0x40, 0x3D, // Ü
    0x00, 0x21, 0x54, 0x54, 0x54, 0x79, // ä
    0x00, 0x7D, 0x12, 0x11, 0x12, 0x7D, // Ä
    0x00, 0x39, 0x44, 0x44, 0x44, 0x39, // ö
    0x00, 0x3D, 0x42, 0x42, 0x42, 0x3D, // Ö
    0x00, 0x02, 0x05, 0x02, 0x00, 0x00, // °
    0x00, 0x7E, 0x01, 0x49, 0x55, 0x73, // ß
    0x00, 0x7C, 0x10, 0x10, 0x08, 0x1C, // µ
    0x00, 0x30, 0x48, 0x20, 0x48, 0x30, // ω
    0x00, 0x5C, 0x62, 0x02, 0x62, 0x5C, // Ω
};
