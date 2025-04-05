//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

const sf = @import("sfml.zig");

const app = @import("game.zig");

pub fn main() !void {
    std.debug.print("hre", .{});

    const mode = sf.sfVideoMode{
        .width = 800,
        .height = 600,
        .bitsPerPixel = 32,
    };
    const settings: [*c]const sf.sfContextSettings = null;
    const window = sf.sfRenderWindow_create(mode, "SFML window", sf.sfResize | sf.sfClose, settings);
    if (window == null) {
        return;
    }

    const size = sf.sfRenderWindow_getSize(window);
    const center = sf.Vec2{ .x = @as(f32, @floatFromInt(size.x)) / 2.0, .y = @as(f32, @floatFromInt(size.y)) / 2.0 };

    var balls = std.ArrayList(*app.Ball).init(std.heap.page_allocator);

    var ball = app.Ball.new();
    try balls.append(&ball);
    var solver = app.Solver.new(center, balls);

    const renderer = Renderer{ .window = window };

    // Start the game loop
    var event: sf.sfEvent = undefined;
    while (sf.sfRenderWindow_isOpen(window) != sf.sfFalse) {

        // Process events
        while (sf.sfRenderWindow_pollEvent(window, &event) != sf.sfFalse) {
            // Close window : exit
            if (event.type == sf.sfEvtClosed) {
                std.debug.print("Closed\n", .{});
                sf.sfRenderWindow_close(window);
            }
        }

        solver.update(1.0 / 60.0);
        renderer.render(&solver);
    }

    // Cleanup resources
    sf.sfRenderWindow_destroy(window);

    return;
}

const Renderer = struct {
    window: ?*sf.sfRenderWindow,

    pub fn render(self: Renderer, solver: *app.Solver) void {
        const window = self.window;
        // Clear the screen
        sf.sfRenderWindow_clear(window, sf.sfBlack);

        {
            const background = sf.sfCircleShape_create();
            defer sf.sfCircleShape_destroy(background);
            sf.sfCircleShape_setFillColor(background, sf.sfColor_fromRGB(100, 100, 100));
            sf.sfCircleShape_setPointCount(background, 32);
            sf.sfCircleShape_setRadius(background, solver.contraint_radius);
            sf.sfCircleShape_setOrigin(background, sf.sfVector2f{ .x = solver.contraint_radius, .y = solver.contraint_radius });
            sf.sfCircleShape_setPosition(background, @bitCast(solver.constraint_center));
            sf.sfRenderWindow_drawCircleShape(window, background, null);
        }

        const circle = sf.sfCircleShape_create();
        defer sf.sfCircleShape_destroy(circle);
        sf.sfCircleShape_setFillColor(circle, sf.sfColor_fromRGB(255, 255, 255));
        sf.sfCircleShape_setPointCount(circle, 10);

        for (solver.balls.items) |ball| {
            sf.sfCircleShape_setOrigin(circle, sf.sfVector2f{ .x = ball.radius, .y = ball.radius });
            sf.sfCircleShape_setPosition(circle, @bitCast(ball.curr_pos));
            sf.sfCircleShape_setRadius(circle, ball.radius);
            sf.sfRenderWindow_drawCircleShape(window, circle, null);
        }

        // Update the window
        sf.sfRenderWindow_display(window);
    }
};
