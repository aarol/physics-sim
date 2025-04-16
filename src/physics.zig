const std = @import("std");

const sf = @import("sfml.zig");

pub const Ball = struct {
    curr_pos: sf.Vec2 = .{ .x = 0, .y = 0 },
    last_pos: sf.Vec2 = .{ .x = 0, .y = 0 },
    acceleration: sf.Vec2 = .{ .x = 0, .y = 100 },
    color: sf.sfColor,

    pub const radius: f32 = 1.0;

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
        const dist = v.length();
        if (dist > (CONSTRAINT_RADIUS - Ball.radius)) {
            const n = v.div_f32(dist);
            self.curr_pos = CENTER.sub(n.mul_f32(CONSTRAINT_RADIUS - Ball.radius));
        }
    }
};

pub const WORLD_SIZE = sf.sfVector2u{ .x = 600, .y = 600 };
pub const CENTER = sf.Vec2{ .x = WORLD_SIZE.x / 2, .y = WORLD_SIZE.y / 2 };
const GRID_SIZE: u32 = WORLD_SIZE.x / 1;

pub const CONSTRAINT_RADIUS = 300;

const Cell = struct {
    ball_count: u32,
    balls: [4]u32,

    fn add_ball(self: *Cell, idx: u32) void {
        if (self.ball_count < 4) {
            self.balls[self.ball_count] = idx;
            self.ball_count += 1;
        }
    }
};

pub const Solver = struct {
    balls: std.ArrayList(Ball),
    sub_steps: u32 = 1,
    grid: [GRID_SIZE * GRID_SIZE]Cell = undefined,

    pub const contraint_radius: f32 = 300;

    pub fn new(balls: std.ArrayList(Ball)) Solver {
        return .{ .balls = balls };
    }

    pub fn add_ball(self: *Solver, ball: Ball) !void {
        try self.balls.append(ball);
    }

    pub fn grid_pos(ball: Ball) u32 {
        const x: f32 = (ball.curr_pos.x) / GRID_SIZE;
        const y: f32 = (ball.curr_pos.y) / GRID_SIZE;
        const idx = @as(u32, @intFromFloat(y * GRID_SIZE + x));
        return idx;
    }

    pub fn fill_grid(self: *Solver) void {
        for (self.balls.items, 0..) |ball, i| {
            const x: f32 = (ball.curr_pos.x) / GRID_SIZE;
            const y: f32 = (ball.curr_pos.y) / GRID_SIZE;
            const idx = @as(u32, @intFromFloat(y * GRID_SIZE + x));
            // std.debug.print("pos {} set {} to {}\n", .{ ball.curr_pos, idx, i });
            self.grid[idx].add_ball(@intCast(i));
            // std.debug.assert(found);
        }
    }

    fn add_to_grid(self: *Solver) void {
        @memset(&self.grid, Cell{ .ball_count = 0, .balls = [4]u32{ 0, 0, 0, 0 } });
        self.fill_grid();
    }

    pub fn update(self: *Solver, dt: f32) void {
        const sub_dt = dt / 8.0;
        for (0..8) |_| {
            self.add_to_grid();
            for (0..self.grid.len) |i| {
                self.process_cell(@intCast(i));
            }
            for (self.balls.items) |*ball| {
                ball.update(sub_dt);
            }
        }
    }

    fn solve_contact(self: *Solver, index1: u32, index2: u32) void {
        const response_coef = 1;
        const eps = 0.0001;
        const obj1 = &self.balls.items[index1];
        const obj2 = &self.balls.items[index2];
        const o2_o1 = obj1.curr_pos.sub(obj2.curr_pos);
        const dist2 = o2_o1.length();

        if (dist2 < 1.0 and dist2 > eps) {
            const dist = o2_o1.length();
            const delta = response_coef * 0.5 * (Ball.radius * 2 - dist);
            const col_vec = (o2_o1.div_f32(dist)).mul_f32(delta);
            obj1.curr_pos = obj1.curr_pos.add(col_vec);
            obj2.curr_pos = obj2.curr_pos.sub(col_vec);
        }
    }

    fn check_cell_collisions(self: *Solver, ball_idx: u32, cell: *Cell) void {
        for (0..cell.ball_count) |i| {
            self.solve_contact(ball_idx, cell.balls[i]);
        }
    }

    fn process_cell(self: *Solver, index: u32) void {
        const c = self.grid[index];
        for (0..c.ball_count) |i| {
            const ball_idx = c.balls[i];
            self.check_cell_collisions(ball_idx, &self.grid[index - 1]);
            self.check_cell_collisions(ball_idx, &self.grid[index]);
            self.check_cell_collisions(ball_idx, &self.grid[index + 1]);
            self.check_cell_collisions(ball_idx, &self.grid[index + GRID_SIZE - 1]);
            self.check_cell_collisions(ball_idx, &self.grid[index + GRID_SIZE]);
            self.check_cell_collisions(ball_idx, &self.grid[index + GRID_SIZE + 1]);
            if (index > GRID_SIZE) {
                self.check_cell_collisions(ball_idx, &self.grid[index - GRID_SIZE - 1]);
                self.check_cell_collisions(ball_idx, &self.grid[index - GRID_SIZE]);
                self.check_cell_collisions(ball_idx, &self.grid[index - GRID_SIZE + 1]);
            }
        }
    }
};
