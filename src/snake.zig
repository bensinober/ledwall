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
    direction: Direction,
    snakeLength: i32,
    playerX: i32,
    playerY: i32,
    cells: [numCells]Cell,
    food: Cell, // always just one
    delay: u64, // inverted speed
    prng: std.Random.DefaultPrng,

    pub fn init() !Self {
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
        return Self{
            .direction = .up,
            .snakeLength = 3,
            .playerX = 1,
            .playerY = 6,
            .cells = cells,
            .food = undefined,
            .delay = 500 * 1000 * 1000, // start at 500ms
            .prng = prng,
        };
    }
    pub fn deinit(_: *Self) void {}

    pub fn reset(self: *Self) void {
        self.snakeLength = 3;
    }

    pub fn step(self: *Self) void {
        self.move(Direction.right);
    }

    // placeFood in an empty cell, just try until one fits
    pub fn placeFood(self: *Self) void {
        while (true) {
            const r = self.prng.random().uintLessThan(usize, numCells - 1);
            //.intRangeAtMost(u8, 0, 255);
            if (self.cells[r].data == 0) {
                const cell = Cell.indexToCell(r, 1);
                self.food = cell; // actually not neccessary ?
                return;
            }
        }
    }

    fn move(self: *Self, direction: Direction) void {
        if (direction == self.direction.opposite()) {
            return; // don't allow
        }
        if (direction == .left) {
            self.playerX -= 1;
        } else if (direction == .up) {
            self.playerY += 1;
        } else if (direction == .right) {
            self.playerX += 1;
        } else if (direction == .down) {
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
                    self.cells[i].data = self.snakeLength;
                }
            }
            // decrease cell counter if occupied by a snake length
            if (p.data != 0) {
                self.cells[i].data -= 1;
            }
        }
    }
};
