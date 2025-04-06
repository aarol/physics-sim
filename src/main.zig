//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

const sf = @import("sfml.zig");

const physics = @import("physics.zig");
const render = @import("render.zig");

pub fn main() !void {
    const mode = sf.sfVideoMode{
        .size = .{ .x = 800, .y = 800 },
        .bitsPerPixel = 32,
    };
    const window = sf.sfRenderWindow_create(mode, "Physics sim", sf.sfClose | sf.sfResize, sf.sfWindowed, null);
    if (window == null) {
        return;
    }

    // Cleanup resources
    defer sf.sfRenderWindow_destroy(window);

    const size = sf.sfRenderWindow_getSize(window);
    sf.sfRenderWindow_setVerticalSyncEnabled(window, true);
    const center = sf.Vec2{ .x = @as(f32, @floatFromInt(size.x)) / 2.0, .y = @as(f32, @floatFromInt(size.y)) / 2.0 };

    const balls = std.ArrayList(physics.Ball).init(std.heap.page_allocator);

    var solver = physics.Solver.new(center, balls);

    const renderer = render.Renderer{ .window = window };

    var moving = false;
    var old_pos: sf.sfVector2f = undefined;

    const spawn_clock = sf.sfClock_create();
    defer sf.sfClock_destroy(spawn_clock);
    const elapsed_clock = sf.sfClock_create();
    defer sf.sfClock_destroy(elapsed_clock);

    // Start the game loop
    const view = @constCast(sf.sfRenderWindow_getDefaultView(window));
    while (sf.sfRenderWindow_isOpen(window)) {
        var event: sf.sfEvent = undefined;
        // Process events
        while (sf.sfRenderWindow_pollEvent(window, &event)) {
            // Close window : exit
            switch (event.type) {
                sf.sfEvtClosed => {
                    std.debug.print("Closed\n", .{});
                    sf.sfRenderWindow_close(window);
                },
                sf.sfEvtMouseButtonPressed => {
                    if (event.mouseButton.button == 0) {
                        moving = true;
                        old_pos = sf.sfRenderWindow_mapPixelToCoords(window, event.mouseButton.position, view);
                    }
                },
                sf.sfEvtMouseButtonReleased => {
                    if (event.mouseButton.button == 0) {
                        moving = false;
                    }
                },
                sf.sfEvtMouseMoved => {
                    if (!moving) break;

                    const new_pos = sf.sfRenderWindow_mapPixelToCoords(window, event.mouseMove.position, view);
                    const delta_pos = .{ .x = old_pos.x - new_pos.x, .y = old_pos.y - new_pos.y };
                    const curr_center = sf.sfView_getCenter(view);
                    sf.sfView_setCenter(view, .{ .x = curr_center.x + delta_pos.x, .y = curr_center.y + delta_pos.y });
                    sf.sfRenderWindow_setView(window, view);
                    old_pos = sf.sfRenderWindow_mapPixelToCoords(window, event.mouseMove.position, view);
                },
                sf.sfEvtMouseWheelScrolled => {
                    if (moving) break;

                    const def_size = sf.sfView_getSize(sf.sfRenderWindow_getDefaultView(window));
                    sf.sfView_setSize(view, def_size);
                    sf.sfView_zoom(view, 1.0 + event.mouseWheelScroll.delta * -0.1);
                    sf.sfRenderWindow_setView(window, view);
                },
                else => {},
            }
        }

        const elapsed = sf.sfClock_getElapsedTime(spawn_clock);
        if (sf.sfTime_asMilliseconds(elapsed) > 16) {
            _ = sf.sfClock_restart(spawn_clock);
            const since_start = sf.sfClock_getElapsedTime(elapsed_clock);
            const seconds = sf.sfTime_asSeconds(since_start);

            const pos = sf.Vec2{ .x = 0, .y = 0 };
            const before_pos = sf.Vec2{ .x = 0.1, .y = -10 };
            const color = render.hslToRgb(@mod(seconds / 50.0, 1.0), 0.75, 0.5);
            try solver.add_ball(physics.Ball.new(pos.add(center), before_pos.add(center), color));
        }

        solver.update(1.0 / 60.0);
        renderer.render(&solver);
    }

    return;
}
