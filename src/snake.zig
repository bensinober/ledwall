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
        const y: i32 = @intCast(i % height);
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
};

pub const Snake = struct {
    const Self = @This();

    newDirection: Direction,
    lastDirection: Direction,
    snakeLength: i32,
    playerX: i32,
    playerY: i32,
    cells: [numCells]Cell,
    food: i32, // always just one
    delay: u64, // inverted speed
    prng: std.Random.DefaultPrng,

    pub fn reset(self: *Self) !void {
        var cells: [numCells]Cell = undefined; // x, y, col
        const prng = std.Random.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        // prefill cells with x,y and zeroes
        for (0..numCells) |i| {
            const cell = Cell.indexToCell(i, 0);
            cells[i] = cell;
        }
        self.newDirection = .right;
        self.lastDirection = .right;
        self.snakeLength = 3;
        self.playerX = 1;
        self.playerY = 6;
        self.cells = cells;
        self.food = undefined;
        self.delay = 500 * 1000 * 1000;
        self.prng = prng;
    }

    pub fn step(self: *Self) void {
        self.move();
    }

    // placeFood in an empty cell, just try until one fits
    pub fn placeFood(self: *Self) void {
        while (true) {
            const r = self.prng.random().uintLessThan(usize, numCells - 1);
            if (self.cells[r].data == 0) {
                self.food = @intCast(r);
                return;
            }
        }
    }

    fn move(self: *Self) void {
        if (self.newDirection == self.lastDirection.opposite()) {
            return; // don't allow
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
            const p = self.cells[i];
            if (p.x == self.playerX) {
                if (p.y == self.playerY) {
                    // Snake head is on active cell
                    if (self.cells[i].data > 0) {
                        self.gameOver() catch |err| {
                            std.debug.print("Failed setting gameover {any}\n", .{err});
                        }; // Cell is occupied - crash
                    }
                    // set cell to length of snake
                    self.cells[i].data = self.snakeLength;

                    // food eaten?
                    if (i == self.food) {
                        self.snakeLength += 1;
                        self.placeFood();
                    }
                }
            }
            // decrease cell counter if occupied by a snake length
            if (p.data != 0) {
                self.cells[i].data -= 1;
            }
        }
        self.lastDirection = self.newDirection;
    }
    fn gameOver(self: *Self) !void {
        std.debug.print("GAME OVER\n", .{});
        // TODO: Print something?
        std.Thread.sleep(3 * 1000 * 1000 * 1000); // 3 secs
        try self.reset();
    }
};
