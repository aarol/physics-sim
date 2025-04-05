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

    var moving = false;
    // var zoom: f32 = 1;
    var old_pos: sf.sfVector2f = undefined;
    // Start the game loop
    const view = @constCast(sf.sfRenderWindow_getDefaultView(window));
    while (sf.sfRenderWindow_isOpen(window) != sf.sfFalse) {
        var event: sf.sfEvent = undefined;
        // Process events
        while (sf.sfRenderWindow_pollEvent(window, &event) != sf.sfFalse) {
            // Close window : exit
            switch (event.type) {
                sf.sfEvtClosed => {
                    std.debug.print("Closed\n", .{});
                    sf.sfRenderWindow_close(window);
                },
                sf.sfEvtMouseButtonPressed => {
                    if (event.mouseButton.button == 0) {
                        moving = true;
                        old_pos = sf.sfRenderWindow_mapPixelToCoords(window, sf.sfVector2i{ .x = event.mouseButton.x, .y = event.mouseButton.y }, view);
                    }
                },
                sf.sfEvtMouseButtonReleased => {
                    if (event.mouseButton.button == 0) {
                        moving = false;
                    }
                },
                sf.sfEvtMouseMoved => {
                    if (!moving) break;

                    const v2i = sf.sfVector2i{ .x = event.mouseMove.x, .y = event.mouseMove.y };
                    const new_pos = sf.sfRenderWindow_mapPixelToCoords(window, v2i, view);
                    const delta_pos = sf.sfVector2f{ .x = old_pos.x - new_pos.x, .y = old_pos.y - new_pos.y };
                    std.debug.print("delta {}\n", .{delta_pos});
                    const curr_center = sf.sfView_getCenter(view);
                    sf.sfView_setCenter(view, sf.sfVector2f{ .x = curr_center.x + delta_pos.x, .y = curr_center.y + delta_pos.y });
                    sf.sfRenderWindow_setView(window, view);
                    old_pos = sf.sfRenderWindow_mapPixelToCoords(window, v2i, view);
                },
                sf.sfEvtMouseWheelScrolled => {
                    if (moving) break;

                    const def_size = sf.sfView_getSize(sf.sfRenderWindow_getDefaultView(window));
                    sf.sfView_setSize(view, def_size);
                    sf.sfView_zoom(view, 1.0 + event.mouseWheelScroll.delta * 0.1);
                    sf.sfRenderWindow_setView(window, view);
                },
                else => {},
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
