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

const TetrisColors = struct {
    Cyan: ray.Color = .{ .r = 0, .g = 255, .b = 255, .a = 255 },
    Yellow: ray.Color = .{ .r = 255, .g = 255, .b = 0, .a = 255 },
    Purple: ray.Color = .{ .r = 128, .g = 0, .b = 128, .a = 255 },
    Green: ray.Color = .{ .r = 0, .g = 255, .b = 0, .a = 255 },
    Red: ray.Color = .{ .r = 255, .g = 0, .b = 0, .a = 255 },
    Blue: ray.Color = .{ .r = 0, .g = 0, .b = 255, .a = 255 },
    Orange: ray.Color = .{ .r = 255, .g = 165, .b = 0, .a = 255 },
}{};

const I_POSITIONS = [_]Position{
    .{ .x = -2, .y = 0 }, // ████
    .{ .x = -1, .y = 0 },
    .{ .x = 0, .y = 0 },
    .{ .x = 1, .y = 0 },
};

const O_POSITIONS = [_]Position{
    .{ .x = -1, .y = 0 }, // ██
    .{ .x = 0, .y = 0 }, //  ██
    .{ .x = -1, .y = 1 },
    .{ .x = 0, .y = 1 },
};

const T_POSITIONS = [_]Position{
    .{ .x = 0, .y = 1 }, //   █
    .{ .x = -1, .y = 0 }, // ███
    .{ .x = 0, .y = 0 },
    .{ .x = 1, .y = 0 },
};

const S_POSITIONS = [_]Position{
    .{ .x = 0, .y = 1 }, //   ██
    .{ .x = 1, .y = 1 }, // ██
    .{ .x = -1, .y = 0 },
    .{ .x = 0, .y = 0 },
};

const Z_POSITIONS = [_]Position{
    .{ .x = -1, .y = 1 }, // ██
    .{ .x = 0, .y = 1 }, //    ██
    .{ .x = 0, .y = 0 },
    .{ .x = 1, .y = 0 },
};

const J_POSITIONS = [_]Position{
    .{ .x = -1, .y = 1 }, // █
    .{ .x = -1, .y = 0 }, // ███
    .{ .x = 0, .y = 0 },
    .{ .x = 1, .y = 0 },
};

const L_POSITIONS = [_]Position{
    .{ .x = 1, .y = 1 },  //    █
    .{ .x = -1, .y = 0 }, // ███
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

    pub fn random(rand: std.Random) TetrominoType {
        return @enumFromInt(rand.intRangeAtMost(u3, 0, 6));
    }
};

pub const TETROMINO_SHAPES = [_]TetrominoShape{
    .{ .positions = &I_POSITIONS }, // I piece (flat)
    .{ .positions = &O_POSITIONS }, // O piece (2x2 square)
    .{ .positions = &T_POSITIONS }, // T piece (pointing up)
    .{ .positions = &S_POSITIONS }, // S piece (standard S)
    .{ .positions = &Z_POSITIONS }, // Z piece (standard Z)
    .{ .positions = &J_POSITIONS }, // J piece (pointing left)
    .{ .positions = &L_POSITIONS }, // L piece (pointing right)
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
        .i => TetrisColors.Cyan,
        .o => TetrisColors.Yellow,
        .t => TetrisColors.Purple,
        .s => TetrisColors.Green,
        .z => TetrisColors.Red,
        .j => TetrisColors.Blue,
        .l => TetrisColors.Orange,
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

    pub fn initRandom(rand: std.Random, position: Position) Tetromino {
        return init(TetrominoType.random(rand), position);
    }

    pub fn getGridCells(self: *const Tetromino) [4]GridCell {
        const shape = TETROMINO_SHAPES[@intFromEnum(self.tetromino_type)];
        const color = getTetrominoColor(self.tetromino_type);

        var grid_cells: [4]GridCell = undefined;

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

    pub fn tryRotate(self: *Tetromino, clockwise: bool, grid: anytype) bool {
        if (self.tetromino_type == .o) return true; // O piece doesn't rotate

        // Save original state to revert if rotation fails
        const original_rotation = self.rotation;
        const original_position = self.position;

        // Perform the rotation
        if (clockwise) {
            self.rotation = self.rotation.next();
        } else {
            self.rotation = self.rotation.previous();
        }

        // Get the kick data for this rotation transition
        const kick_data = WallKickData.getKickData(self.tetromino_type, original_rotation);

        // Try each offset in the kick data
        for (kick_data) |offset| {
            self.position.x += offset.x;
            self.position.y += offset.y;

            if (grid.hasSpaceForPiece(self)) {
                return true;
            }

            self.position = original_position;
        }

        self.rotation = original_rotation;
        return false;
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

// SRS (Super Rotation System) wall kick data
// Format: For each rotation state, list of relative offsets to try
pub const WallKickData = struct {
    pub const jlstz_kicks = [4][5]Position{
        // 0->1 (up->right)
        [_]Position{ .{ .x = 0, .y = 0 }, .{ .x = -1, .y = 0 }, .{ .x = -1, .y = 1 }, .{ .x = 0, .y = -2 }, .{ .x = -1, .y = -2 } },
        // 1->2 (right->down)
        [_]Position{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 1, .y = -1 }, .{ .x = 0, .y = 2 }, .{ .x = 1, .y = 2 } },
        // 2->3 (down->left)
        [_]Position{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = 1, .y = 1 }, .{ .x = 0, .y = -2 }, .{ .x = 1, .y = -2 } },
        // 3->0 (left->up)
        [_]Position{ .{ .x = 0, .y = 0 }, .{ .x = -1, .y = 0 }, .{ .x = -1, .y = -1 }, .{ .x = 0, .y = 2 }, .{ .x = -1, .y = 2 } },
    };

    pub const i_kicks = [4][5]Position{
        // 0->1 (up->right)
        [_]Position{ .{ .x = 0, .y = 0 }, .{ .x = -2, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = -2, .y = -1 }, .{ .x = 1, .y = 2 } },
        // 1->2 (right->down)
        [_]Position{ .{ .x = 0, .y = 0 }, .{ .x = -1, .y = 0 }, .{ .x = 2, .y = 0 }, .{ .x = -1, .y = 2 }, .{ .x = 2, .y = -1 } },
        // 2->3 (down->left)
        [_]Position{ .{ .x = 0, .y = 0 }, .{ .x = 2, .y = 0 }, .{ .x = -1, .y = 0 }, .{ .x = 2, .y = 1 }, .{ .x = -1, .y = -2 } },
        // 3->0 (left->up)
        [_]Position{ .{ .x = 0, .y = 0 }, .{ .x = 1, .y = 0 }, .{ .x = -2, .y = 0 }, .{ .x = 1, .y = -2 }, .{ .x = -2, .y = 1 } },
    };

    pub fn getKickData(tetromino_type: TetrominoType, from_rotation: Rotation) []const Position {
        const rotation_index = @intFromEnum(from_rotation);

        if (tetromino_type == .i) {
            return &i_kicks[rotation_index];
        } else if (tetromino_type == .o) {
            // O piece doesn't rotate, so just return the first offset (0,0)
            return i_kicks[0][0..1];
        } else {
            // J, L, S, T, Z pieces
            return &jlstz_kicks[rotation_index];
        }
    }
};
