const std = @import("std");

const sf = @import("sfml.zig");

pub const Ball = struct {
    curr_pos: sf.Vec2 = .{ .x = 0, .y = 0 },
    last_pos: sf.Vec2 = .{ .x = 0, .y = 0 },
    acceleration: sf.Vec2 = .{ .x = 0, .y = 100 },
    color: sf.sfColor,

    pub const radius: f32 = 6;

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
const GRID_SIZE: u32 = WORLD_SIZE.x / @as(u32, @intFromFloat(Ball.radius / 2));

pub const Solver = struct {
    contraint_radius: f32 = 300,
    balls: std.ArrayList(Ball),
    sub_steps: u32 = 1,
    grid: [GRID_SIZE * GRID_SIZE]i32 = undefined,

    pub fn new(balls: std.ArrayList(Ball)) Solver {
        return .{ .balls = balls };
    }

    pub fn add_ball(self: *Solver, ball: Ball) !void {
        try self.balls.append(ball);
    }

    pub fn fill_grid(self: *Solver) void {
        for (self.balls.items, 0..) |ball, i| {
            const x = @as(u32, @intFromFloat(ball.curr_pos.x)) / GRID_SIZE;
            const y = @as(u32, @intFromFloat(ball.curr_pos.y)) / GRID_SIZE;
            const idx = y * GRID_SIZE + x;
            if (self.grid[idx] != -1) {
                std.debug.panic("anotha one {}, {} [{}]={} i: {}\n", .{ x, y, idx, self.grid[idx], i });
            }
            std.debug.print("pos {} set {} to {}\n", .{ ball.curr_pos, idx, i });
            self.grid[idx] = @intCast(i);
        }
    }

    pub fn update(self: *Solver, dt: f32) void {
        @memset(&self.grid, -1);
        self.fill_grid();

        for (self.balls.items) |*ball| {
            ball.update(dt);
        }
        self.apply_constraint();
        self.check_collisions();
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

    pub fn check_collisions(self: *Solver) void {
        const response_coef = 0.75;
        const obj_count = self.balls.items.len;
        for (0..obj_count) |i| {
            const object1 = &self.balls.items[i];
            for ((i + 1)..obj_count) |k| {
                const object2 = &self.balls.items[k];
                const v = object1.curr_pos.sub(object2.curr_pos);
                const dist2 = v.length_squared();
                const min_dist = 2 * Ball.radius;

                if (dist2 < min_dist * min_dist) {
                    const dist = v.length();
                    const n = v.div_f32(dist);
                    const mass_ratio_1 = 0.5;
                    const mass_ratio_2 = 0.5;
                    const delta = 0.5 * response_coef * (dist - min_dist);

                    object1.curr_pos = object1.curr_pos.sub(n.mul_f32(mass_ratio_2 * delta));
                    object2.curr_pos = object2.curr_pos.add(n.mul_f32(mass_ratio_1 * delta));
                }
            }
        }
    }
};
