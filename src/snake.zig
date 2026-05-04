const std = @import("std");

pub const width = 24;
pub const height = 18;
const numCells = width * height;

const Cell = struct {
    x: i32,
    y: i32,
    data: i32,

    // get x/y coords in led grid, mirrors main.getLedNumberFromPoint
    pub fn indexToCell(i: usize, data: i32) Cell {
        const x: i32 = @intCast(i / height);
        var y: i32 = 0;
        if (@mod(x, 2) == 0) {
            y = @intCast(i % height);
        } else {
            y = @intCast(height - (i % height) - 1);
        }
        return Cell{
            .x = x,
            .y = y,
            .data = data,
        };
    }
};

pub const Direction = enum {
    left,
    up,
    right,
    down,

    pub fn opposite(self: Direction) Direction {
        return switch (self) {
            .left => .right,
            .up => .down,
            .right => .left,
            .down => .up,
        };
    }
    pub fn str2enum(str: []const u8) ?Direction {
        return std.meta.stringToEnum(Direction, str) orelse Direction.right;
    }
};

pub const Snake = struct {
    const Self = @This();

    io: std.Io,
    newDirection: Direction,
    lastDirection: Direction,
    snakeLength: i32,
    playerX: i32,
    playerY: i32,
    cells: [numCells]Cell,
    food: i32, // always just one
    delay: u64, // inverted speed
    randomMove: bool,
    gameOver: bool,

    pub fn reset(self: *Self) !void {
        var cells: [numCells]Cell = undefined; // x, y, col

        // prefill cells with x,y and zeroes
        for (0..numCells) |i| {
            const cell = Cell.indexToCell(i, 0);
            cells[i] = cell;
        }
        self.newDirection = .right;
        self.lastDirection = .right;
        self.snakeLength = 3;
        self.playerX = 1;
        self.playerY = 2;
        self.cells = cells;
        self.food = undefined;
        self.delay = 200 * 1000 * 1000;
        self.randomMove = false;
        self.gameOver = false;
        self.placeFood();
    }

    pub fn step(self: *Self) void {
        self.move();
        if (self.randomMove == true) {
            // want a random direction 0 - 1 - 2 - 3 for a random move 1/10th
            var buf: [1]u8 = undefined; // = 0-254 so we need to map to relevant size 0-10
            self.io.random(&buf);
            const rand1: u32 = buf[0];
            const r: u32 = @intCast((rand1 * 10) / 254); // map 0-254 to 0-10
            if (r == 5) {
                self.io.random(&buf);
                const rand2: u32 = buf[0];
                const r2: u32 = @intCast((rand2 * 4) / 254); // map 0-254 to 0-4
                self.newDirection = @enumFromInt(r2);
            }
        }
    }

    pub fn setRandomMove(self: *Self) void {
        self.randomMove = true;
    }

    // placeFood in an empty cell, just try until one fits
    pub fn placeFood(self: *Self) void {
        while (true) {
            var buf: [2]u8 = undefined;
            self.io.random(&buf);
            const rand: u32 = (@as(u16, buf[0]) << 8) | buf[1];
            const max = std.math.maxInt(u16); // 65535
            const r: usize = @intCast((rand * numCells - 1) / max); // map u16 (0-65535) to total cells (432)
            if (self.cells[r].data == 0) {
                std.debug.print("Placing food on {any}\n", .{r});
                self.food = @intCast(r);
                return;
            }
        }
    }

    fn move(self: *Self) void {
        if (self.newDirection == self.lastDirection.opposite()) {
            self.newDirection = self.lastDirection; // don't allow
        }
        if (self.newDirection == .left) {
            self.playerX -= 1;
        } else if (self.newDirection == .up) {
            self.playerY += 1;
        } else if (self.newDirection == .right) {
            self.playerX += 1;
        } else if (self.newDirection == .down) {
            self.playerY -= 1;
        }

        if (self.playerX == width) {
            self.playerX = 0;
        } else if (self.playerX == -1) {
            self.playerX = width - 1;
        }

        if (self.playerY == height) {
            self.playerY = 0;
        } else if (self.playerY == -1) {
            self.playerY = height - 1;
        }

        for (0..numCells) |i| {
            const c = self.cells[i];
            if (c.x == self.playerX) {
                if (c.y == self.playerY) {
                    // Snake head is on active cell
                    if (self.cells[i].data > 0) {
                        // Cell is occupied - crash
                        self.setGameOver() catch |err| {
                            std.debug.print("Failed setting gameover {any}\n", .{err});
                        };
                    }
                    // set cell to length of snake
                    self.cells[i].data = self.snakeLength;

                    // food eaten?
                    if (i == self.food) {
                        std.debug.print("Yummy!! {d}\n", .{i});
                        self.snakeLength += 1;
                        self.placeFood();
                    }
                }
            }
            // decrease cell counter if occupied by a snake length
            if (c.data != 0) {
                self.cells[i].data -= 1;
            }
        }
        self.lastDirection = self.newDirection;
    }
    fn setGameOver(self: *Self) !void {
        std.debug.print("GAME OVER\n", .{});
        self.gameOver = true;
        // TODO: Print something?
        //std.Thread.sleep(10 * 1000 * 1000 * 1000); // 10 secs
        //try self.reset();
    }
};
