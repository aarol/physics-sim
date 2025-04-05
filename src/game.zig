const std = @import("std");

const sf = @import("sfml.zig");

pub const Ball = struct {
    curr_pos: sf.Vec2 = .{ .x = 0, .y = 0 },
    last_pos: sf.Vec2 = .{ .x = 0, .y = 0 },
    acceleration: sf.Vec2 = .{ .x = 0, .y = 1 },
    radius: f32 = 10,

    pub fn new() Ball {
        return .{};
    }

    pub fn update(self: *Ball, dt: f32) void {
        const at2 = self.acceleration.mul_f32(dt * dt);
        const next_pos = self.curr_pos.mul_f32(2).sub(self.last_pos).add(at2);
        self.last_pos = self.curr_pos;
        self.curr_pos = next_pos;
    }
};

pub const Solver = struct {
    constraint_center: sf.Vec2,
    contraint_radius: f32,
    balls: std.ArrayList(*Ball),
    sub_steps: u32 = 1,

    pub fn new(center: sf.Vec2, balls: std.ArrayList(*Ball)) Solver {
        return Solver{ .constraint_center = center, .contraint_radius = 100, .balls = balls };
    }

    pub fn update(self: *Solver, dt: f32) void {
        for (self.balls.items) |ball| {
            ball.update(dt);
        }
        apply_constraint(self);
    }

    pub fn apply_constraint(self: *Solver) void {
        for (self.balls.items) |ball| {
            const v = self.constraint_center.sub(ball.curr_pos);
            const dist = v.length();
            if (dist > (self.contraint_radius - ball.radius)) {
                const n = v.div_f32(dist);
                ball.curr_pos = self.constraint_center.sub(n.mul_f32(self.contraint_radius - ball.radius));
            }
        }
    }
};
