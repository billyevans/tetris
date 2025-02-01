const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const tetromino = @import("tetromino");

const GameSettings = struct {
    square_size: usize,
    screen_width: usize,
    screen_height: usize,
    grid_width: usize,
    grid_height: usize,
    grid_color: ray.Color,
    level_increase_lines: usize,
};

const Score = struct {
    total: usize,
};

const InputState = struct {
    move_delay: f32 = 0.10,  // Delay between movements when key is held (in seconds)
    move_timer: f32 = 0.05,   // Timer for movement delay

    // Reset timer
    pub fn reset_timer(self: *InputState) void {
        self.move_timer = self.move_delay;
    }

    // Update timer and check if we can move
    pub fn can_move(self: *InputState) bool {
        self.move_timer -= ray.GetFrameTime();
        if (self.move_timer <= 0) {
            self.reset_timer();
            return true;
        }
        return false;
    }
};

pub fn areColorsEqual(a: ray.Color, b: ray.Color) bool {
    return a.r == b.r and
           a.g == b.g and
           a.b == b.b and
           a.a == b.a;
}

const Board = struct {
    width :i32,
    height: i32,
    unit_size: i32,
    border_width: i32,
    border_color: ray.Color,
    background_color: ray.Color,

    fn draw(self: *const Board, start: tetromino.Position) void {
        const height = self.height * self.unit_size;
        const width = self.width * self.unit_size;
        const start_x = start.x * self.unit_size;
        const start_y = start.y * self.unit_size;
        const border = self.border_width * self.unit_size;

        ray.DrawRectangle(start_x + border, start_y, width, height, self.background_color);
        // border
        ray.DrawRectangle(start_x, border, start_y, border + height, self.border_color);
        ray.DrawRectangle(start_x + border, start_y + height, width, border, self.border_color);
        ray.DrawRectangle(start_x + border + width, start_y, border, border + height, self.border_color);
    }
};

pub const Grid = struct {
    cells: [][]tetromino.GridCell,
    width: usize,
    height: usize,
    allocator: std.mem.Allocator,
    background_color: ray.Color,

    pub fn init(allocator: std.mem.Allocator, width: usize, height: usize, background_color: ray.Color) !Grid {
        // Allocate the rows
        var cells = try allocator.alloc([]tetromino.GridCell, height);
        errdefer allocator.free(cells);

        // Allocate each row
        for (cells, 0..) |*row, y| {
            row.* = try allocator.alloc(tetromino.GridCell, width);
            errdefer {
                // Free previously allocated rows if we fail
                for (cells[0..y]) |prev_row| {
                    allocator.free(prev_row);
                }
            }

            // Initialize each cell in the row
            for (row.*, 0..) |*cell, x| {
                cell.* = tetromino.GridCell{
                    .position = .{
                        .x = @intCast(x),
                        .y = @intCast(y),
                    },
                    .color = background_color,  // Default color
                };
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
    fn getCell(self: *Grid, x: i32, y: i32) ?*tetromino.GridCell {
        if (!self.isInBounds(x, y)) return null;
        return &self.cells[@intCast(y)][@intCast(x)];
    }

    fn isEmpty(self: *Grid, x: i32, y: i32) bool {
        if (self.getCell(x, y)) |cell| {
            return areColorsEqual(cell.color, self.background_color);
        }
        return false;
    }

    // Clear the grid (set all cells to default color)
    fn clear(self: *Grid) void {
        for (self.cells) |row| {
            for (row) |*cell| {
                cell.*.color = self.background_color;
            }
        }
    }

    pub fn addPiece(self: *Grid, piece: *const tetromino.Tetromino, allocator: std.mem.Allocator) !void {
        const cells = try piece.getGridCells(allocator);
        defer allocator.free(cells);

        for (cells) |cell| {
            if (self.getCell(cell.position.x, cell.position.y)) |gridCell| {
                gridCell.*.color = cell.color;
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

    fn hasSpaceForPiece(self: *Grid, piece: *const tetromino.Tetromino, allocator: std.mem.Allocator) !bool {
        const cells = try piece.getGridCells(allocator);
        defer allocator.free(cells);
        return self.hasSpace(cells);
    }

    fn isLineComplete(self: *Grid, y: usize) bool {
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
                self.cells[y][x].color = self.cells[y-1][x].color;
            }
            y -= 1;
        }

        // Clear the top line
        for (0..self.width) |x| {
            self.cells[0][x].color = self.background_color;
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

    pub fn findDropPosition(self: *Grid, piece: *const tetromino.Tetromino, allocator: std.mem.Allocator) !tetromino.Tetromino {
        var test_piece = piece.*;
        var last_valid = piece.*;

        while (try self.hasSpaceForPiece(&test_piece, allocator)) {
            last_valid = test_piece;
            test_piece.position.y += 1;
        }

        return last_valid;
    }
};

const MovementResult = struct {
    piece: tetromino.Tetromino,
    moved: bool,
    dropped: bool,
};

pub fn handleInput(piece: *tetromino.Tetromino, input_state: *InputState) MovementResult {
    var temp_piece = piece.*;
    var moved = false;
    var dropped = false;

    // Handle initial key presses immediately
    if (ray.IsKeyPressed(ray.KEY_LEFT)) {
        temp_piece.position.x -= 1;
        input_state.reset_timer();
        moved = true;
    } else if (ray.IsKeyPressed(ray.KEY_RIGHT)) {
        temp_piece.position.x += 1;
        input_state.reset_timer();
        moved = true;
    }

    // Handle held keys with delay
    if (!moved and input_state.can_move()) {
        if (ray.IsKeyDown(ray.KEY_LEFT)) {
            temp_piece.position.x -= 1;
            moved = true;
        } else if (ray.IsKeyDown(ray.KEY_RIGHT)) {
            temp_piece.position.x += 1;
            moved = true;
        }
    }

    // Rotation controls (usually don't need hold support)
    if (ray.IsKeyPressed(ray.KEY_UP) or ray.IsKeyPressed(ray.KEY_Z)) {
        temp_piece.rotateClockwise();
        moved = true;
    }

    if (ray.IsKeyPressed(ray.KEY_LEFT_CONTROL)) {
        temp_piece.rotateCounterclockwise();
        moved = true;
    }

    // Quick drop with either continuous drop or instant drop
    if (ray.IsKeyPressed(ray.KEY_SPACE)) {
        dropped = true;
    } else if (ray.IsKeyDown(ray.KEY_DOWN) and input_state.can_move()) {
        temp_piece.position.y += 1;
        moved = true;
    }

    return .{
        .piece = temp_piece,
        .moved = moved,
        .dropped = dropped,
    };
}

const GameSpeed = struct {
    // Classic NES speeds converted to seconds (frames / 60)
    const speeds = [30]f32{
        0.800,  // Level 0:  48 frames
        0.717,  // Level 1:  43 frames
        0.633,  // Level 2:  38 frames
        0.550,  // Level 3:  33 frames
        0.467,  // Level 4:  28 frames
        0.383,  // Level 5:  23 frames
        0.300,  // Level 6:  18 frames
        0.217,  // Level 7:  13 frames
        0.133,  // Level 8:   8 frames
        0.100,  // Level 9:   6 frames
        0.083,  // Level 10:  5 frames
        0.083,  // Level 11:  5 frames
        0.083,  // Level 12:  5 frames
        0.067,  // Level 13:  4 frames
        0.067,  // Level 14:  4 frames
        0.067,  // Level 15:  4 frames
        0.050,  // Level 16:  3 frames
        0.050,  // Level 17:  3 frames
        0.050,  // Level 18:  3 frames
        0.033,  // Level 19:  2 frames
        0.033,  // Level 20:  2 frames
        0.033,  // Level 21:  2 frames
        0.033,  // Level 22:  2 frames
        0.033,  // Level 23:  2 frames
        0.033,  // Level 24:  2 frames
        0.033,  // Level 25:  2 frames
        0.033,  // Level 26:  2 frames
        0.033,  // Level 27:  2 frames
        0.033,  // Level 28:  2 frames
        0.017,  // Level 29:  1 frame
    };

    pub fn get_fall_delay(level: usize) f32 {
        if (level >= speeds.len) {
            return speeds[speeds.len - 1];
        }
        return speeds[level];
    }
};

const FallingState = struct {
    fall_timer: f32,
    level: usize,

    pub fn init(initial_level: usize) FallingState {
        return .{
            .fall_timer = GameSpeed.get_fall_delay(initial_level),
            .level = initial_level,
        };
    }

    pub fn update(self: *FallingState) bool {
        self.fall_timer -= ray.GetFrameTime();
        if (self.fall_timer <= 0) {
            self.fall_timer = GameSpeed.get_fall_delay(self.level);
            return true;  // Time to fall
        }
        return false;
    }

    pub fn setLevel(self: *FallingState, new_level: usize) void {
        self.level = new_level;
        self.fall_timer = GameSpeed.get_fall_delay(self.level);
    }
};

pub fn gameLoop(settings: *const GameSettings, grid: *Grid, allocator: std.mem.Allocator) !void {
    var prng = std.rand.DefaultPrng.init(@intCast(std.time.timestamp()));
    var rand = prng.random();
    const tetromino_spawn_pos = tetromino.Position{ .x = @divFloor(@as(i32, @intCast(grid.width)), 2), .y = 0 };
    var input_state = InputState{};
    var falling = FallingState.init(0);
    var piece = tetromino.Tetromino.initRandom(&rand, tetromino_spawn_pos);
    var game_over = false;
    const square_size = @as(i32, @intCast(settings.square_size));
    var score = Score { .total = 0 };

    while (!ray.WindowShouldClose()) {
        if (!game_over) {
            // handle input
            const result = handleInput(&piece, &input_state);
            if (result.dropped) {
                piece = try grid.findDropPosition(&result.piece, allocator);
            } else if (result.moved) {
                if (try grid.hasSpaceForPiece(&result.piece, allocator)) {
                    piece = result.piece;
                }
            }

            // handle falling
            if (falling.update()) {
                var fall_piece = piece;
                fall_piece.position.y += 1;
                if (try grid.hasSpaceForPiece(&fall_piece, allocator)) {
                    piece = fall_piece;
                } else {
                    try grid.addPiece(&piece, allocator);
                    const removed = grid.removeCompletedLines();
                    score.total += removed;
                    falling.setLevel(score.total / settings.level_increase_lines);
                    piece = tetromino.Tetromino.initRandom(&rand, tetromino_spawn_pos);
                }
            }
        }

        // render part
        ray.BeginDrawing();
        defer ray.EndDrawing();
        const cells = try piece.getGridCells(allocator);
        defer allocator.free(cells);
        if (!grid.hasSpace(cells)) {
            // FIXME
            ray.DrawText("Game Over!", @intCast(grid.width/2 * settings.square_size), @intCast(grid.height/2 * settings.square_size), square_size, ray.PINK);
            game_over = true;
            continue;
        }
        ray.ClearBackground(ray.WHITE);
        // Draw grid
        ray.DrawRectangle(0, 0, @intCast(grid.width * settings.square_size), @intCast(grid.height * settings.square_size), ray.BLACK);
        for (grid.cells) |row| {
            for (row) |cell| {
                ray.DrawRectangle(
                    cell.position.x * square_size,
                    cell.position.y * square_size,
                    square_size - 1, // slightly smaller than scale for grid effect
                    square_size - 1,
                    cell.color,
                );
            }
        }


        // Draw current piece
        for (cells) |cell| {
            ray.DrawRectangle(
                cell.position.x * square_size,
                cell.position.y * square_size,
                square_size - 1,
                square_size - 1,
                tetromino.getTetrominoColor(piece.tetromino_type),
            );
        }
        const score_string = try std.fmt.allocPrintZ(
            allocator, "Score: {d}", .{ score.total },
        );
        defer allocator.free(score_string);
        ray.DrawText(score_string, @intCast((grid.width + 1) * settings.square_size), 0, square_size, ray.DARKGRAY);
        const level_string = try std.fmt.allocPrintZ(
            allocator, "Level: {d}", .{ falling.level },
        );
        defer allocator.free(level_string);
        ray.DrawText(level_string, @intCast((grid.width + 1) * settings.square_size), square_size, square_size, ray.DARKGRAY);
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer {
        std.debug.assert(gpa.deinit() == .ok);
    }
    const settings = GameSettings{
        .square_size = 50,
        .screen_width = 800,
        .screen_height = 1200,
        .grid_width = 10,
        .grid_height = 20,
        .grid_color = ray.SKYBLUE,
        .level_increase_lines = 10,
    };

    ray.InitWindow(settings.screen_width, settings.screen_height, "tetris");
    defer ray.CloseWindow();
    ray.SetTargetFPS(60);

    var grid = try Grid.init(allocator, settings.grid_width, settings.grid_height, settings.grid_color);
    defer grid.deinit();

    try gameLoop(&settings, &grid, allocator);
}
