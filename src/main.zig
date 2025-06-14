const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const tetromino = @import("tetromino");
const gs = @import("game_state");
const gm = @import("game_manager");
const rm = @import("records_manager");

const Layout = struct {
    window_width: f32,
    window_height: f32,
    margin: f32,
    block_size: f32,
    grid_width: f32,
    grid_height: f32,
    preview_size: f32,

    // Get tetris main grid position and size
    pub fn getMainGridBounds(self: *const Layout) ray.Rectangle {
        return ray.Rectangle{
            .x = self.margin,
            .y = self.margin,
            .width = self.block_size * self.grid_width,
            .height = self.block_size * self.grid_height,
        };
    }

    // Get sidebar position (right side of main grid)
    pub fn getSidebarX(self: *const Layout) f32 {
        const grid = self.getMainGridBounds();
        return grid.x + grid.width + self.margin;
    }

    pub fn getPreviewBounds(self: *const Layout) ray.Rectangle {
        const sidebar_x = self.getSidebarX();
        const preview_size = self.block_size * self.preview_size;
        return ray.Rectangle{
            .x = sidebar_x,
            .y = self.margin + 150, // Place below score/level text
            .width = preview_size,
            .height = preview_size,
        };
    }

    pub fn getCheckboxBounds(self: *const Layout) ray.Rectangle {
        const preview = self.getPreviewBounds();
        return ray.Rectangle{
            .x = preview.x,
            .y = preview.y + preview.height + self.margin,
            .width = 20,
            .height = 20,
        };
    }

    // Get score text position
    pub fn getScorePosition(self: *const Layout) ray.Vector2 {
        return ray.Vector2{
            .x = self.getSidebarX(),
            .y = self.margin,
        };
    }

    // Get level text position
    pub fn getLevelPosition(self: *const Layout) ray.Vector2 {
        return ray.Vector2{
            .x = self.getSidebarX(),
            .y = self.margin + 50,
        };
    }

    // Get lines text position
    pub fn getLinesPosition(self: *const Layout) ray.Vector2 {
        return ray.Vector2{
            .x = self.getSidebarX(),
            .y = self.margin + 100,
        };
    }
};

const Checkbox = struct {
    bounds: ray.Rectangle,
    checked: bool,
    text: [:0]const u8,

    pub fn init(x: f32, y: f32, width: f32, height: f32, text: [:0]const u8) Checkbox {
        return Checkbox{
            .bounds = ray.Rectangle{
                .x = x,
                .y = y,
                .width = width,
                .height = height,
            },
            .checked = true, // Start with sound on
            .text = text,
        };
    }

    pub fn draw(self: *Checkbox) void {
        // Draw the checkbox outline
        ray.DrawRectangleLinesEx(self.bounds, 2, ray.BLACK);

        // Draw the filled part if checked
        if (self.checked) {
            const inner_bounds = ray.Rectangle{
                .x = self.bounds.x + 4,
                .y = self.bounds.y + 4,
                .width = self.bounds.width - 8,
                .height = self.bounds.height - 8,
            };
            ray.DrawRectangleRec(inner_bounds, ray.BLACK);
        }

        // Draw the text label
        ray.DrawText(
            self.text.ptr,
            @intFromFloat(self.bounds.x + self.bounds.width + 10),
            @intFromFloat(self.bounds.y + 5),
            20,
            ray.BLACK,
        );
    }

    pub fn update(self: *Checkbox) void {
        if (ray.IsMouseButtonPressed(ray.MOUSE_BUTTON_LEFT)) {
            const mouse_point = ray.GetMousePosition();
            if (ray.CheckCollisionPointRec(mouse_point, self.bounds)) {
                self.checked = !self.checked;
            }
        }
    }
};

pub fn handleInput(game: *gm.GameManager) void {
    // First handle key presses
    if (ray.IsKeyPressed(ray.KEY_LEFT)) {
        _ = game.processInput(.move_left);
    } else if (ray.IsKeyPressed(ray.KEY_RIGHT)) {
        _ = game.processInput(.move_right);
    }

    // Handle held keys with delay
    if (game.canMovePiece(.horizontal)) {
        if (ray.IsKeyDown(ray.KEY_LEFT)) {
            _ = game.processInput(.move_left);
        } else if (ray.IsKeyDown(ray.KEY_RIGHT)) {
            _ = game.processInput(.move_right);
        }
    }

    // Rotation controls
    if (ray.IsKeyPressed(ray.KEY_UP) or ray.IsKeyPressed(ray.KEY_Z)) {
        _ = game.processInput(.rotate_clockwise);
    }

    if (ray.IsKeyPressed(ray.KEY_LEFT_CONTROL)) {
        _ = game.processInput(.rotate_counterclockwise);
    }

    // Quick drop
    if (ray.IsKeyPressed(ray.KEY_SPACE)) {
        _ = game.processInput(.hard_drop);
    } else if (ray.IsKeyDown(ray.KEY_DOWN) and game.canMovePiece(.vertical)) {
        _ = game.processInput(.soft_drop);
    }

    // Game control
    if (ray.IsKeyPressed(ray.KEY_F10)) {
        _ = game.processInput(.toggle_pause);
    }

    if (ray.IsKeyPressed(ray.KEY_ENTER)) {
        _ = game.processInput(.restart);
    }

    if (ray.IsKeyPressed(ray.KEY_H)) {
        _ = game.processInput(.toggle_records);
    }
}

pub fn drawText(game_state: *const gs.GameState, layout: *const Layout, text_size: i32, allocator: std.mem.Allocator) !void {
    {
        const score_pos = layout.getScorePosition();
        const score_string = try std.fmt.allocPrintZ(
            allocator,
            "Score: {d}",
            .{game_state.score},
        );
        defer allocator.free(score_string);
        ray.DrawText(score_string, @intFromFloat(score_pos.x), @intFromFloat(score_pos.y), text_size, ray.DARKGRAY);
    }

    {
        const lines_pos = layout.getLinesPosition();
        const lines_string = try std.fmt.allocPrintZ(
            allocator,
            "Lines: {d}",
            .{game_state.lines_cleared},
        );
        defer allocator.free(lines_string);
        ray.DrawText(lines_string, @intFromFloat(lines_pos.x), @intFromFloat(lines_pos.y), text_size, ray.DARKGRAY);
    }

    {
        const level_pos = layout.getLevelPosition();
        const level_string = try std.fmt.allocPrintZ(
            allocator,
            "Level: {d}",
            .{game_state.level},
        );
        defer allocator.free(level_string);
        ray.DrawText(level_string, @intFromFloat(level_pos.x), @intFromFloat(level_pos.y), text_size, ray.DARKGRAY);
    }
}

pub fn drawCell(origin_x: i32, origin_y: i32, x: i32, y: i32, block_size: i32, color: ray.Color) void {
    ray.DrawRectangle(
        origin_x + (x * block_size),
        origin_y + (y * block_size),
        block_size - 1,
        block_size - 1,
        color,
    );
}

pub fn drawPiece(piece: *const tetromino.Tetromino, grid_bounds: ray.Rectangle, block_size: i32) void {
    const cells = piece.getGridCells();
    for (cells) |cell| {
        drawCell(@intFromFloat(grid_bounds.x), @intFromFloat(grid_bounds.y), cell.position.x, cell.position.y, block_size, cell.color);
    }
}

pub fn drawGhostPiece(piece: *const tetromino.Tetromino, grid_bounds: ray.Rectangle, block_size: i32) void {
    const cells = piece.getGridCells();

    for (cells) |cell| {
        const x = @as(i32, @intFromFloat(grid_bounds.x)) + (cell.position.x * block_size);
        const y = @as(i32, @intFromFloat(grid_bounds.y)) + (cell.position.y * block_size);

        // Draw a distinctive pattern for ghost pieces - a dotted/dashed outline
        const dash_size: i32 = 4;
        var i: i32 = 0;
        while (i < block_size - 1) : (i += dash_size * 2) {
            // Draw dashes on all four sides of the block
            ray.DrawRectangle(x + i, y, dash_size, 1, ray.WHITE);
            ray.DrawRectangle(x + i, y + block_size - 2, dash_size, 1, ray.WHITE);
            ray.DrawRectangle(x, y + i, 1, dash_size, ray.WHITE);
            ray.DrawRectangle(x + block_size - 2, y + i, 1, dash_size, ray.WHITE);
        }
    }
}

pub fn drawGrid(grid: *const gs.Grid, grid_bounds: ray.Rectangle, block_size: i32) void {
    ray.DrawRectangleLinesEx(grid_bounds, 2, ray.BLACK);
    ray.DrawRectangleRec(grid_bounds, ray.BLACK);
    for (0.., grid.cells) |y, row| {
        for (0.., row) |x, cell| {
            drawCell(@intFromFloat(grid_bounds.x), @intFromFloat(grid_bounds.y), @intCast(x), @intCast(y), block_size, cell);
        }
    }
}

pub fn gameLoop(layout: *const Layout, grid: *gs.Grid, preview_grid: *gs.Grid, sound_files: gm.SoundFiles, allocator: std.mem.Allocator) !void {
    var records_manager = try rm.RecordsManager.init(allocator, "tetris_records.dat", "Player");
    defer records_manager.deinit();

    var game = gm.GameManager.init(grid, preview_grid, @intCast(std.time.timestamp()), sound_files, &records_manager);
    defer game.deinit(); // Make sure to clean up sounds

    // Other UI elements
    const block_size: i32 = @intFromFloat(layout.block_size);
    var sound_checkbox = Checkbox.init(layout.getCheckboxBounds().x, layout.getCheckboxBounds().y, 20, 20, "Sound On");

    var name_buffer: [16:0]u8 = [_:0]u8{0} ** 16;
    @memcpy(name_buffer[0..@min(records_manager.default_name.len, 15)], records_manager.default_name[0..@min(records_manager.default_name.len, 15)]);
    var name_length: usize = records_manager.default_name.len;

    while (!ray.WindowShouldClose()) {
        game.update();

        if (game.status != .high_score) {
            handleInput(&game);
        } else {
            // Handle high score name input
            const key = ray.GetCharPressed();
            if (key > 0 and name_length < 15 and
                ((key >= 'a' and key <= 'z') or
                    (key >= 'A' and key <= 'Z') or
                    (key >= '0' and key <= '9') or
                    key == '_' or key == '-' or key == ' ')) {

                        name_buffer[name_length] = @truncate(@as(usize, @intCast(key)));
                        name_length += 1;
                        name_buffer[name_length] = 0; // Null terminate
                    }

            if (ray.IsKeyPressed(ray.KEY_BACKSPACE) and name_length > 0) {
                name_length -= 1;
                name_buffer[name_length] = 0;
            }

            if (ray.IsKeyPressed(ray.KEY_ENTER) and name_length > 0) {
                try game.submitHighScore(name_buffer[0..name_length]);

                // Reset name for next time
                name_length = records_manager.default_name.len;
                @memcpy(name_buffer[0..@min(records_manager.default_name.len, 15)], records_manager.default_name[0..@min(records_manager.default_name.len, 15)]);
            }
        }

        game.updateGhostPiece();

        // Update UI
        sound_checkbox.update();
        game.setSoundEnabled(sound_checkbox.checked);

        // Render part
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.WHITE);

        const grid_bounds = layout.getMainGridBounds();
        drawGrid(grid, grid_bounds, block_size);

        // Draw game state based on status
        if (game.status == .paused) {
            ray.DrawText("Pause", @as(i32, @intCast(grid.width / 2)) * block_size, @as(i32, @intCast(grid.height / 2)) * block_size, block_size, ray.PINK);
        } else if (game.status == .game_over) {
            ray.DrawText("Game Over!", @intFromFloat(grid_bounds.x + grid_bounds.width / 2 - 120),
                @intFromFloat(grid_bounds.y + grid_bounds.height / 2 - 40), 40, ray.PINK);
            ray.DrawText("Press Enter to restart", @intFromFloat(grid_bounds.x + grid_bounds.width / 2 - 150),
                @intFromFloat(grid_bounds.y + grid_bounds.height / 2 + 20), 24, ray.PINK);
            ray.DrawText("Press H to view high scores", @intFromFloat(grid_bounds.x + grid_bounds.width / 2 - 150),
                @intFromFloat(grid_bounds.y + grid_bounds.height / 2 + 50), 24, ray.PINK);
        } else if (game.status == .high_score) {
            const highscore_panel = ray.Rectangle{
                .x = grid_bounds.x + 20,
                .y = grid_bounds.y + grid_bounds.height / 4 - 80,
                .width = grid_bounds.width - 40,
                .height = 240,
            };
            ray.DrawRectangleRec(highscore_panel, ray.ColorAlpha(ray.BLACK, 0.8));

            ray.DrawText("NEW HIGH SCORE!", @intFromFloat(grid_bounds.x + grid_bounds.width / 2 - 150),
                @intFromFloat(grid_bounds.y + grid_bounds.height / 4 - 60), 34, ray.GOLD);
            ray.DrawText("Enter your name:", @intFromFloat(grid_bounds.x + grid_bounds.width / 2 - 100),
                @intFromFloat(grid_bounds.y + grid_bounds.height / 4), 24, ray.WHITE);

            const name_panel = ray.Rectangle{
                .x = grid_bounds.x + grid_bounds.width / 2 - 150,
                .y = grid_bounds.y + grid_bounds.height / 4 + 40,
                .width = 300,
                .height = 40,
            };

            ray.DrawRectangleRec(name_panel, ray.LIGHTGRAY);
            ray.DrawRectangleLinesEx(name_panel, 2, ray.GRAY);
            ray.DrawText(&name_buffer, @intFromFloat(name_panel.x + 10),
                @intFromFloat(name_panel.y + 10), 24, ray.BLACK);

            ray.DrawText("Press Enter to confirm", @intFromFloat(grid_bounds.x + grid_bounds.width / 2 - 140),
                @intFromFloat(grid_bounds.y + grid_bounds.height / 4 + 100), 24, ray.WHITE);
            ray.DrawText("Game Over!", @as(i32, @intCast(grid.width / 2)) * block_size, @as(i32, @intCast(grid.height / 2)) * block_size, block_size, ray.PINK);
        } else {
            // Only render game when playing
            if (game.ghost_piece) |ghost| {
                if (ghost.position.y > game.current_piece.position.y) {
                    drawGhostPiece(&ghost, grid_bounds, block_size);
                }
            }

            drawPiece(&game.current_piece, grid_bounds, block_size);
        }

        // Always draw these UI elements
        const preview_bounds = layout.getPreviewBounds();
        drawGrid(preview_grid, preview_bounds, block_size);
        drawPiece(&game.next_piece, preview_bounds, block_size);

        try drawText(&game.game_state, layout, block_size, allocator);

        sound_checkbox.draw();
        // If records should be displayed
        if (records_manager.show_records) {
            const records_bounds = ray.Rectangle{
                .x = layout.window_width * 0.1,
                .y = layout.window_height * 0.1,
                .width = layout.window_width * 0.8,
                .height = layout.window_height * 0.8,
            };

            try records_manager.drawRecords(
                records_bounds.x,
                records_bounds.y,
                records_bounds.width,
                records_bounds.height,
                40, 20
            );
        }
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        std.debug.assert(gpa.deinit() == .ok);
    }

    const layout = Layout{
        .window_width = 800,
        .window_height = 1200,
        .margin = 20,
        .block_size = 40,
        .grid_width = 10,
        .grid_height = 20,
        .preview_size = 4,
    };

    var grid = try gs.Grid.init(
        allocator,
        layout.grid_width,
        layout.grid_height,
        ray.SKYBLUE,
    );
    defer grid.deinit();

    ray.InitWindow(layout.window_width, layout.window_height, "Tetris");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);

    var preview_grid = try gs.Grid.init(
        allocator,
        layout.preview_size,
        layout.preview_size,
        ray.LIGHTGRAY,
    );
    defer preview_grid.deinit();

    ray.InitAudioDevice();
    defer ray.CloseAudioDevice();

    const sound_files = gm.SoundFiles{
        .drop = "philip.ogg",
        .move = "philip.ogg",
        .rotate = "philip.ogg",
        .line_clear = "philip.ogg",
        .level_up = "philip.ogg",
    };

    try gameLoop(&layout, &grid, &preview_grid, sound_files, allocator);
}
