const std = @import("std");
const sf = @import("sfml.zig");
const physics = @import("physics.zig");

pub const Renderer = struct {
    window: ?*sf.sfRenderWindow,

    pub fn render(self: Renderer, solver: *physics.Solver) void {
        const window = self.window;
        // Clear the screen
        sf.sfRenderWindow_clear(window, sf.sfBlack);

        {
            const background = sf.sfCircleShape_create();
            defer sf.sfCircleShape_destroy(background);
            sf.sfCircleShape_setFillColor(background, sf.sfColor_fromRGB(50, 50, 50));
            sf.sfCircleShape_setPointCount(background, 64);
            sf.sfCircleShape_setRadius(background, solver.contraint_radius);
            sf.sfCircleShape_setOrigin(background, .{ .x = solver.contraint_radius, .y = solver.contraint_radius });
            sf.sfCircleShape_setPosition(background, @bitCast(solver.constraint_center));
            sf.sfRenderWindow_drawCircleShape(window, background, null);
        }

        const circle = sf.sfCircleShape_create();
        defer sf.sfCircleShape_destroy(circle);
        sf.sfCircleShape_setFillColor(circle, sf.sfWhite);
        sf.sfCircleShape_setPointCount(circle, 32);
        sf.sfCircleShape_setRadius(circle, physics.Ball.radius);
        sf.sfCircleShape_setOrigin(circle, .{ .x = physics.Ball.radius, .y = physics.Ball.radius });

        for (solver.balls.items) |ball| {
            sf.sfCircleShape_setPosition(circle, @bitCast(ball.curr_pos));
            sf.sfCircleShape_setFillColor(circle, ball.color);
            sf.sfRenderWindow_drawCircleShape(window, circle, null);
        }

        // Update the window
        sf.sfRenderWindow_display(window);
    }
};

pub fn random_color(rand: *std.Random.Xoshiro256) sf.sfColor {
    const r = rand.random().uintAtMost(u8, 255);
    const g = rand.random().uintAtMost(u8, 255);
    const b = rand.random().uintAtMost(u8, 255);

    return sf.sfColor_fromRGB(r, g, b);
}

pub fn hslToRgb(h: f32, s: f32, l: f32) sf.sfColor {
    var r: f32 = 0.0;
    var g: f32 = 0.0;
    var b: f32 = 0.0;
    if (s == 0) {
        r = l;
        g = l;
        b = l; // achromatic
    } else {
        const q = if (l < 0.5) l * (1 + s) else l + s - l * s;
        const p = 2 * l - q;
        r = hueToRgb(p, q, h + 1.0 / 3.0);
        g = hueToRgb(p, q, h);
        b = hueToRgb(p, q, h - 1.0 / 3.0);
    }

    return sf.sfColor_fromRGB(@intFromFloat(r * 255), @intFromFloat(g * 255), @intFromFloat(b * 255));
}

fn hueToRgb(p: f32, q: f32, t: f32) f32 {
    const t_norm = if (t < 0.0) t + 1.0 else if (t > 1.0) t - 1.0 else t;

    if (t_norm < 1.0 / 6.0) return p + (q - p) * 6.0 * t_norm;
    if (t_norm < 0.5) return q;
    if (t_norm < 2.0 / 3.0) return p + (q - p) * (2.0 / 3.0 - t_norm) * 6.0;
    return p;
}
