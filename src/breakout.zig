const std = @import("std");

pub const width = 24;
pub const height = 18;

pub const brick_rows = 4;
pub const brick_cols = 12; // 2 px wide bricks -> 24 px total
pub const brick_bottom_y = 13; // brick rows occupy y 13..16, y 17 is the top wall
pub const paddle_width = 5;
pub const paddle_speed = 2;
pub const paddle_y = 1;
pub const base_delay = 80; // ms per frame at level 1
pub const min_delay = 40;

pub const Dir = enum {
    none,
    left,
    right,
};

pub const Breakout = struct {
    const Self = @This();

    io: std.Io,
    dir: Dir,
    paddleX: i32, // left edge of paddle in mat coords (y=0 is bottom)
    ballX: i32,
    ballY: i32,
    ballVx: i32,
    ballVy: i32,
    launched: bool, // ball sits on the paddle until launched
    bricks: [brick_rows][brick_cols]bool,
    bricksLeft: usize,
    lives: i32,
    score: u32,
    level: u32,
    gameOver: bool,
    delay: u64, // frame time in ms (sleep between steps)

    pub fn reset(self: *Self) void {
        self.dir = .none;
        self.paddleX = (width - paddle_width) / 2;
        self.score = 0;
        self.lives = 3;
        self.level = 1;
        self.gameOver = false;
        self.delay = base_delay;
        self.resetBricks();
        self.resetBall();
    }

    pub fn resetBricks(self: *Self) void {
        for (self.bricks[0..]) |*row| {
            for (row[0..]) |*cell| {
                cell.* = true;
            }
        }
        self.bricksLeft = brick_rows * brick_cols;
    }

    fn resetBall(self: *Self) void {
        self.launched = false;
        self.ballVx = -1;
        self.ballVy = 1;
        self.stickBallToPaddle();
    }

    fn stickBallToPaddle(self: *Self) void {
        self.ballX = self.paddleX + paddle_width / 2;
        self.ballY = paddle_y + 1;
    }

    // launch the ball from the paddle in a random horizontal direction
    pub fn launch(self: *Self) void {
        if (self.gameOver or self.launched) return;
        var buf: [1]u8 = undefined;
        self.io.random(&buf);
        self.ballVx = if (buf[0] & 1 == 0) 1 else -1;
        self.ballVy = 1;
        self.launched = true;
    }

    // paddle slides in the last pressed direction (latched; stop releases it)
    fn movePaddle(self: *Self) void {
        if (self.dir == .left) {
            self.paddleX -= paddle_speed;
            if (self.paddleX < 0) self.paddleX = 0;
        } else if (self.dir == .right) {
            self.paddleX += paddle_speed;
            if (self.paddleX > width - paddle_width) self.paddleX = width - paddle_width;
        }
    }

    pub fn step(self: *Self) void {
        if (self.gameOver) return;
        self.movePaddle();

        if (!self.launched) {
            self.stickBallToPaddle();
            return;
        }

        var newx = self.ballX + self.ballVx;
        var newy = self.ballY + self.ballVy;

        // side walls
        if (newx < 0) {
            newx = -newx;
            self.ballVx = -self.ballVx;
        } else if (newx > width - 1) {
            newx = 2 * (width - 1) - newx;
            self.ballVx = -self.ballVx;
        }

        // top wall
        if (newy > height - 1) {
            newy = 2 * (height - 1) - newy;
            self.ballVy = -self.ballVy;
        }

        // bricks, bounce off whichever side we entered from
        if (newy >= brick_bottom_y and newy <= brick_bottom_y + brick_rows - 1) {
            const r: usize = @intCast(newy - brick_bottom_y);
            const c: usize = @intCast(@divTrunc(newx, 2));
            if (self.bricks[r][c]) {
                self.bricks[r][c] = false;
                self.bricksLeft -= 1;
                self.score += 1;
                self.ballVy = -self.ballVy;
                newy = newy + self.ballVy; // step back out of the brick
                if (self.bricksLeft == 0) {
                    self.levelUp();
                    return;
                }
            }
        }

        // paddle bounce, offset from center steers the ball
        if (self.ballVy < 0 and newy == paddle_y and newx >= self.paddleX and newx <= self.paddleX + paddle_width - 1) {
            const center = self.paddleX + paddle_width / 2;
            if (newx < center) self.ballVx = -1;
            if (newx > center) self.ballVx = 1;
            self.ballVy = 1;
            newy = paddle_y + 1;
        }

        // floor: ball fell below the paddle
        if (newy <= 0) {
            self.loseLife();
            return;
        }

        self.ballX = newx;
        self.ballY = newy;
    }

    fn loseLife(self: *Self) void {
        self.lives -= 1;
        std.debug.print("BALL LOST, lives left: {d}\n", .{self.lives});
        if (self.lives <= 0) {
            std.debug.print("GAME OVER\n", .{});
            self.gameOver = true;
            return;
        }
        self.resetBall();
    }

    // cleared the wall: bonus life, slightly faster, bricks refill, ball back on paddle
    fn levelUp(self: *Self) void {
        self.level += 1;
        if (self.lives < 9) self.lives += 1;
        if (self.delay > min_delay) self.delay -= 8;
        self.resetBricks();
        self.resetBall();
        std.debug.print("LEVEL UP! level: {d} lives: {d} delay: {d}ms\n", .{ self.level, self.lives, self.delay });
    }
};
