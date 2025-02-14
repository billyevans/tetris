const gs = @import("game_state");
const tetromino = @import("tetromino");
const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const testing = std.testing;

test "initial state" {
    const game = gs.GameState.init();
    try testing.expectEqual(@as(u32, 0), game.score);
    try testing.expectEqual(@as(u32, 0), game.level);
    try testing.expectEqual(@as(u32, 0), game.lines_cleared);
}

test "level progression" {
    var game = gs.GameState.init();

    // Clear 9 lines (should still be level 0)
    var i: u32 = 0;
    while (i < 9) : (i += 1) {
        game.clearLines(1);
    }
    try testing.expectEqual(0, game.level);

    // Clear one more line to reach level 1
    game.clearLines(1);
    try testing.expectEqual(1, game.level);
}

test "scoring calculation" {
    var game = gs.GameState.init();

    // Single line at level 0
    game.clearLines(1);
    try testing.expectEqual(40, game.score);

    // Double line at level 0
    game.clearLines(2);
    try testing.expectEqual(140, game.score); // 40 + 100

    // Clear enough lines to reach level 1
    var i: u32 = 0;
    while (i < 6) : (i += 1) {
        game.clearLines(1);
    }
    try testing.expectEqual(380, game.score); // 140 + (6 * 40)

    // Clear 1 line to reach level 1 (10th line)
    game.clearLines(1);
    try testing.expectEqual(460, game.score); // 380 + (40 * 2) because now level 1

    // Tetris at level 1
    game.clearLines(4);
    try testing.expectEqual(2860, game.score);
    // 420 (previous) + (1200 * 2) level multiplier
}

test "soft drop points" {
    var game = gs.GameState.init();

    game.addSoftDrop(5);
    try testing.expectEqual(@as(u32, 5), game.score);

    game.addSoftDrop(3);
    try testing.expectEqual(@as(u32, 8), game.score);
}

test "invalid line clears" {
    var game = gs.GameState.init();

    // Clearing 0 lines should not affect score
    game.clearLines(0);
    try testing.expectEqual(@as(u32, 0), game.score);

    // Clearing more than 4 lines should not affect score
    game.clearLines(5);
    try testing.expectEqual(@as(u32, 0), game.score);
}

test "Rotation enum operations" {
    try testing.expectEqual(tetromino.Rotation.right, tetromino.Rotation.up.next());
    try testing.expectEqual(tetromino.Rotation.down, tetromino.Rotation.right.next());
    try testing.expectEqual(tetromino.Rotation.left, tetromino.Rotation.down.next());
    try testing.expectEqual(tetromino.Rotation.up, tetromino.Rotation.left.next());

    // Test rotation previous
    try testing.expectEqual(tetromino.Rotation.left, tetromino.Rotation.up.previous());
    try testing.expectEqual(tetromino.Rotation.up, tetromino.Rotation.right.previous());
    try testing.expectEqual(tetromino.Rotation.right, tetromino.Rotation.down.previous());
    try testing.expectEqual(tetromino.Rotation.down, tetromino.Rotation.left.previous());
}

test "TetrominoType random generation" {
    var prng = std.rand.DefaultPrng.init(42);
    const rand = prng.random();

    // Test multiple random generations to ensure all types can be generated
    var type_counts = [_]usize{0} ** 7;
    const iterations = 1000;

    for (0..iterations) |_| {
        const tetromino_type = tetromino.TetrominoType.random(rand);
        type_counts[@intFromEnum(tetromino_type)] += 1;
    }

    // Verify each type was generated at least once
    for (type_counts) |count| {
        try testing.expect(count > 0);
    }
}

test "Position rotation calculations" {
    const test_pos = tetromino.Position{ .x = 1, .y = 0 };

    // Test all rotations of a single position
    try testing.expectEqual(tetromino.Position{ .x = 1, .y = 0 }, tetromino.rotatePosition(test_pos, .up));
    try testing.expectEqual(tetromino.Position{ .x = 0, .y = 1 }, tetromino.rotatePosition(test_pos, .right));
    try testing.expectEqual(tetromino.Position{ .x = -1, .y = 0 }, tetromino.rotatePosition(test_pos, .down));
    try testing.expectEqual(tetromino.Position{ .x = 0, .y = -1 }, tetromino.rotatePosition(test_pos, .left));
}

test "Tetromino initialization and rotation" {
    // Test I piece initialization
    var piece = tetromino.Tetromino.init(.i, .{ .x = 5, .y = 5 });
    try testing.expectEqual(tetromino.TetrominoType.i, piece.tetromino_type);
    try testing.expectEqual(tetromino.Position{ .x = 5, .y = 5 }, piece.position);
    try testing.expectEqual(tetromino.Rotation.up, piece.rotation);

    // Test piece rotation
    piece.rotateClockwise();
    try testing.expectEqual(tetromino.Rotation.right, piece.rotation);

    piece.rotateCounterclockwise();
    try testing.expectEqual(tetromino.Rotation.up, piece.rotation);

    // Test O piece rotation (should not rotate)
    var o_piece = tetromino.Tetromino.init(.o, .{ .x = 5, .y = 5 });
    o_piece.rotateClockwise();
    try testing.expectEqual(tetromino.Rotation.up, o_piece.rotation);
}

test "Grid initialization and basic operations" {
    const allocator = testing.allocator;
    const bg_color = ray.Color{ .r = 0, .g = 0, .b = 0, .a = 255 };

    var grid = try gs.Grid.init(allocator, 10, 20, bg_color);
    defer grid.deinit();

    // Test grid dimensions
    try testing.expectEqual(@as(usize, 10), grid.width);
    try testing.expectEqual(@as(usize, 20), grid.height);

    // Test initial grid state
    for (0..grid.height) |y| {
        for (0..grid.width) |x| {
            try testing.expect(grid.isEmpty(@intCast(x), @intCast(y)));
        }
    }
}

test "Line clearing mechanics" {
    const allocator = testing.allocator;
    const bg_color = ray.Color{ .r = 0, .g = 0, .b = 0, .a = 255 };
    const fill_color = ray.Color{ .r = 255, .g = 255, .b = 255, .a = 255 };

    var grid = try gs.Grid.init(allocator, 4, 4, bg_color);
    defer grid.deinit();

    // Fill bottom row
    for (0..grid.width) |x| {
        grid.cells[3][x] = fill_color;
    }

    // Test line completion detection
    try testing.expect(grid.isLineComplete(3));
    try testing.expect(!grid.isLineComplete(2));

    // Test line clearing
    const lines_cleared = grid.removeCompletedLines();
    try testing.expectEqual(@as(usize, 1), lines_cleared);

    // Verify bottom row is now empty
    for (0..grid.width) |x| {
        try testing.expect(grid.isEmpty(@intCast(x), 3));
    }
}

test "Piece dropping mechanics" {
    const allocator = testing.allocator;
    const bg_color = ray.Color{ .r = 0, .g = 0, .b = 0, .a = 255 };

    var grid = try gs.Grid.init(allocator, 10, 20, bg_color);
    defer grid.deinit();

    var piece = tetromino.Tetromino.init(.i, .{ .x = 5, .y = 0 });
    const drop_position = grid.findDropPosition(&piece);

    // The piece should drop to the bottom
    try testing.expectEqual(@as(i32, 5), drop_position.position.x);
    try testing.expect(drop_position.position.y > 0);
}

test "Color equality" {
    const color1 = ray.Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
    const color2 = ray.Color{ .r = 255, .g = 0, .b = 0, .a = 255 };
    const color3 = ray.Color{ .r = 0, .g = 255, .b = 0, .a = 255 };

    try testing.expect(gs.areColorsEqual(&color1, &color2));
    try testing.expect(!gs.areColorsEqual(&color1, &color3));
}

test "Grid piece collision detection" {
    const allocator = testing.allocator;
    const bg_color = ray.Color{ .r = 0, .g = 0, .b = 0, .a = 255 };

    var grid = try gs.Grid.init(allocator, 10, 20, bg_color);
    defer grid.deinit();

    // Test piece at valid position
    var piece = tetromino.Tetromino.init(.i, .{ .x = 5, .y = 0 });
    try testing.expect(grid.hasSpaceForPiece(&piece));

    // Test piece collision at bottom
    piece.position.y = 20; // Bottom edge
    try testing.expect(grid.hasSpaceForPiece(&piece) == false);

    // Test piece collision at walls
    piece.position = .{ .x = -1, .y = 5 }; // Left wall
    try testing.expect(grid.hasSpaceForPiece(&piece) == false);

    piece.position = .{ .x = 9, .y = 5 }; // Right wall
    try testing.expect(grid.hasSpaceForPiece(&piece) == false);
}
