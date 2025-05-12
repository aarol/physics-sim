const std = @import("std");

const sf = @import("sfml.zig");

pub const Ball = struct {
    curr_pos: sf.Vec2 = .{ .x = 0, .y = 0 },
    last_pos: sf.Vec2 = .{ .x = 0, .y = 0 },

    acceleration: sf.Vec2 = .{ .x = 0, .y = 100 },
    color: sf.sfColor,

    pub const radius: f32 = 2;

    pub fn new(curr_pos: sf.Vec2, last_pos: sf.Vec2, color: sf.sfColor) Ball {
        return .{
            .curr_pos = curr_pos,
            .last_pos = last_pos,
            .color = color,
        };
    }

    pub fn update(self: *Ball, dt: f32) void {
        const at2 = self.acceleration.mul_f32(dt * dt);
        const next_pos = self.curr_pos.mul_f32(2).sub(self.last_pos).add(at2);
        self.last_pos = self.curr_pos;
        self.curr_pos = next_pos;

        const v = CENTER.sub(self.curr_pos);
        const dist2 = v.length_squared();
        const constraint_radius_with_margin = (CONSTRAINT_RADIUS - Ball.radius);
        if (dist2 > constraint_radius_with_margin * constraint_radius_with_margin) {
            const n = v.normalized();
            self.curr_pos = CENTER.sub(n.mul_f32(constraint_radius_with_margin));
        }
    }
};

pub const WORLD_SIZE = sf.sfVector2u{ .x = 600, .y = 600 };
pub const CENTER = sf.Vec2{ .x = WORLD_SIZE.x / 2, .y = WORLD_SIZE.y / 2 };

pub const CELL_COUNT: u32 = WORLD_SIZE.x / CELL_SIZE;
pub const CELL_SIZE: u32 = 4 * Ball.radius;

pub const CONSTRAINT_RADIUS = 300;

const Cell = struct {
    ball_count: u32,
    balls: [10]u32,

    fn add_ball(self: *Cell, idx: u32) void {
        if (self.ball_count < 10) {
            self.balls[self.ball_count] = idx;
            self.ball_count += 1;
        }
    }
};

pub const Solver = struct {
    balls: std.ArrayList(Ball),
    subSteps: u32 = 8,
    grid: [CELL_COUNT * CELL_COUNT]Cell = undefined,
    threadpool: std.Thread.Pool,
    numThreads: usize,

    pub fn new(balls: std.ArrayList(Ball), alloc: std.mem.Allocator) !Solver {
        var threadpool: std.Thread.Pool = undefined;
        const numThreads = try std.Thread.getCpuCount();
        try std.Thread.Pool.init(&threadpool, .{
            .allocator = alloc,
            .n_jobs = numThreads,
        });

        return .{
            .balls = balls,
            .threadpool = threadpool,
            .numThreads = numThreads,
        };
    }

    pub fn add_ball(self: *Solver, ball: Ball) !void {
        try self.balls.append(ball);
    }

    pub fn grid_pos(self: *Solver, screen_pos: sf.Vec2) u32 {
        const x: u32 = @as(u32, @intFromFloat(screen_pos.x)) / CELL_SIZE;
        const y: u32 = @as(u32, @intFromFloat(screen_pos.y)) / CELL_SIZE;

        const idx: u32 = (y * CELL_COUNT + x);
        return std.math.clamp(idx, @as(u32, 0), @as(u32, self.grid.len - 1));
    }

    pub fn fill_grid(self: *Solver) void {
        for (self.balls.items, 0..) |ball, i| {
            const idx = self.grid_pos(ball.curr_pos);
            self.grid[idx].add_ball(@intCast(i));
        }
    }

    fn add_to_grid(self: *Solver) void {
        @memset(&self.grid, Cell{ .ball_count = 0, .balls = [1]u32{0} ** 10 });
        self.fill_grid();
    }

    pub fn update(self: *Solver, dt: f32) void {
        const sub_dt = dt / @as(f32, @floatFromInt(self.subSteps));
        for (0..self.subSteps) |_| {
            self.add_to_grid();

            var wg: std.Thread.WaitGroup = .{};

            const cellsPerThread = self.grid.len / self.numThreads;

            for (0..self.numThreads) |i| {
                const start = cellsPerThread * i;
                const end = cellsPerThread * (i + 1);
                self.threadpool.spawnWg(&wg, Solver.process_cell, .{ self, @as(u32, @intCast(start)), @as(u32, @intCast(end)) });
            }
            self.threadpool.waitAndWork(&wg);

            for (0..self.numThreads) |i| {
                const start = cellsPerThread * i;
                const end = cellsPerThread * (i + 1);
                self.threadpool.spawnWg(&wg, Solver.process_cell, .{ self, @as(u32, @intCast(start)), @as(u32, @intCast(end)) });
            }

            for (self.balls.items) |*ball| {
                ball.update(sub_dt);
            }
        }
    }

    fn solve_contact(self: *Solver, index1: u32, index2: u32) void {
        const response_coef = 0.75;
        const eps = 0.0001;
        const obj1 = &self.balls.items[index1];
        const obj2 = &self.balls.items[index2];
        const o2_o1 = obj1.curr_pos.sub(obj2.curr_pos);
        const dist2 = o2_o1.length_squared();
        const min_dist = 2 * Ball.radius;

        if (dist2 < min_dist * min_dist and dist2 > eps) {
            const dist = o2_o1.length();
            const delta = response_coef * 0.5 * (min_dist - dist);
            const col_vec = (o2_o1.div_f32(dist)).mul_f32(delta);
            obj1.curr_pos = obj1.curr_pos.add(col_vec);
            obj2.curr_pos = obj2.curr_pos.sub(col_vec);
        }
    }

    fn check_cell_collisions(self: *Solver, ball_idx: u32, cell_idx: u32) void {
        if (cell_idx >= 0 and cell_idx < self.grid.len) {
            for (0..self.grid[cell_idx].ball_count) |i| {
                if (i != ball_idx) {
                    self.solve_contact(ball_idx, self.grid[cell_idx].balls[i]);
                }
            }
        }
    }

    fn process_cell(self: *Solver, start: u32, end: u32) void {
        for (start..end) |_index| {
            const index = @as(u32, @intCast(_index));
            const c = self.grid[index];
            for (0..c.ball_count) |i| {
                const ball_idx = c.balls[i];
                if (index > 1) {
                    self.check_cell_collisions(ball_idx, index - 1);
                }
                self.check_cell_collisions(ball_idx, index);
                self.check_cell_collisions(ball_idx, index + 1);
                self.check_cell_collisions(ball_idx, index + CELL_COUNT - 1);
                self.check_cell_collisions(ball_idx, index + CELL_COUNT);
                self.check_cell_collisions(ball_idx, index + CELL_COUNT + 1);
                if (index > CELL_COUNT) {
                    self.check_cell_collisions(ball_idx, index - CELL_COUNT - 1);
                    self.check_cell_collisions(ball_idx, index - CELL_COUNT);
                    self.check_cell_collisions(ball_idx, index - CELL_COUNT + 1);
                }
            }
        }
    }
};
