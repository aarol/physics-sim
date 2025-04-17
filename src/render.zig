const std = @import("std");
const sf = @import("sfml.zig");
const physics = @import("physics.zig");

pub const Renderer = struct {
    window: ?*sf.sfRenderWindow,
    circleShape: ?*sf.sfCircleShape,
    gridShape: ?*sf.sfRectangleShape,
    backgroundShape: ?*sf.sfCircleShape,

    pub fn init(window: ?*sf.sfRenderWindow) Renderer {
        const background = sf.sfCircleShape_create();
        sf.sfCircleShape_setFillColor(background, sf.sfColor_fromRGB(50, 50, 50));
        sf.sfCircleShape_setPointCount(background, 64);
        sf.sfCircleShape_setRadius(background, physics.CONSTRAINT_RADIUS);
        sf.sfCircleShape_setOrigin(background, .{ .x = physics.CONSTRAINT_RADIUS, .y = physics.CONSTRAINT_RADIUS });
        sf.sfCircleShape_setPosition(background, @bitCast(physics.CENTER));

        const ball = sf.sfCircleShape_create();
        sf.sfCircleShape_setFillColor(ball, sf.sfWhite);
        sf.sfCircleShape_setPointCount(ball, 32);
        sf.sfCircleShape_setRadius(ball, physics.Ball.radius);
        sf.sfCircleShape_setOrigin(ball, .{ .x = physics.Ball.radius, .y = physics.Ball.radius });

        const grid = sf.sfRectangleShape_create();
        sf.sfRectangleShape_setSize(grid, .{ .x = physics.CELL_SIZE, .y = physics.CELL_SIZE });
        sf.sfRectangleShape_setOutlineThickness(grid, 2.0);
        sf.sfRectangleShape_setOutlineColor(grid, sf.sfBlue);
        sf.sfRectangleShape_setFillColor(grid, sf.sfTransparent);

        return .{
            .window = window,
            .circleShape = ball,
            .backgroundShape = background,
            .gridShape = grid,
        };
    }

    pub fn deinit(self: Renderer) void {
        sf.sfRectangleShape_destroy(self.gridShape);
        sf.sfCircleShape_destroy(self.backgroundShape);
        sf.sfCircleShape_destroy(self.circleShape);
    }

    pub fn render(self: Renderer, solver: *physics.Solver) void {
        const window = self.window;
        // Clear the screen
        sf.sfRenderWindow_clear(window, sf.sfBlack);

        sf.sfRenderWindow_drawCircleShape(window, self.backgroundShape, null);

        for (solver.balls.items) |ball| {
            sf.sfCircleShape_setPosition(self.circleShape, @bitCast(ball.curr_pos));
            // const idx = solver.grid_pos(ball.curr_pos);
            // const col = hslToRgb(@mod(@as(f32, @floatFromInt(idx)) / 10.0, 1.0), 0.75, 0.5);
            sf.sfCircleShape_setFillColor(self.circleShape, ball.color);
            sf.sfRenderWindow_drawCircleShape(window, self.circleShape, null);
        }

        // draws cell grid for debugging
        // for (0..physics.CELL_COUNT) |x| {
        //     for (0..physics.CELL_COUNT) |y| {
        //         const xf: f32 = @floatFromInt(x * physics.CELL_SIZE);
        //         const yf: f32 = @floatFromInt(y * physics.CELL_SIZE);
        //         sf.sfRectangleShape_setPosition(self.gridShape, .{ .x = xf, .y = yf });
        //         sf.sfRenderWindow_drawRectangleShape(window, self.gridShape, null);
        //     }
        // }

        // Update the window
        sf.sfRenderWindow_display(window);
    }
};

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
