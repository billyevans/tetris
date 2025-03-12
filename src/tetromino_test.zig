const tetromino = @import("tetromino");
const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const testing = std.testing;

const MockGrid = struct {
    allow_piece: bool,

    pub fn init(allow: bool) MockGrid {
        return MockGrid{
            .allow_piece = allow,
        };
    }

    pub fn hasSpaceForPiece(self: *const MockGrid, _: *const tetromino.Tetromino) bool {
        return self.allow_piece;
    }
};

test "WallKickData.getKickData returns correct data for different piece types" {
    // Test for I piece
    {
        const kick_data = tetromino.WallKickData.getKickData(.i, .up);
        try testing.expectEqual(@as(usize, 5), kick_data.len);
        try testing.expectEqual(tetromino.Position{ .x = 0, .y = 0 }, kick_data[0]);
        try testing.expectEqual(tetromino.Position{ .x = -2, .y = 0 }, kick_data[1]);
    }

    // Test for O piece
    {
        const kick_data = tetromino.WallKickData.getKickData(.o, .up);
        try testing.expectEqual(@as(usize, 1), kick_data.len);
        try testing.expectEqual(tetromino.Position{ .x = 0, .y = 0 }, kick_data[0]);
    }

    // Test for J, L, S, T, Z pieces
    {
        const kick_data = tetromino.WallKickData.getKickData(.t, .up);
        try testing.expectEqual(@as(usize, 5), kick_data.len);
        try testing.expectEqual(tetromino.Position{ .x = 0, .y = 0 }, kick_data[0]);
        try testing.expectEqual(tetromino.Position{ .x = -1, .y = 0 }, kick_data[1]);
    }
}

test "WallKickData.getKickData returns correct rotation-dependent offsets" {
    // Test rotation transitions for J, L, S, T, Z pieces
    {
        const up_to_right = tetromino.WallKickData.getKickData(.j, .up);
        const right_to_down = tetromino.WallKickData.getKickData(.j, .right);
        const down_to_left = tetromino.WallKickData.getKickData(.j, .down);
        const left_to_up = tetromino.WallKickData.getKickData(.j, .left);

        try testing.expect(!std.meta.eql(up_to_right, right_to_down));
        try testing.expect(!std.meta.eql(right_to_down, down_to_left));
        try testing.expect(!std.meta.eql(down_to_left, left_to_up));
    }

    // Test rotation transitions for I piece
    {
        const up_to_right = tetromino.WallKickData.getKickData(.i, .up);
        const right_to_down = tetromino.WallKickData.getKickData(.i, .right);

        try testing.expect(!std.meta.eql(up_to_right, right_to_down));
    }
}

test "tryRotate returns true for O piece without rotation" {
    var piece = tetromino.Tetromino.init(.o, .{ .x = 5, .y = 5 });
    var grid = MockGrid.init(true);

    const original_rotation = piece.rotation;
    const result = piece.tryRotate(true, &grid);

    try testing.expect(result);
    try testing.expectEqual(original_rotation, piece.rotation);
}

test "tryRotate succeeds with first offset when space is available" {
    var piece = tetromino.Tetromino.init(.t, .{ .x = 5, .y = 5 });
    var grid = MockGrid.init(true);

    const original_rotation = piece.rotation;
    const result = piece.tryRotate(true, &grid);

    try testing.expect(result);
    try testing.expectEqual(original_rotation.next(), piece.rotation);
}

test "tryRotate fails when no valid position is found" {
    var piece = tetromino.Tetromino.init(.t, .{ .x = 5, .y = 5 });
    var grid = MockGrid.init(false);

    const original_rotation = piece.rotation;
    const result = piece.tryRotate(true, &grid);

    try testing.expect(!result);
    try testing.expectEqual(original_rotation, piece.rotation);
}

test "tryRotate counterclockwise works correctly" {
    var piece = tetromino.Tetromino.init(.t, .{ .x = 5, .y = 5 });
    var grid = MockGrid.init(true);

    const original_rotation = piece.rotation;
    const result = piece.tryRotate(false, &grid);

    try testing.expect(result);
    try testing.expectEqual(original_rotation.previous(), piece.rotation);
}
