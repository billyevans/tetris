const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const gm = @import("game_manager");
const gs = @import("game_state");
const tetromino = @import("tetromino");
const testing = std.testing;

pub fn createTestableGameManager(allocator: std.mem.Allocator) !struct {
    game: gm.GameManager,
    main_grid: *gs.Grid,
    preview_grid: *gs.Grid,
} {
    const bg_color = ray.Color{ .r = 0, .g = 0, .b = 0, .a = 255 };

    const main_grid = try allocator.create(gs.Grid);
    errdefer allocator.destroy(main_grid);

    main_grid.* = try gs.Grid.init(allocator, 10, 20, bg_color);

    const preview_grid = try allocator.create(gs.Grid);
    errdefer allocator.destroy(preview_grid);
    preview_grid.* = try gs.Grid.init(allocator, 4, 4, bg_color);

    const game = gm.GameManager.init(main_grid, preview_grid, 42, null, null);

    return .{
        .game = game,
        .main_grid = main_grid,
        .preview_grid = preview_grid,
    };
}

test "Test createTestableGameManager" {
    const allocator = testing.allocator;
    var test_env = try createTestableGameManager(allocator);

    defer {
        test_env.game.deinit();
        test_env.main_grid.deinit();
        allocator.destroy(test_env.main_grid);
        test_env.preview_grid.deinit();
        allocator.destroy(test_env.preview_grid);
    }

    try testing.expect(test_env.game.status == .playing);
}

test "GameManager initialization using helper" {
    const allocator = testing.allocator;

    var test_env = try createTestableGameManager(allocator);
    defer {
        test_env.game.deinit();
        test_env.main_grid.deinit();
        allocator.destroy(test_env.main_grid);
        test_env.preview_grid.deinit();
        allocator.destroy(test_env.preview_grid);
    }

    try testing.expect(test_env.game.status == .playing);
    try testing.expectEqual(@as(usize, 0), test_env.game.game_state.score);
    try testing.expectEqual(@as(usize, 0), test_env.game.game_state.level);
}

test "Piece movement using helper" {
    const allocator = testing.allocator;

    var test_env = try createTestableGameManager(allocator);
    defer {
        test_env.game.deinit();
        test_env.main_grid.deinit();
        allocator.destroy(test_env.main_grid);
        test_env.preview_grid.deinit();
        allocator.destroy(test_env.preview_grid);
    }

    const initial_x = test_env.game.current_piece.position.x;

    _ = test_env.game.processInput(.move_right);
    try testing.expectEqual(initial_x + 1, test_env.game.current_piece.position.x);

    // Move left (back to initial)
    _ = test_env.game.processInput(.move_left);
    try testing.expectEqual(initial_x, test_env.game.current_piece.position.x);

    // Move left again
    _ = test_env.game.processInput(.move_left);
    try testing.expectEqual(initial_x - 1, test_env.game.current_piece.position.x);
}

test "Piece rotation using helper" {
    const allocator = testing.allocator;

    var test_env = try createTestableGameManager(allocator);
    defer {
        test_env.game.deinit();
        test_env.main_grid.deinit();
        allocator.destroy(test_env.main_grid);
        test_env.preview_grid.deinit();
        allocator.destroy(test_env.preview_grid);
    }

    // Ensure we're not testing with the O piece (which doesn't rotate)
    if (test_env.game.current_piece.tetromino_type == .o) {
        test_env.game.current_piece.tetromino_type = .t;
    }

    // Save initial rotation
    const initial_rotation = test_env.game.current_piece.rotation;

    // Rotate clockwise
    _ = test_env.game.processInput(.rotate_clockwise);
    try testing.expectEqual(initial_rotation.next(), test_env.game.current_piece.rotation);

    // Rotate counterclockwise (back to initial)
    _ = test_env.game.processInput(.rotate_counterclockwise);
    try testing.expectEqual(initial_rotation, test_env.game.current_piece.rotation);
}

test "Game state transitions using helper" {
    const allocator = testing.allocator;

    var test_env = try createTestableGameManager(allocator);
    defer {
        test_env.game.deinit();
        test_env.main_grid.deinit();
        allocator.destroy(test_env.main_grid);
        test_env.preview_grid.deinit();
        allocator.destroy(test_env.preview_grid);
    }

    try testing.expectEqual(gm.GameStatus.playing, test_env.game.status);

    // Toggle pause
    _ = test_env.game.processInput(.toggle_pause);
    try testing.expectEqual(gm.GameStatus.paused, test_env.game.status);

    // Toggle pause again (back to playing)
    _ = test_env.game.processInput(.toggle_pause);
    try testing.expectEqual(gm.GameStatus.playing, test_env.game.status);

    // Force game over
    test_env.game.status = .game_over;

    // Restart
    _ = test_env.game.processInput(.restart);
    try testing.expectEqual(gm.GameStatus.playing, test_env.game.status);
}

test "Sound enabling/disabling using helper" {
    const allocator = testing.allocator;

    var test_env = try createTestableGameManager(allocator);
    defer {
        test_env.game.deinit();
        test_env.main_grid.deinit();
        allocator.destroy(test_env.main_grid);
        test_env.preview_grid.deinit();
        allocator.destroy(test_env.preview_grid);
    }

    // Off for tests
    try testing.expect(!test_env.game.sound_manager.enabled);

     // Disable sound
    test_env.game.setSoundEnabled(false);
    try testing.expect(!test_env.game.sound_manager.enabled);

    // Enable sound again
    test_env.game.setSoundEnabled(true);
    try testing.expect(test_env.game.sound_manager.enabled);
}
