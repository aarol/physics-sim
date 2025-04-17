pub usingnamespace @cImport({
    @cInclude("CSFML/Graphics.h");
    @cInclude("CSFML/Window.h");
    @cInclude("CSFML/System.h");
});

const std = @import("std");

pub const Vec2 = extern struct {
    x: f32,
    y: f32,

    pub fn add(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x + other.x, .y = self.y + other.y };
    }
    pub fn sub(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x - other.x, .y = self.y - other.y };
    }

    pub fn mul(self: Vec2, other: Vec2) Vec2 {
        return .{ .x = self.x * other.x, .y = self.y * other.y };
    }
    pub fn mul_f32(self: Vec2, f: f32) Vec2 {
        return .{ .x = self.x * f, .y = self.y * f };
    }

    pub fn div_f32(self: Vec2, f: f32) Vec2 {
        return .{ .x = self.x / f, .y = self.y / f };
    }

    pub fn length(self: Vec2) f32 {
        return std.math.sqrt(self.x * self.x + self.y * self.y);
    }
    pub fn length_squared(self: Vec2) f32 {
        return self.x * self.x + self.y * self.y;
    }

    pub fn normalized(self: Vec2) Vec2 {
        return self.div_f32(self.length());
    }
};
