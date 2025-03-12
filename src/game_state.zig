const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const tetromino = @import("tetromino");

const GameSpeed = struct {
    // Classic NES speeds converted to seconds (frames / 60)
    const speeds = [30]f32{
        0.800, // Level 0:  48 frames
        0.717, // Level 1:  43 frames
        0.633, // Level 2:  38 frames
        0.550, // Level 3:  33 frames
        0.467, // Level 4:  28 frames
        0.383, // Level 5:  23 frames
        0.300, // Level 6:  18 frames
        0.217, // Level 7:  13 frames
        0.133, // Level 8:   8 frames
        0.100, // Level 9:   6 frames
        0.083, // Level 10:  5 frames
        0.083, // Level 11:  5 frames
        0.083, // Level 12:  5 frames
        0.067, // Level 13:  4 frames
        0.067, // Level 14:  4 frames
        0.067, // Level 15:  4 frames
        0.050, // Level 16:  3 frames
        0.050, // Level 17:  3 frames
        0.050, // Level 18:  3 frames
        0.033, // Level 19:  2 frames
        0.033, // Level 20:  2 frames
        0.033, // Level 21:  2 frames
        0.033, // Level 22:  2 frames
        0.033, // Level 23:  2 frames
        0.033, // Level 24:  2 frames
        0.033, // Level 25:  2 frames
        0.033, // Level 26:  2 frames
        0.033, // Level 27:  2 frames
        0.033, // Level 28:  2 frames
        0.017, // Level 29:  1 frame
    };

    pub fn getFallDelay(level: usize) f32 {
        if (level >= speeds.len) {
            return speeds[speeds.len - 1];
        }
        return speeds[level];
    }
};

pub const FallingState = struct {
    fall_timer: f32,
    level: usize,

    pub fn init(initial_level: usize) FallingState {
        return .{
            .fall_timer = GameSpeed.getFallDelay(initial_level),
            .level = initial_level,
        };
    }

    pub fn update(self: *FallingState) bool {
        self.fall_timer -= ray.GetFrameTime();
        if (self.fall_timer <= 0) {
            self.fall_timer = GameSpeed.getFallDelay(self.level);
            return true; // Time to fall
        }
        return false;
    }

    pub fn setLevel(self: *FallingState, new_level: usize) void {
        self.level = new_level;
        self.fall_timer = GameSpeed.getFallDelay(self.level);
    }
};

const LinePoints = struct {
    pub const single: u32 = 40;
    pub const double: u32 = 100;
    pub const triple: u32 = 300;
    pub const tetris: u32 = 1200;
};

pub const GameState = struct {
    score: usize = 0,
    level: usize = 0,
    lines_cleared: usize = 0,
    soft_drop_points: u32 = 0,

    const Self = @This();

    pub fn init() Self {
        return .{};
    }

    pub fn calculateLevel(self: *Self) void {
        self.level = self.lines_cleared / 10;
    }

    pub fn addSoftDrop(self: *Self, cells: u32) void {
        self.soft_drop_points += cells;
        self.score += cells;
    }

    pub fn getLinePoints(num_lines: usize) u32 {
        return switch (num_lines) {
            1 => LinePoints.single,
            2 => LinePoints.double,
            3 => LinePoints.triple,
            4 => LinePoints.tetris,
            else => 0,
        };
    }

    pub fn clearLines(self: *Self, num_lines: usize) void {
        if (num_lines == 0) return;
        if (num_lines > 4) return; // Invalid input

        const points = getLinePoints(num_lines);
        self.lines_cleared += num_lines;
        self.calculateLevel();
        self.score += points * (self.level + 1);
    }
};

pub const Grid = struct {
    cells: [][]ray.Color,
    width: usize,
    height: usize,
    allocator: std.mem.Allocator,
    background_color: ray.Color,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize, background_color: ray.Color) !Grid {
        // Allocate the rows
        var cells = try allocator.alloc([]ray.Color, height);
        errdefer allocator.free(cells);

        // Allocate each row
        for (cells, 0..) |*row, y| {
            row.* = try allocator.alloc(ray.Color, width);
            errdefer {
                // Free previously allocated rows if we fail
                for (cells[0..y]) |prev_row| {
                    allocator.free(prev_row);
                }
            }

            // Initialize each cell in the row
            for (row.*) |*cell| {
                cell.* = background_color;
            }
        }

        return Grid{
            .cells = cells,
            .width = width,
            .height = height,
            .allocator = allocator,
            .background_color = background_color,
        };
    }

    pub fn deinit(self: *Grid) void {
        for (self.cells) |row| {
            self.allocator.free(row);
        }
        self.allocator.free(self.cells);
    }

    // Helper method to check if a position is in bounds
    fn isInBounds(self: *Grid, x: i32, y: i32) bool {
        return x >= 0 and x < self.width and y >= 0 and y < self.height;
    }

    // Helper to get a cell safely (returns null if out of bounds)
    fn getCell(self: *Grid, x: i32, y: i32) ?*ray.Color {
        if (!self.isInBounds(x, y)) return null;
        return &self.cells[@intCast(y)][@intCast(x)];
    }

    pub fn isEmpty(self: *Grid, x: i32, y: i32) bool {
        if (self.getCell(x, y)) |cell| {
            return areColorsEqual(cell, &self.background_color);
        }
        return false;
    }

    // Clear the grid (set all cells to default color)
    pub fn clear(self: *Grid) void {
        for (self.cells) |row| {
            for (row) |*cell| {
                cell.* = self.background_color;
            }
        }
    }

    pub fn addPiece(self: *Grid, piece: *const tetromino.Tetromino) void {
        const cells = piece.getGridCells();
        for (cells) |cell| {
            if (self.getCell(cell.position.x, cell.position.y)) |gridCell| {
                gridCell.* = cell.color;
            }
        }
    }

    fn hasSpace(self: *Grid, cells: []const tetromino.GridCell) bool {
        for (cells) |cell| {
            if (!self.isEmpty(cell.position.x, cell.position.y)) {
                return false;
            }
        }
        return true;
    }

    pub fn hasSpaceForPiece(self: *Grid, piece: *const tetromino.Tetromino) bool {
        const cells = piece.getGridCells();
        return self.hasSpace(&cells);
    }

    pub fn isLineComplete(self: *Grid, y: usize) bool {
        for (0..self.width) |x| {
            if (self.isEmpty(@intCast(x), @intCast(y))) {
                return false;
            }
        }
        return true;
    }

    // Move all lines above the given line down by one
    fn shiftLinesDown(self: *Grid, from_y: usize) void {
        var y = from_y;
        while (y > 0) {
            for (0..self.width) |x| {
                self.cells[y][x] = self.cells[y - 1][x];
            }
            y -= 1;
        }

        // Clear the top line
        for (0..self.width) |x| {
            self.cells[0][x] = self.background_color;
        }
    }

    pub fn removeCompletedLines(self: *Grid) usize {
        var lines_cleared: usize = 0;
        var y: usize = 0;

        while (y < self.height) {
            if (self.isLineComplete(y)) {
                self.shiftLinesDown(y);
                lines_cleared += 1;
                // Don't increment y, check the same line again
                // as new line has shifted down
            } else {
                y += 1;
            }
        }
        return lines_cleared;
    }

    pub fn findDropPosition(self: *Grid, piece: *const tetromino.Tetromino) tetromino.Tetromino {
        var test_piece = piece.*;
        var last_valid = piece.*;

        while (self.hasSpaceForPiece(&test_piece)) {
            last_valid = test_piece;
            test_piece.position.y += 1;
        }

        return last_valid;
    }
};

pub fn areColorsEqual(a: *const ray.Color, b: *const ray.Color) bool {
    return a.r == b.r and
        a.g == b.g and
        a.b == b.b and
        a.a == b.a;
}
