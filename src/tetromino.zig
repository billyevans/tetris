const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});

pub const Position = struct {
    x: i32,
    y: i32,
};

pub const GridCell = struct {
    position: Position,
    color: ray.Color,
};

pub const TetrominoShape = struct {
    positions: []const Position,
};

pub const Rotation = enum(u2) {
    up = 0,
    right = 1,
    down = 2,
    left = 3,

    pub fn next(self: Rotation) Rotation {
        return @enumFromInt((@intFromEnum(self) +% 1) & 3);
    }

    pub fn previous(self: Rotation) Rotation {
        return @enumFromInt((@intFromEnum(self) +% 3) & 3);
    }
};

const tetris_colors = struct {
    cyan: ray.Color = .{ .r = 0, .g = 255, .b = 255, .a = 255 },
    yellow: ray.Color = .{ .r = 255, .g = 255, .b = 0, .a = 255 },
    purple: ray.Color = .{ .r = 128, .g = 0, .b = 128, .a = 255 },
    green: ray.Color = .{ .r = 0, .g = 255, .b = 0, .a = 255 },
    red: ray.Color = .{ .r = 255, .g = 0, .b = 0, .a = 255 },
    blue: ray.Color = .{ .r = 0, .g = 0, .b = 255, .a = 255 },
    orange: ray.Color = .{ .r = 255, .g = 165, .b = 0, .a = 255 },
}{};

const i_positions = [_]Position{
    .{ .x = -2, .y = 0 },  // ████
    .{ .x = -1, .y = 0 },
    .{ .x = 0, .y = 0 },
    .{ .x = 1, .y = 0 },
};

const o_positions = [_]Position{
    .{ .x = -1, .y = 0 },  // ██
    .{ .x = 0, .y = 0 },   // ██
    .{ .x = -1, .y = 1 },
    .{ .x = 0, .y = 1 },
};

const t_positions = [_]Position{
    .{ .x = 0, .y = 1 },   //  █
    .{ .x = -1, .y = 0 },  // ███
    .{ .x = 0, .y = 0 },
    .{ .x = 1, .y = 0 },
};

const s_positions = [_]Position{
    .{ .x = 0, .y = 1 },   //  ██
    .{ .x = 1, .y = 1 },   // ██
    .{ .x = -1, .y = 0 },
    .{ .x = 0, .y = 0 },
};

const z_positions = [_]Position{
    .{ .x = -1, .y = 1 },  // ██
    .{ .x = 0, .y = 1 },   //  ██
    .{ .x = 0, .y = 0 },
    .{ .x = 1, .y = 0 },
};

const j_positions = [_]Position{
    .{ .x = -1, .y = 1 },  // █
    .{ .x = -1, .y = 0 },  // ███
    .{ .x = 0, .y = 0 },
    .{ .x = 1, .y = 0 },
};

const l_positions = [_]Position{
    .{ .x = 1, .y = 1 },   //   █
    .{ .x = -1, .y = 0 },  // ███
    .{ .x = 0, .y = 0 },
    .{ .x = 1, .y = 0 },
};

pub const TetrominoType = enum(u3) {
    i = 0,
    o = 1,
    t = 2,
    s = 3,
    z = 4,
    j = 5,
    l = 6,

    pub fn random(rand: *std.Random) TetrominoType {
        return @enumFromInt(rand.intRangeAtMost(u3, 0, 6));
    }
};

pub const tetromino_shapes = [_]TetrominoShape{
    .{ .positions = &i_positions },  // I piece (flat)
    .{ .positions = &o_positions },  // O piece (2x2 square)
    .{ .positions = &t_positions },  // T piece (pointing up)
    .{ .positions = &s_positions },  // S piece (standard S)
    .{ .positions = &z_positions },  // Z piece (standard Z)
    .{ .positions = &j_positions },  // J piece (pointing left)
    .{ .positions = &l_positions },  // L piece (pointing right)
};

pub fn rotatePosition(pos: Position, rotation: Rotation) Position {
    return switch (rotation) {
        .up => pos,
        .right => .{ .x = -pos.y, .y = pos.x },
        .down => .{ .x = -pos.x, .y = -pos.y },
        .left => .{ .x = pos.y, .y = -pos.x },
    };
}

pub fn getTetrominoColor(tetromino_type: TetrominoType) ray.Color {
    return switch (tetromino_type) {
        .i => tetris_colors.cyan,
        .o => tetris_colors.yellow,
        .t => tetris_colors.purple,
        .s => tetris_colors.green,
        .z => tetris_colors.red,
        .j => tetris_colors.blue,
        .l => tetris_colors.orange,
    };
}

pub const Tetromino = struct {
    tetromino_type: TetrominoType,
    position: Position,
    rotation: Rotation,

    pub fn init(tetromino_type: TetrominoType, position: Position) Tetromino {
        return .{
            .tetromino_type = tetromino_type,
            .position = position,
            .rotation = .up,
        };
    }

    pub fn initRandom(rand: *std.Random, position: Position) Tetromino {
        return init(TetrominoType.random(rand), position);
    }

    pub fn getGridCells(self: *const Tetromino, allocator: std.mem.Allocator) ![]GridCell {
        const shape = tetromino_shapes[@intFromEnum(self.tetromino_type)];
        const color = getTetrominoColor(self.tetromino_type);

        // Allocate memory for the cells
        var grid_cells = try allocator.alloc(GridCell, shape.positions.len);
        errdefer allocator.free(grid_cells);

        // Create each cell with proper position and color
        for (shape.positions, 0..) |pos, i| {
            const rotated = rotatePosition(pos, self.rotation);
            grid_cells[i] = GridCell{
                .position = .{
                    .x = rotated.x + self.position.x,
                    .y = rotated.y + self.position.y,
                },
                .color = color,
            };
        }

        return grid_cells;
    }

    pub fn rotateClockwise(self: *Tetromino) void {
        if (self.tetromino_type == .o) return;

        self.rotation = self.rotation.next();
    }

    pub fn rotateCounterclockwise(self: *Tetromino) void {
        if (self.tetromino_type == .o) return;

        self.rotation = self.rotation.previous();
    }
};
