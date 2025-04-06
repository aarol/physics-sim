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
            sf.sfCircleShape_setOrigin(background, sf.sfVector2f{ .x = solver.contraint_radius, .y = solver.contraint_radius });
            sf.sfCircleShape_setPosition(background, @bitCast(solver.constraint_center));
            sf.sfRenderWindow_drawCircleShape(window, background, null);
        }

        const circle = sf.sfCircleShape_create();
        defer sf.sfCircleShape_destroy(circle);
        sf.sfCircleShape_setFillColor(circle, sf.sfWhite);
        sf.sfCircleShape_setPointCount(circle, 32);

        for (solver.balls.items) |ball| {
            sf.sfCircleShape_setOrigin(circle, sf.sfVector2f{ .x = physics.Ball.radius, .y = physics.Ball.radius });
            sf.sfCircleShape_setPosition(circle, @bitCast(ball.curr_pos));
            sf.sfCircleShape_setFillColor(circle, ball.color);
            sf.sfCircleShape_setRadius(circle, physics.Ball.radius);
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
