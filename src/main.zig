//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

const sf = @import("sfml.zig");

const physics = @import("physics.zig");
const render = @import("render.zig");

pub fn main() !void {
    std.debug.print("hre", .{});

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

    var rand = std.Random.DefaultPrng.init(0);

    for (0..50) |_| {
        const f = rand.random().float(f32) * 100 - 50;
        const pos = sf.Vec2{ .x = f, .y = f };
        const color = render.random_color(&rand);
        try solver.add_ball(physics.Ball.new(pos.add(center), pos.add(center), color));
    }

    const renderer = render.Renderer{ .window = window };

    var moving = false;
    var old_pos: sf.sfVector2f = undefined;

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
                    std.debug.print("delta {}\n", .{delta_pos});
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

        solver.update(1.0 / 60.0);
        renderer.render(&solver);
    }

    return;
}
