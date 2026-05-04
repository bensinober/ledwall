const std = @import("std");
const mem = std.mem;
const fs = std.fs;
const posix = std.posix;

// for http server
const net = std.net;
const http = std.http;
const index_html = @embedFile("www/index.html");
const index_adm_html = @embedFile("www/index-adm.html");
const game_control_html = @embedFile("www/game-control.html");
const snake_html = @embedFile("www/snake.html");
const script_js = @embedFile("www/script.js");

// the rest
const gpiod = @import("gpiod.zig");
const ws2811 = @import("ws2811.zig");
//const ws281x = @import("ws281x.zig");

const img = @import("img.zig"); // TODO: use API to upload/convert images instead
const eightbitFont = @import("eightbit_atari_stop2_font.zig");

const snake = @import("snake.zig");

// GLOBALS
var snakeGame: snake.Snake = snake.Snake{
    .io = undefined,
    .newDirection = .right,
    .lastDirection = .right,
    .snakeLength = 3,
    .playerX = 1,
    .playerY = 6,
    .cells = undefined,
    .food = undefined,
    .delay = 500 * 1000 * 1000,
    .randomMove = false,
    .gameOver = false,
};

// BLUEZ C WRAPPER
// C wrapper function to start server
extern "c" fn start_gatt_server() void;

// C calls this Zig function when characteristic is written
export fn zig_write_handler(data: [*]const u8, length: usize) void {
    std.debug.print("Zig received {d} bytes from GATT write: ", .{length});
    for (data[0..length]) |b| {
        std.debug.print("{x} ", .{b});
        if (b == 0x61) { // a (left)
            snakeGame.newDirection = snake.Direction.left;
        } else if (b == 0x73) { // w (up)
            snakeGame.newDirection = snake.Direction.up;
        } else if (b == 0x64) { // d (right)
            snakeGame.newDirection = snake.Direction.right;
        } else if (b == 0x77) { // s (down)
            snakeGame.newDirection = snake.Direction.down;
        }
    }
    std.debug.print("\n", .{});
}
// END BLUES C WRAPPER

pub const LEDMode = enum(u8) {
    IDLE,
    ANIMATION,
    SNAKE,
    _,

    pub fn enum2str(self: LEDMode) []u8 {
        return std.meta.fields(?LEDMode)[self];
    }
    pub fn str2enum(str: []const u8) ?LEDMode {
        return std.meta.stringToEnum(LEDMode, str) orelse LEDMode.IDLE;
    }
};
// initial mode
var ledMode = LEDMode.ANIMATION;
var lastLedMode = LEDMode.ANIMATION;

// *** GLOBALS ***

const Allocator = mem.Allocator;
const ArrayList = std.ArrayList;
const time = std.time;

const LEDSTRIP_PIN_A = 18; // GPIO18 (12)
const LEDSTRIP_COLS = 24;
const LEDSTRIP_ROWS = 18;
const LEDSTRIP_LENGTH = LEDSTRIP_COLS * LEDSTRIP_ROWS;

const JsonTextScroll = struct {
    text: []u8,
    x: i32,
    y: i32,
    col: u32,
};

const JsonImage = struct {
    body: u64,
    frameDelay: u64,
};

const JsonText = struct {
    text: []u8,
    frameDelay: u64,
};

pub const Server = struct {
    allocator: Allocator,
    io: std.Io,
    listener: std.Io.net.Server,
    ledController: *LedControl,
    // Add other fields as needed, e.g., for routing, database connections, etc.

    pub fn init(allocator: std.mem.Allocator, io: std.Io, port: u16, ledController: *LedControl) !Server {
        const address = try std.Io.net.IpAddress.parse("0.0.0.0", port);
        const listener = try address.listen(io, .{ .reuse_address = true });
        std.debug.print("Listening on {d}\n", .{port});

        return Server{
            .allocator = allocator,
            .io = io,
            .listener = listener,
            .ledController = ledController,
        };
    }

    pub fn deinit(self: *Server) void {
        self.listener.deinit(self.io);
    }

    pub fn serve(self: *Server) !void {
        while (true) {
            try self.handleConnection(try self.listener.accept(self.io));
        }
    }

    // Request handler function (example)
    pub fn handleConnection(self: *Server, conn: std.Io.net.Stream) !void {
        //defer conn.stream.close();
        var recvBuf: [4096]u8 = undefined;
        var sendBuf: [4096]u8 = undefined;
        var reader = conn.reader(self.io, &recvBuf);
        var writer = conn.writer(self.io, &sendBuf);
        var httpServer = std.http.Server.init(&reader.interface, &writer.interface);
        var req = try httpServer.receiveHead();
        std.debug.print("Received request: {any}\n", .{req});

        // TODO: remove
        var it = req.iterateHeaders();
        while (it.next()) |header| {
            std.debug.print("HEADER: {s} - VAL: {s}\n", .{ header.name, header.value });
        }
        // https://github.com/ziglang/zig/issues/25017
        // if body content_length is not null
        req.head.keep_alive = false;

        // assert(request.head.transfer_encoding != .none or request.head.content_length != null);
        if (req.head.method == .GET and std.mem.eql(u8, req.head.target, "/")) {
            //var response_headers = std.http.Header{};
            //response_headers.content_type = "text/html";
            const indexLen = try std.fmt.allocPrint(self.allocator, "{d}", .{index_html.len});
            try req.respond(index_html, .{
                .status = .ok,
                .extra_headers = &.{
                    http.Header{ .name = "Content-Type", .value = "text/html" },
                    http.Header{ .name = "Content-Length", .value = indexLen },
                },
            });
        } else if (std.mem.eql(u8, req.head.target, "/adm")) {
            const scriptLen = try std.fmt.allocPrint(self.allocator, "{d}", .{script_js.len});
            try req.respond(index_adm_html, .{
                .status = .ok,
                .extra_headers = &.{
                    http.Header{ .name = "Content-Type", .value = "text/javascript" },
                    http.Header{ .name = "Content-Length", .value = scriptLen },
                },
            });
        } else if (std.mem.eql(u8, req.head.target, "/game-control")) {
            const gameControlLen = try std.fmt.allocPrint(self.allocator, "{d}", .{game_control_html.len});
            try req.respond(game_control_html, .{
                .status = .ok,
                .extra_headers = &.{
                    http.Header{ .name = "Content-Type", .value = "text/html" },
                    http.Header{ .name = "Content-Length", .value = gameControlLen },
                },
            });
        } else if (std.mem.eql(u8, req.head.target, "/snake")) {
            const snakeLen = try std.fmt.allocPrint(self.allocator, "{d}", .{snake_html.len});
            try req.respond(snake_html, .{
                .status = .ok,
                .extra_headers = &.{
                    http.Header{ .name = "Content-Type", .value = "text/html" },
                    http.Header{ .name = "Content-Length", .value = snakeLen },
                },
            });
        } else if (std.mem.eql(u8, req.head.target, "/script.js")) {
            const scriptLen = try std.fmt.allocPrint(self.allocator, "{d}", .{script_js.len});
            try req.respond(script_js, .{
                .status = .ok,
                .extra_headers = &.{
                    http.Header{ .name = "Content-Type", .value = "text/javascript" },
                    http.Header{ .name = "Content-Length", .value = scriptLen },
                },
            });
            // LED CONTROL

        } else if (req.head.method == .PUT and std.mem.eql(u8, req.head.target, "/cycle")) {
            try self.ledController.cycleColours();
            try req.respond("CYCLE", .{ .status = .ok, .transfer_encoding = .chunked });
        } else if (req.head.method == .PUT and std.mem.eql(u8, req.head.target, "/rows")) {
            try self.ledController.rows(255);
            try req.respond("ROWS", .{ .status = .ok, .transfer_encoding = .chunked });
        } else if (req.head.method == .PUT and std.mem.eql(u8, req.head.target, "/cols")) {
            try self.ledController.cols(255);
            try req.respond("COLS", .{ .status = .ok, .transfer_encoding = .chunked });
        } else if (req.head.method == .POST and std.mem.eql(u8, req.head.target, "/frameDelay")) {
            var len: usize = 0;
            if (req.head.content_length) |contLen| {
                len = @intCast(contLen);
            }
            const body = try reader.interface.take(len);
            const frameDelay: u64 = try std.fmt.parseInt(u64, body, 10); // 10 specifies base 10 (decimal)
            try self.ledController.setFrameDelay(frameDelay);
            std.debug.print("Frame delay set: {d}\n", .{frameDelay});
            try req.respond("OK", .{ .status = .ok, .transfer_encoding = .chunked });
        } else if (req.head.method == .POST and std.mem.eql(u8, req.head.target, "/setText")) {
            var len: usize = 0;
            if (req.head.content_length) |contLen| {
                len = @intCast(contLen);
            }
            const body = try reader.interface.take(len);
            const jsonBody = std.json.parseFromSlice(JsonText, self.allocator, body, .{}) catch |err| {
                std.debug.print("ERROR parsing json body: {any}\n", .{err});
                try req.respond(@errorName(err), .{ .status = .internal_server_error });
                return;
            };
            defer jsonBody.deinit();
            try self.ledController.setText(jsonBody.value.text, jsonBody.value.frameDelay, 0, 0xff0000, 9, 5);
            std.debug.print("Set new text: {s}\n", .{body});
            try req.respond("OK", .{ .status = .ok, .transfer_encoding = .chunked });
        } else if (req.head.method == .POST and std.mem.eql(u8, req.head.target, "/textScroll")) {
            var len: usize = 0;
            if (req.head.content_length) |contLen| {
                len = @intCast(contLen);
            }
            const body = try reader.interface.take(len);
            const jsonBody = std.json.parseFromSlice(JsonTextScroll, self.allocator, body, .{}) catch |err| {
                std.debug.print("ERROR parsing json body: {any}\n", .{err});
                try req.respond(@errorName(err), .{ .status = .internal_server_error });
                return;
            };
            defer jsonBody.deinit();

            //std.debug.print("UPLOAD body: {any}\n", .{body});
            const charPixels = try self.ledController.renderTextAtPos(jsonBody.value.text, jsonBody.value.x, jsonBody.value.y);
            try self.ledController.runTextScroll(jsonBody.value.text);
            //std.debug.print("PIXELS: {any}\n", .{charPixels});
            var out = std.Io.Writer.Allocating.init(self.allocator);
            const jsonWriter = &out.writer;
            defer out.deinit();
            try std.json.Stringify.value(charPixels, .{}, jsonWriter);
            const jsonRes = out.written();

            try req.respond(jsonRes, .{
                .status = .ok,
                .extra_headers = &.{
                    http.Header{ .name = "Content-Type", .value = "application/json" },
                },
            });
        } else if (req.head.method == .PUT and std.mem.eql(u8, req.head.target, "/toggleActive")) {
            try self.ledController.toggleActive();
            const response = std.fmt.allocPrint(self.allocator, "NEW STATE: {any}\n", .{self.ledController.activeMatrix}) catch @panic("Failed to format status line");
            try req.respond(response, .{ .status = .ok, .transfer_encoding = .chunked });
            // TODO: disable this? start whenever app is started
        } else if (req.head.method == .PUT and std.mem.eql(u8, req.head.target, "/start")) {
            // TODO: no need to spawn thread when no animation running
            const thread = try std.Thread.spawn(.{}, LedControl.runMatrix, .{self.ledController});
            thread.detach();
            const response = std.fmt.allocPrint(self.allocator, "matrix started in thread: {any}\n", .{thread}) catch @panic("Failed to set matrix");
            try req.respond(response, .{});

            // Raw image data upload, can set LedControl Matrix directly
        } else if (req.head.method == .POST and std.mem.eql(u8, req.head.target, "/uploadRawImg")) {
            var len: usize = 0;
            if (req.head.content_length) |contLen| {
                len = @intCast(contLen);
            }
            //std.debug.print("READER: seek {any} en {any}\n", .{reader.file_reader.interface.seek, reader.file_reader.interface.end});
            // TODO: accept json body + frameDelay
            const body = try reader.interface.take(len);
            std.debug.print("UPLOAD len: {d} - body: {any}\n", .{ len, reader });
            const num: usize = self.ledController.addImg(body, self.ledController.frameDelay) catch |err| {
                std.debug.print("Error uploading image: {}\n", .{err});
                try req.respond("Error uploading image!", .{ .status = .internal_server_error });
                return err;
            };
            const response = try std.fmt.allocPrint(self.allocator, "{d}\n", .{num});
            try req.respond(response, .{});
        } else if (req.head.method == .PUT and std.mem.eql(u8, req.head.target, "/clearMat")) {
            std.debug.print("CLEAR Mat!\n", .{});
            try self.ledController.clearMat();
            try self.ledController.addInitialImg();
            try req.respond("0", .{});
        } else if (req.head.method == .GET and std.mem.startsWith(u8, req.head.target, "/setMode")) {
            var paths = std.mem.splitScalar(u8, req.head.target, '/');
            var i: usize = 0;
            while (paths.next()) |p| {
                if (i == 2) {
                    const mode = LEDMode.str2enum(p);
                    std.debug.print("NEW LedMode {any}!\n", .{mode});
                    ledMode = mode.?;
                }
                i += 1;
            }
            try req.respond("OK", .{ .status = .ok, .transfer_encoding = .chunked });
        } else if (req.head.method == .GET and std.mem.startsWith(u8, req.head.target, "/setDirection")) {
            var paths = std.mem.splitScalar(u8, req.head.target, '/');
            var i: usize = 0;
            while (paths.next()) |p| {
                if (i == 2) {
                    const dir = snake.Direction.str2enum(p);
                    std.debug.print("NEW Direction {any}!\n", .{dir});
                    snakeGame.newDirection = dir.?;
                }
                i += 1;
            }
            try req.respond("OK", .{ .status = .ok, .transfer_encoding = .chunked });
        } else if (req.head.method == .GET and std.mem.eql(u8, req.head.target, "/getMode")) {
            try req.respond(@tagName(ledMode), .{ .status = .ok, .transfer_encoding = .chunked });
        } else if (req.head.method == .PUT and std.mem.eql(u8, req.head.target, "/setRandomSnake")) {
            std.debug.print("RANDOM SNAKE MOVES!\n", .{});
            try self.ledController.clearMat();
            snakeGame.randomMove = true;
        } else {
            try req.respond("Not Found", .{ .status = .not_found });
        }
        conn.close(self.io);
    }

    fn sendFile(writer: std.io.Writer, filename: []const u8) !void {
        const file = try std.fs.cwd().openFile(filename, .{});
        defer file.close();

        var buffer: [2096]u8 = undefined;
        while (true) {
            const read_bytes = try file.read(buffer[0..]);
            if (read_bytes.len == 0) break;
            try writer.writeAll(read_bytes);
        }
    }
};

const Pixel = struct {
    x: i32,
    y: i32,
    col: u32,
};

const CharPixel = struct {
    char: u8,
    pixels: ArrayList(Pixel),
};

const ImageMat = struct {
    mat: [LEDSTRIP_ROWS][LEDSTRIP_COLS][4]u8,
    frameDelay: u64, //ms length of slide
};

pub const LedControl = struct {
    const Self = @This();

    ptr: *ws2811.ws2811_t,
    io: std.Io,
    activeMatrix: bool,
    images: ArrayList(ImageMat), // TODO: rename to frames?
    mat: [LEDSTRIP_ROWS][LEDSTRIP_COLS][4]u8, // use as overlay
    activeTextScroll: bool,
    text: []u8,
    allocator: Allocator,
    mutex: std.Io.Mutex,
    frameDelay: u64,

    pub fn init(allocator: Allocator, io: std.Io, ledstrip: *ws2811.ws2811_t) !Self {
        const images: ArrayList(ImageMat) = .empty;
        const mat = createEmptyMat(0);
        return Self{
            .ptr = ledstrip,
            .io = io,
            .activeMatrix = true, // default start
            .images = images,
            .mat = mat,
            .activeTextScroll = false,
            .text = undefined,
            .allocator = allocator,
            .mutex = std.Io.Mutex.init,
            .frameDelay = 200,
        };
    }
    pub fn deinit(self: *Self) void {
        if (@import("builtin").target.cpu.arch != std.Target.Cpu.Arch.x86_64) {
            defer ws2811.ws2811_fini(self.ptr);
        }
    }

    pub fn addInitialImg(self: *Self) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        const mat = try imgbytes2matrix(&img.DATA);
        const imageMat: ImageMat = .{ .mat = mat, .frameDelay = 3000 };
        try self.images.append(self.allocator, imageMat);
    }

    pub fn addImg(self: *Self, imageBytes: []u8, frameDelay: u64) !usize {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        const mat = imgbytes2matrix(imageBytes) catch |err| {
            std.debug.print("Error adding image: {}\n", .{err});
            return err;
        };
        // TODO: use per frame frameDelay sent from API instead of global?
        const imageMat: ImageMat = .{ .mat = mat, .frameDelay = frameDelay };
        try self.images.append(self.allocator, imageMat);
        std.debug.print("mat: {any} images number in mat: {d}\n", .{ mat, self.images.items.len });
        return self.images.items.len;
    }

    pub fn clearMat(self: *Self) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        self.images = .empty;
        std.debug.print("images in mat: {d}\n", .{self.images.items.len});
    }

    // NB : y-axis is mirrored, as we start from top (x,y[0,0] is top left)
    pub fn getLedNumberFromPointYInverse(x: usize, y: usize) usize {
        const step = LEDSTRIP_ROWS; // y = 18
        var led: usize = undefined;
        if (x % 2 == 0) { // up from bottom
            const bottom = step * x;
            led = bottom + (step - y) - 1;
        } else { // down from top
            const top = step * x;
            led = top + y;
        }
        //std.debug.print("pixel: {d}, {d}, led nr: {d}\n", .{ x, y, led });
        return led;
    }
    // (x,y[0,0] is bottom left)
    pub fn getLedNumberFromPoint(x: usize, y: usize) usize {
        const step = LEDSTRIP_ROWS; // y = 18
        var led: usize = undefined;
        if (x % 2 == 0) { // up from bottom
            const bottom = step * x;
            led = bottom + y;
        } else { // down from top
            const top = step * x;
            led = top + (step - y) - 1;
        }
        //std.debug.print("pixel: {d}, {d}, led nr: {d}\n", .{ x, y, led });
        return led;
    }

    // convert pixel to u32 and insert in led channel
    // pixel is rgba, strip is grb big endian (ws2811 lib does not handle conversion to grb)
    // order is big endian gbra!
    pub fn setPixel(self: *Self, chan: usize, ledIdx: usize, colour: [4]u8) void {
        // Big endian, swap red and green
        const value: u32 = (@as(u32, colour[3]) << 24) | (@as(u32, colour[0]) << 16) | (@as(u32, colour[2]) << 8) | @as(u32, colour[1]);
        //const value: u32 = std.mem.readPackedInt(u32, colour[0..4], 0, .big);
        //std.debug.print("colour: {x}, bigend: 0x{x:0>8}, 0x{x:0>8}\n", .{ colour, val1, val2 });
        if (@import("builtin").target.cpu.arch != std.Target.Cpu.Arch.x86_64) {
            self.ptr.*.channel[chan].leds[ledIdx] = value;
        }
    }

    // Render single self.mat
    pub fn renderMat(self: *Self) void {
        if (self.mutex.tryLock()) {
            defer self.mutex.unlock(self.io);
            for (0..LEDSTRIP_ROWS) |y| {
                for (0..LEDSTRIP_COLS) |x| {
                    const ledIdx = getLedNumberFromPointYInverse(x, y);
                    self.setPixel(0, ledIdx, self.mat[y][x]);
                }
            }
            if (@import("builtin").target.cpu.arch != std.Target.Cpu.Arch.x86_64) {
                _ = ws2811.ws2811_render(self.ptr); // show row
            } else {
                std.debug.print("Single mat frameDelay: {d}\n", .{self.frameDelay});
            }
        } else {
            std.debug.print("could not lock, skipping single mat render\n", .{});
        }
    }
    // render images to led wall
    // source image is 24x18 24bit, reads from top left
    pub fn renderImages(self: *Self) !void {
        if (self.mutex.tryLock()) {
            defer self.mutex.unlock(self.io);
            std.debug.print("ITEMs: {d}\n", .{self.images.items.len});
            for (self.images.items) |item| { // cannot use direct access of elements as Arraylist pointers can be invalidated when reallocated
                for (0..LEDSTRIP_ROWS) |y| {
                    for (0..LEDSTRIP_COLS) |x| {
                        const ledIdx = getLedNumberFromPointYInverse(x, y);
                        self.setPixel(0, ledIdx, item.mat[y][x]);
                    }
                }
                if (@import("builtin").target.cpu.arch != std.Target.Cpu.Arch.x86_64) {
                    _ = ws2811.ws2811_render(self.ptr); // show row
                } else {
                    std.debug.print("ITEM frameDelay: {d}\n", .{item.frameDelay});
                }
                if (item.frameDelay < 5000) {
                    try self.io.sleep(std.Io.Duration.fromMilliseconds(@as(i64, @intCast(item.frameDelay))), .real);
                } else {
                    std.debug.print("FISHY: frameDelay: {d}, {any}\n", .{ item.frameDelay, item.mat });
                }
            }
        } else {
            std.debug.print("could not lock, skipping render\n", .{});
        }
    }

    pub fn renderSnake(self: *Self) !void {
        if (snakeGame.gameOver) {
            try self.cols(0x0000ff00);
            try self.setText(@constCast("GAME OVER"), 300, 0, 0x00ff0000, 9, 5);
            try self.io.sleep(std.Io.Duration.fromMilliseconds(1000), .real);
            try self.setText(@constCast("SCORE"), 300, 0, 0x00ff0000, 9, 5);
            try self.io.sleep(std.Io.Duration.fromMilliseconds(1000), .real);

            var scoreBuf: [4]u8 = undefined;
            const scoreTxt = try std.fmt.bufPrint(&scoreBuf, "{d}", .{snakeGame.snakeLength});
            try self.setText(scoreTxt, 3000, 0, 0x00ff0000, 9, 5);
            try self.renderImages();
            try self.clearMat();
            try snakeGame.reset();
        }
        snakeGame.step();
        var mat = createEmptyMat(0);
        const playerX: usize = @intCast(snakeGame.playerX);
        const playerY: usize = @intCast(snakeGame.playerY);
        for (snakeGame.cells) |cell| {
            const x: usize = @intCast(cell.x);
            const y: usize = @intCast(cell.y);
            const cellIdx: usize = getLedNumberFromPoint(x, y); // TOOD: make food an x,y cell?
            if (x == playerX and y == playerY) {
                std.debug.print("PLAYER is here: x: {d} - y: {d}, idx: {d}\n", .{ x, y, cellIdx });
                mat[y][x] = u32ToU8Bytes(0x0000ff00);
            } else if (cellIdx == snakeGame.food) {
                std.debug.print("FOOD is here: x: {d} - y: {d}, idx: {d}\n", .{ x, y, cellIdx });
                mat[y][x] = u32ToU8Bytes(0xff000000);
            } else if (cell.data > 0) {
                //std.debug.print("SNAKE is here: x: {d} - y: {d}, idx: {d}\n", .{ x, y, cellIdx });
                mat[y][x] = u32ToU8Bytes(0x00ff0000);
            }
        }
        self.mat = mat;
        self.renderMat();
        if (@import("builtin").target.cpu.arch != std.Target.Cpu.Arch.x86_64) {
            _ = ws2811.ws2811_render(self.ptr);
        } else {
            //std.debug.print("SNAKE MAT: {any}\n", .{self.mat});
        }
        std.debug.print("SNAKE STATE: playerX: {d} playerY: {d}, lastDirection: {any}, length: {d}\n", .{ snakeGame.playerX, snakeGame.playerY, snakeGame.lastDirection, snakeGame.snakeLength });
    }

    pub fn renderTextAtPos(self: *Self, chars: []u8, x: i32, y: i32) !ArrayList(CharPixel) {
        var charPixels: ArrayList(CharPixel) = .empty;
        const width = 8;
        var startX = x;
        for (chars) |char| {
            const charBytes = eightbitFont.getCharBytes(char);
            var pixels: ArrayList(Pixel) = .empty;
            var i: i32 = 0;
            while (i < eightbitFont.FONT_SIZE_W) : (i += 1) {
                const pos: usize = @intCast(i);
                const byte = charBytes[pos];
                var j: i32 = 0;
                while (j < eightbitFont.FONT_SIZE_H) : (j += 1) { // bits to shift, leftshift from left
                    const shift: u3 = @intCast(eightbitFont.FONT_SIZE_H - j - 1);
                    const mask: u8 = (@as(u8, 1) << shift);
                    const isSet = (byte & mask) != 0;
                    var col: u32 = 0xffffff;
                    if (isSet) {
                        col = 0x00ff00;
                    }
                    try pixels.append(self.allocator, Pixel{ .x = i + startX, .y = j + y, .col = col });
                }
            }
            try charPixels.append(self.allocator, CharPixel{ .char = char, .pixels = pixels });
            startX += width;
        }
        return charPixels;
    }

    pub fn u32ToU8Bytes(value: u32) [4]u8 {
        var buf: [4]u8 = undefined;
        std.mem.writeInt(u32, &buf, value, .big);
        return buf;
    }

    pub fn setText(self: *Self, chars: []u8, frameDelay: u64, bg: u32, fg: u32, startX: i32, startY: i32) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        for (chars) |char| {
            const charBytes = eightbitFont.getCharBytes(char);
            var i: i32 = 0;
            var mat = createEmptyMat(bg);
            while (i < eightbitFont.FONT_SIZE_W) : (i += 1) {
                const pos: usize = @intCast(i);
                const byte = charBytes[pos];
                var j: i32 = 0;
                while (j < eightbitFont.FONT_SIZE_H) : (j += 1) { // bits to shift, leftshift from left
                    const shift: u3 = @intCast(j);
                    const mask: u8 = (@as(u8, 1) << shift);
                    const isSet = (byte & mask) != 0;
                    var col: u32 = bg;
                    if (isSet) {
                        col = fg;
                    }
                    const x: usize = @intCast(i + startX);
                    const y: usize = @intCast(j + startY);
                    mat[y][x] = u32ToU8Bytes(col);
                }
            }
            const imageMat: ImageMat = .{ .mat = mat, .frameDelay = frameDelay };
            try self.images.append(self.allocator, imageMat);
        }
    }

    pub fn runTextScroll(self: *Self, chars: []u8) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        if (self.activeMatrix == true) {
            self.activeMatrix = false;
        }
        self.activeTextScroll = true;
        while (self.activeTextScroll == true) {
            var startX: i32 = LEDSTRIP_COLS - 1; // right end
            const charPixels = try self.renderTextAtPos(chars, startX, 4);
            // clear textMat, apply text on empty mat
            var mat = createEmptyMat(0);
            for (charPixels.items) |charPixel| {
                for (charPixel.pixels.items) |pixel| {
                    if (pixel.x >= 0 and pixel.x < LEDSTRIP_COLS) {
                        if (pixel.y >= 0 and pixel.y < LEDSTRIP_ROWS) {
                            const x: usize = @intCast(pixel.x);
                            const y: usize = @intCast(pixel.y);
                            mat[y][x] = u32ToU8Bytes(pixel.col);
                        }
                    }
                }
            }
            self.mat = mat;
            try self.io.sleep(std.Io.Duration.fromMilliseconds(100), .real);
            startX -= 1;
        }
    }

    // set colour on ALL leds
    pub fn setColour(self: *Self, col: u32) void {
        if (@import("builtin").target.cpu.arch != std.Target.Cpu.Arch.x86_64) {
            var i: usize = 0;
            while (i < LEDSTRIP_LENGTH) : (i += 1) {
                const channel = self.ptr.*.channel[0];
                channel.leds[i] = col;
            }
        }
    }

    pub fn rows(self: *Self, col: u32) !void {
        if (@import("builtin").target.cpu.arch != std.Target.Cpu.Arch.x86_64) {
            for (0..LEDSTRIP_ROWS) |y| {
                for (0..LEDSTRIP_COLS) |x| {
                    const ledIdx = getLedNumberFromPoint(x, y);
                    self.ptr.*.channel[0].leds[ledIdx] = col;
                }
                _ = ws2811.ws2811_render(self.ptr); // show row
                try self.io.sleep(std.Io.Duration.fromMilliseconds(10), .real);
            }
            self.setColour(0);
            _ = ws2811.ws2811_render(self.ptr); // show row
        }
    }

    pub fn cols(self: *Self, col: u32) !void {
        if (@import("builtin").target.cpu.arch != std.Target.Cpu.Arch.x86_64) {
            for (0..LEDSTRIP_COLS) |x| {
                for (0..LEDSTRIP_ROWS) |y| {
                    const ledIdx = getLedNumberFromPoint(x, y);
                    self.ptr.*.channel[0].leds[ledIdx] = col;
                }
                _ = ws2811.ws2811_render(self.ptr); // show row
                try self.io.sleep(std.Io.Duration.fromMilliseconds(1), .real);
            }
            self.setColour(0);
            _ = ws2811.ws2811_render(self.ptr);

            // reverse
            for (0..LEDSTRIP_COLS) |x| {
                for (0..LEDSTRIP_ROWS) |y| {
                    const reverseX = LEDSTRIP_COLS - 1 - x;
                    const ledIdx = getLedNumberFromPoint(reverseX, y);
                    self.ptr.*.channel[0].leds[ledIdx] = col;
                }
                _ = ws2811.ws2811_render(self.ptr); // show row
                try self.io.sleep(std.Io.Duration.fromMilliseconds(1), .real);
            }
            self.setColour(0);
            _ = ws2811.ws2811_render(self.ptr);
        }
    }

    // Startup, blink blue, red, green
    pub fn cycleColours(self: *Self) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        var start: std.Io.Timestamp = undefined;
        start = std.Io.Clock.awake.now(self.io);

        self.setColour(0xff0000); // blue
        if (@import("builtin").target.cpu.arch != std.Target.Cpu.Arch.x86_64) {
            _ = ws2811.ws2811_render(self.ptr);
        }
        var elapsed = start.untilNow(self.io, .awake);
        var ns = elapsed.toNanoseconds();
        std.debug.print("ns spent on green cycle: {}\n", .{ns});

        try self.io.sleep(std.Io.Duration.fromMilliseconds(500), .real);

        start = std.Io.Clock.awake.now(self.io);
        self.setColour(0xed1c24); // red
        if (@import("builtin").target.cpu.arch != std.Target.Cpu.Arch.x86_64) {
            _ = ws2811.ws2811_render(self.ptr);
        }
        elapsed = start.untilNow(self.io, .awake);
        ns = elapsed.toNanoseconds();
        std.debug.print("ns spent on red cycle: {}\n", .{ns});

        try self.io.sleep(std.Io.Duration.fromMilliseconds(1500), .real);

        start = std.Io.Clock.awake.now(self.io);
        self.setColour(0x0000ff); // green
        if (@import("builtin").target.cpu.arch != std.Target.Cpu.Arch.x86_64) {
            _ = ws2811.ws2811_render(self.ptr);
        }
        elapsed = start.untilNow(self.io, .awake);
        ns = elapsed.toNanoseconds();
        std.debug.print("ns spent on blue cycle: {}\n", .{ns});
        try self.io.sleep(std.Io.Duration.fromMilliseconds(500), .real);

        self.setColour(0x000000);
        if (@import("builtin").target.cpu.arch != std.Target.Cpu.Arch.x86_64) {
            _ = ws2811.ws2811_render(self.ptr);
        }
        try self.io.sleep(std.Io.Duration.fromMilliseconds(1000), .real);
    }

    pub fn toggleActive(self: *Self) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        self.activeMatrix = !self.activeMatrix;
    }

    // TODO: remove
    pub fn setFrameDelay(self: *Self, fd: u64) !void {
        try self.mutex.lock(self.io);
        defer self.mutex.unlock(self.io);
        self.frameDelay = fd;
    }

    // event loop running in thread, set activeMatrix first
    pub fn runMatrix(self: *Self) !void {
        while (true) {
            switch (ledMode) {
                .IDLE => {},
                .ANIMATION => {
                    try self.cols(0x00ff00);
                    const start = std.Io.Clock.awake.now(self.io);
                    try self.renderImages();
                    var elapsed = start.untilNow(self.io, .awake);
                    const ns = elapsed.toNanoseconds();
                    std.debug.print("ns spent on full render: {}\n", .{ns});
                    try self.io.sleep(std.Io.Duration.fromMilliseconds(1000), .real);
                },
                .SNAKE => {
                    const start = std.Io.Clock.awake.now(self.io);
                    try self.renderSnake();
                    var elapsed = start.untilNow(self.io, .awake);
                    const ns = elapsed.toNanoseconds();
                    std.debug.print("ns spent on snake render: {}\n", .{ns});
                    try self.io.sleep(std.Io.Duration.fromMilliseconds(@as(i64, @intCast(snakeGame.delay))), .real);
                },
                else => {
                    std.debug.print("UNKNOWN STATE", .{});
                },
            }
        }
    }

    pub fn createEmptyMat(colour: u32) [LEDSTRIP_ROWS][LEDSTRIP_COLS][4]u8 {
        var mat: [LEDSTRIP_ROWS][LEDSTRIP_COLS][4]u8 = undefined;
        for (0..LEDSTRIP_COLS) |col| {
            for (0..LEDSTRIP_ROWS) |row| {
                mat[row][col] = u32ToU8Bytes(colour);
            }
        }
        return mat;
    }
    // reads pixel data stream to mat of x,y coords (rows * cols)
    // transform png data [][4]u8 to led matrix pixel vector (mat[row][col]pixel) [rows][cols][4]u8 prepared for led strip length
    // NB : image data sent over wire starts top left, we need to set pixels in same order (getLedNumberFromPointYInverse)
    pub fn imgbytes2matrix(bytes: []const u8) ![LEDSTRIP_ROWS][LEDSTRIP_COLS][4]u8 {
        var reader = std.Io.Reader.fixed(bytes);
        var mat: [LEDSTRIP_ROWS][LEDSTRIP_COLS][4]u8 = undefined;
        var pixel: [4]u8 = undefined; // in bigendian MSB format
        for (0..LEDSTRIP_ROWS) |row| {
            for (0..LEDSTRIP_COLS) |col| {
                try reader.readSliceAll(pixel[0..]); // read to buffer is full
                mat[row][col] = pixel;
            }
        }
        return mat;
    }
};

// Get WIFI IP address by fake UDP connection to 1.1.1.1
pub fn getLocalAddress(io: std.Io, alloc: Allocator) ![]const u8 {
    const local = try std.Io.net.IpAddress.parse("0.0.0.0", 0);
    const remote = try std.Io.net.IpAddress.parse("1.1.1.1", 0);
    var socket = try local.bind(io, .{ .mode = .dgram, .protocol = .udp });
    defer socket.close(io);
    const conn = try remote.connect(io, .{ .mode = .dgram });
    const address = conn.socket.address;
    const out = try std.fmt.allocPrint(alloc, "{f}", .{address});
    return out;
}

pub fn onCharRead() void {
    return;
}
pub fn onCharWrite() void {
    return;
}
pub fn getChar() void {
    return;
}

pub fn main(init: std.process.Init) !void {
    // init IO
    const allocator = init.arena.allocator();
    const io = init.io;
    const args = try init.minimal.args.toSlice(allocator);

    for (args) |arg| {
        std.log.info("Argument: {s}", .{arg});
    }
    const arch = @import("builtin").target.cpu.arch;

    const addr = try getLocalAddress(io, allocator);
    std.debug.print("ledwall IP addr: {s}\n", .{addr});

    var ledstrip: ws2811.ws2811_t = undefined;
    // ws281x
    // const ledChip = gpiod.gpiod_chip_open_by_name("gpiochip4");
    // var ledCtrl = ws281x.WS281x.init(ledChip, LEDSTRIP_PINA);
    // defer ledCtrl.deinit();
    // ledCtrl.showColor(0xff, 0xff, 0xa0);
    // ledCtrl.sendReset();

    // ws2811 init
    if (arch != std.Target.Cpu.Arch.x86_64) {
        ledstrip = ws2811.ws2811_t{
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
                    .strip_type = ws2811.WS2811_STRIP_RGB,
                    .leds = undefined,
                    .brightness = 255,
                    .wshift = 0x00,
                    .rshift = 0x00,
                    .gshift = 0x00,
                    .bshift = 0x00,
                    .gamma = null,
                },
                ws2811.ws2811_channel_t{
                    .gpionum = undefined,
                    .invert = 0,
                    .count = 0,
                    .strip_type = ws2811.WS2811_STRIP_RGB,
                    .leds = undefined,
                    .brightness = 0,
                    .wshift = 0x00,
                    .rshift = 0x00,
                    .gshift = 0x00,
                    .bshift = 0x00,
                    .gamma = null,
                },
            },
        };
        _ = ws2811.ws2811_init(&ledstrip);
    }
    var ledController = try LedControl.init(allocator, io, &ledstrip);
    try ledController.addInitialImg();
    defer ledController.deinit();
    snakeGame.io = io;
    try snakeGame.reset();
    // spawn ledrunner in separate thread
    const ledThread = try std.Thread.spawn(.{}, LedControl.runMatrix, .{&ledController});
    ledThread.detach();

    const bleThread = std.Thread.spawn(.{}, start_gatt_server, .{}) catch |err| {
        std.debug.print("ERROR starting GATT server: {any}\n", .{err});
        return err;
    };
    bleThread.detach();

    var server = try Server.init(allocator, io, 8765, &ledController);
    defer server.deinit();
    try server.serve();
}
