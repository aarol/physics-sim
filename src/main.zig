//! By convention, main.zig is where your main function lives in the case that
//! you are building an executable. If you are making a library, the convention
//! is to delete this file and start with root.zig instead.

const std = @import("std");

const sf = @cImport({
    @cInclude("SFML/Graphics.h");
    @cInclude("SFML/Window.h");
    @cInclude("SFML/System.h");
});

pub fn main() !void {
    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
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

    // Start the game loop
    var event: sf.sfEvent = undefined;
    while (sf.sfRenderWindow_isOpen(window) == sf.sfTrue) {
        // Process events
        while (sf.sfRenderWindow_pollEvent(window, &event) == sf.sfTrue) {
            // Close window : exit
            if (event.type == sf.sfEvtClosed)
                sf.sfRenderWindow_close(window);
        }

        // Clear the screen
        sf.sfRenderWindow_clear(window, sf.sfBlack);

        // Update the window
        sf.sfRenderWindow_display(window);
    }

    // Cleanup resources
    sf.sfRenderWindow_destroy(window);

    return;
}
