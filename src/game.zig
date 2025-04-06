const std = @import("std");

const sf = @import("sfml.zig");

pub const Ball = struct {
    curr_pos: sf.Vec2 = .{ .x = 0, .y = 0 },
    last_pos: sf.Vec2 = .{ .x = 0, .y = 0 },
    acceleration: sf.Vec2 = .{ .x = 0, .y = 1 },
    radius: f32 = 10,

    pub fn new(curr_pos: sf.Vec2, last_pos: sf.Vec2) Ball {
        return Ball{
            .curr_pos = curr_pos,
            .last_pos = last_pos,
        };
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
    balls: std.ArrayList(Ball),
    sub_steps: u32 = 1,

    pub fn new(center: sf.Vec2, balls: std.ArrayList(Ball)) Solver {
        return Solver{ .constraint_center = center, .contraint_radius = 300, .balls = balls };
    }

    pub fn add_ball(self: *Solver, ball: Ball) !void {
        try self.balls.append(ball);
    }

    pub fn update(self: *Solver, dt: f32) void {
        for (self.balls.items) |*ball| {
            ball.update(dt);
        }
        self.apply_constraint();
        self.check_collisions();
    }

    pub fn apply_constraint(self: *Solver) void {
        for (self.balls.items) |*ball| {
            const v = self.constraint_center.sub(ball.curr_pos);
            const dist = v.length();
            if (dist > (self.contraint_radius - ball.radius)) {
                const n = v.div_f32(dist);
                ball.curr_pos = self.constraint_center.sub(n.mul_f32(self.contraint_radius - ball.radius));
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
                const min_dist = object1.radius + object2.radius;

                if (dist2 < min_dist * min_dist) {
                    const dist = v.length();
                    const n = v.div_f32(dist);
                    const mass_ratio_1 = object1.radius / (object1.radius + object2.radius);
                    const mass_ratio_2 = object2.radius / (object1.radius + object2.radius);
                    const delta = 0.5 * response_coef * (dist - min_dist);

                    object1.curr_pos = object1.curr_pos.sub(n.mul_f32(mass_ratio_2 * delta));
                    object2.curr_pos = object2.curr_pos.add(n.mul_f32(mass_ratio_1 * delta));
                }
            }
        }
    }
};
