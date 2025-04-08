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
    }
};

pub const WORLD_SIZE = sf.sfVector2u{ .x = 600, .y = 600 };
pub const CENTER = sf.Vec2{ .x = WORLD_SIZE.x / 2, .y = WORLD_SIZE.y / 2 };
const GRID_SIZE: u32 = WORLD_SIZE.x;

const Cell = struct {
    ball_count: u32,
    balls: [4]u32,

    fn add_ball(self: *Cell, idx: u32) void {
        self.balls[self.ball_count] = idx;
        self.ball_count += 1;
    }
};

pub const Solver = struct {
    contraint_radius: f32 = 300,
    balls: std.ArrayList(Ball),
    sub_steps: u32 = 1,
    grid: [GRID_SIZE * GRID_SIZE]Cell = undefined,

    pub fn new(balls: std.ArrayList(Ball)) Solver {
        return .{ .balls = balls };
    }

    pub fn add_ball(self: *Solver, ball: Ball) !void {
        try self.balls.append(ball);
    }

    pub fn fill_grid(self: *Solver) void {
        for (self.balls.items, 0..) |ball, i| {
            const x = (ball.curr_pos.x) / GRID_SIZE;
            const y = (ball.curr_pos.y) / GRID_SIZE;
            const idx = @as(u32, @intFromFloat(y * GRID_SIZE + x));
            // std.debug.print("pos {} set {} to {}\n", .{ ball.curr_pos, idx, i });
            self.grid[idx].add_ball(@intCast(i));
            // std.debug.assert(found);
        }
    }

    pub fn update(self: *Solver, dt: f32) void {
        const sub_dt = dt / 8.0;
        for (0..8) |_| {
            for (self.balls.items) |*ball| {
                @memset(&self.grid, Cell{ .ball_count = 0, .balls = [4]u32{ 0, 0, 0, 0 } });
                self.fill_grid();
                for (0..self.grid.len) |i| {
                    self.process_cell(@intCast(i));
                }
                ball.update(sub_dt);
                self.apply_constraint();
            }
        }
    }

    pub fn apply_constraint(self: *Solver) void {
        for (self.balls.items) |*ball| {
            const v = CENTER.sub(ball.curr_pos);
            const dist = v.length();
            if (dist > (self.contraint_radius - Ball.radius)) {
                const n = v.div_f32(dist);
                ball.curr_pos = CENTER.sub(n.mul_f32(self.contraint_radius - Ball.radius));
            }
        }
    }

    fn solve_contact(self: *Solver, index1: u32, index2: u32) void {
        const response_coef = 1;
        const eps = 0.0001;
        const obj1 = &self.balls.items[index1];
        const obj2 = &self.balls.items[index2];
        const o2_o1 = obj1.curr_pos.sub(obj2.curr_pos);
        const dist2 = o2_o1.length_squared();

        if (dist2 < Ball.radius and dist2 > eps) {
            const dist = o2_o1.length();
            const delta = response_coef * 0.5 * (1.0 - dist);
            const col_vec = (o2_o1.div_f32(dist)).mul_f32(delta);
            obj1.curr_pos = obj1.curr_pos.add(col_vec);
            obj2.curr_pos = obj1.curr_pos.sub(col_vec);
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
            self.check_cell_collisions(ball_idx, &self.grid[index - GRID_SIZE - 1]);
            self.check_cell_collisions(ball_idx, &self.grid[index - GRID_SIZE]);
            self.check_cell_collisions(ball_idx, &self.grid[index - GRID_SIZE + 1]);
        }
    }
};
