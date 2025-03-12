const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const tetromino = @import("tetromino");
const gs = @import("game_state");

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

const InputState = struct {
    move_delay: f32 = 0.10, // Delay between movements when key is held (in seconds)
    move_timer: f32 = 0.05, // Timer for movement delay

    // Reset timer
    pub fn resetTimer(self: *InputState) void {
        self.move_timer = self.move_delay;
    }

    // Update timer and check if we can move
    pub fn canMove(self: *InputState) bool {
        self.move_timer -= ray.GetFrameTime();
        if (self.move_timer <= 0) {
            self.resetTimer();
            return true;
        }
        return false;
    }
};

const GameInput = struct {
    horizontal: InputState,
    vertical: InputState,
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

const MovementResult = struct {
    piece: tetromino.Tetromino,
    moved: bool,
    dropped: bool,
    paused: bool,
};

pub fn handleInput(piece: *tetromino.Tetromino, grid: *gs.Grid, game_input: *GameInput) MovementResult {
    var temp_piece = piece.*;
    var moved = false;
    var dropped = false;
    var paused = false;

    // Handle initial key presses immediately
    if (ray.IsKeyPressed(ray.KEY_LEFT)) {
        temp_piece.position.x -= 1;
        game_input.horizontal.resetTimer();
        moved = true;
    } else if (ray.IsKeyPressed(ray.KEY_RIGHT)) {
        temp_piece.position.x += 1;
        game_input.horizontal.resetTimer();
        moved = true;
    }

    // Handle held keys with delay
    if (!moved and game_input.horizontal.canMove()) {
        if (ray.IsKeyDown(ray.KEY_LEFT)) {
            temp_piece.position.x -= 1;
            moved = true;
        } else if (ray.IsKeyDown(ray.KEY_RIGHT)) {
            temp_piece.position.x += 1;
            moved = true;
        }
    }

    // Rotation controls with wall kicks
    if (ray.IsKeyPressed(ray.KEY_UP) or ray.IsKeyPressed(ray.KEY_Z)) {
        var rotated_piece = piece.*;
        if (rotated_piece.tryRotate(true, grid)) {
            temp_piece = rotated_piece;
            moved = true;
        }
    }

    if (ray.IsKeyPressed(ray.KEY_LEFT_CONTROL)) {
        var rotated_piece = piece.*;
        if (rotated_piece.tryRotate(false, grid)) {
            temp_piece = rotated_piece;
            moved = true;
        }
    }

    // Quick drop with either continuous drop or instant drop
    if (ray.IsKeyPressed(ray.KEY_SPACE)) {
        dropped = true;
    } else if (ray.IsKeyDown(ray.KEY_DOWN) and game_input.vertical.canMove()) {
        temp_piece.position.y += 1;
        moved = true;
    }

    if (ray.IsKeyPressed(ray.KEY_F10)) {
        paused = true;
    }

    return .{
        .piece = temp_piece,
        .moved = moved,
        .dropped = dropped,
        .paused = paused,
    };
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

pub fn gameLoop(layout: *const Layout, grid: *gs.Grid, previewGrid: *gs.Grid, allocator: std.mem.Allocator) !void {
    var prng = std.Random.DefaultPrng.init(@intCast(std.time.timestamp()));
    const rand = prng.random();
    const spawn_pos = tetromino.Position{ .x = @divFloor(@as(i32, @intCast(grid.width)), 2), .y = 0 };
    const next_spawn_pos = tetromino.Position{ .x = @divFloor(@as(i32, @intCast(previewGrid.width)), 2), .y = 1 };
    var game_input = GameInput{
        .horizontal = .{ .move_delay = 0.10 },
        .vertical = .{ .move_delay = 0.05 },
    };
    var falling = gs.FallingState.init(0);
    var piece = tetromino.Tetromino.initRandom(rand, spawn_pos);
    var nextPiece = tetromino.Tetromino.initRandom(rand, next_spawn_pos);
    var game_over = false;
    var game_pause = false;
    var game_state = gs.GameState.init();
    ray.InitAudioDevice();
    defer ray.CloseAudioDevice();
    const sound = ray.LoadSound("/Users/alexeypervushin/src/zig/tetris/philip.ogg");
    const block_size: i32 = @intFromFloat(layout.block_size);
    var sound_checkbox = Checkbox.init(layout.getCheckboxBounds().x, layout.getCheckboxBounds().y, 20, 20, "Sound On");
    var sound_on = sound_checkbox.checked;

    while (!ray.WindowShouldClose()) {
        if (!game_over) {
            // handle input
            const result = handleInput(&piece, grid, &game_input);
            if (result.dropped) {
                piece = grid.findDropPosition(&result.piece);
                if (sound_on) {
                    ray.PlaySound(sound);
                }
            } else if (result.moved) {
                if (grid.hasSpaceForPiece(&result.piece)) {
                    const cells_moved = result.piece.position.y - piece.position.y;
                    piece = result.piece;

                    if (cells_moved > 0) {
                        game_state.addSoftDrop(@intCast(cells_moved));
                    }
                    if (sound_on) {
                        ray.PlaySound(sound);
                    }
                }
            } else if (result.paused) {
                game_pause = !game_pause;
            }

            // handle falling
            if (!game_pause and falling.update()) {
                var fall_piece = piece;
                fall_piece.position.y += 1;
                if (grid.hasSpaceForPiece(&fall_piece)) {
                    piece = fall_piece;
                } else {
                    grid.addPiece(&piece);
                    const removed = grid.removeCompletedLines();
                    game_state.clearLines(removed);
                    falling.setLevel(game_state.level);

                    piece = nextPiece;
                    piece.position = spawn_pos;
                    nextPiece = tetromino.Tetromino.initRandom(rand, next_spawn_pos);
                }
            }
        }

        sound_checkbox.update();
        sound_on = sound_checkbox.checked;

        // render part
        ray.BeginDrawing();
        defer ray.EndDrawing();

        if (game_pause) {
            ray.DrawText("Pause", @as(i32, @intCast(grid.width / 2)) * block_size, @as(i32, @intCast(grid.height / 2)) * block_size, block_size, ray.PINK);
            continue;
        }
        if (!grid.hasSpaceForPiece(&piece)) {
            ray.DrawText("Game Over!", @as(i32, @intCast(grid.width / 2)) * block_size, @as(i32, @intCast(grid.height / 2)) * block_size, block_size, ray.PINK);
            game_over = true;
            continue;
        }
        ray.ClearBackground(ray.WHITE);

        const grid_bounds = layout.getMainGridBounds();
        drawGrid(grid, grid_bounds, block_size);

        const ghost_piece = grid.findDropPosition(&piece);
        if (ghost_piece.position.y > piece.position.y) {
            drawGhostPiece(&ghost_piece, grid_bounds, block_size);
        }

        const preview_bounds = layout.getPreviewBounds();
        drawGrid(previewGrid, preview_bounds, block_size);

        drawPiece(&piece, grid_bounds, block_size);
        drawPiece(&nextPiece, preview_bounds, block_size);

        try drawText(&game_state, layout, block_size, allocator);

        sound_checkbox.draw();
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

    ray.InitWindow(layout.window_width, layout.window_height, "tetris");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);

    var previewGrid = try gs.Grid.init(
        allocator,
        layout.preview_size,
        layout.preview_size,
        ray.LIGHTGRAY,
    );
    defer previewGrid.deinit();
    try gameLoop(&layout, &grid, &previewGrid, allocator);
}
