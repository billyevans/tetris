const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const tetromino = @import("tetromino");

const squareSize = 50;

const InputState = struct {
    move_delay: f32 = 0.10,  // Delay between movements when key is held (in seconds)
    move_timer: f32 = 0.15,   // Timer for movement delay

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

pub fn are_colors_equal(a: ray.Color, b: ray.Color) bool {
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
            return are_colors_equal(cell.color, self.background_color);
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

    fn readyToStop(self: *Grid, cells: []const tetromino.GridCell) bool {
        for (cells) |cell| {
            if (!self.isInBounds(cell.position.x, cell.position.y + 1)) {
                return true;
            }
            if (!self.isEmpty(cell.position.x, cell.position.y + 1)) {
                return true;
            }
        }
        return false;
    }

    fn draw(self: *Grid, start: tetromino.Position) void {
        for (self.cells) |row| {
            drawCells(start, row);
        }
    }

    fn append(self: *Grid, cells: []const tetromino.GridCell) void {
        for (cells) |cell| {
            if (self.getCell(cell.position.x, cell.position.y + 1)) |gridCell| {
                gridCell.*.color = cell.color;
            } else {
                continue;
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

    //fn removeLines(self: *Grid) void {
//
    //}
};

fn drawCells(start: tetromino.Position, cells: []const tetromino.GridCell) void {
    for (cells) |cell| {
        ray.DrawRectangle((start.x + cell.position.x) * squareSize, (start.y + cell.position.y) * squareSize, squareSize, squareSize, cell.color);
    }
}

const MovementResult = struct {
    piece: tetromino.Tetromino,
    moved: bool,
};

pub fn handle_input(piece: *tetromino.Tetromino, input_state: *InputState) MovementResult {
    var temp_piece = piece.*;
    var moved = false;

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
        temp_piece.position.y += 1;  // You might want to implement instant drop here
        moved = true;
    } else if (ray.IsKeyDown(ray.KEY_DOWN) and input_state.can_move()) {
        temp_piece.position.y += 1;
        moved = true;
    }

    return .{
        .piece = temp_piece,
        .moved = moved,
    };
}

const FallingState = struct {
    fall_delay: f32,      // Delay between falls (in seconds)
    fall_timer: f32,      // Current time until next fall

    pub fn init(initial_delay: f32) FallingState {
        return .{
            .fall_delay = initial_delay,
            .fall_timer = initial_delay,
        };
    }

    pub fn update(self: *FallingState) bool {
        self.fall_timer -= ray.GetFrameTime();
        if (self.fall_timer <= 0) {
            self.fall_timer = self.fall_delay;
            return true;  // Time to fall
        }
        return false;
    }

    // Could add methods to adjust speed based on level/score
    pub fn increase_speed(self: *FallingState, factor: f32) void {
        self.fall_delay *= factor;
    }
};


// Example usage in game loop:
pub fn game_loop(grid: *Grid, input_piece: *tetromino.Tetromino) !void {
    var piece = input_piece.*;
    var input_state = InputState{};
    const allocator = std.heap.page_allocator;
    var falling = FallingState.init(1.0);

    while (!ray.WindowShouldClose()) {

        // Handle input
        const result = handle_input(&piece, &input_state);
        if (result.moved) {
            const cells = try result.piece.getGridCells(allocator);
            defer allocator.free(cells);
            if (grid.hasSpace(cells)) {
                std.debug.print("moved!\n", .{});

                piece = result.piece;
            }
        }

        if (falling.update()) {
            var fall_piece = piece;
            fall_piece.position.y += 1;
            const cells = try result.piece.getGridCells(allocator);
            defer allocator.free(cells);
            if (grid.hasSpace(cells)) {
                piece = fall_piece;
            } else {
                grid.append(cells);
                //grid.removeCompletedLines();
                     // 3. Spawn new piece
           }
        }

        // render part
        const cells = try piece.getGridCells(allocator);
        defer allocator.free(cells);
        // Begin drawing
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.BLACK);

        // Draw grid
        for (grid.cells) |row| {
            for (row) |cell| {
                ray.DrawRectangle(
                    @intCast(cell.position.x * 50), // scale factor of 30
                    @intCast(cell.position.y * 50),
                    49, // slightly smaller than scale for grid effect
                    49,
                    cell.color,
                );
            }
        }

        // Draw current piece
        for (cells) |cell| {
            ray.DrawRectangle(
                @intCast(cell.position.x * 50),
                @intCast(cell.position.y * 50),
                49,
                49,
                tetromino.getTetrominoColor(piece.tetromino_type),
            );
        }
    }
}

pub fn main() !void {
    var prng = std.rand.DefaultPrng.init(@intCast(std.time.timestamp()));
    var rand = prng.random();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const screen_width = 800;
    const screen_height = 1200;
    const grid_width = 10;
    const grid_height = 20;
    // create all figures
    ray.InitWindow(screen_width, screen_height, "tetris");
    defer ray.CloseWindow();

    ray.SetTargetFPS(60);
    const board_position = tetromino.Position{ .x = 1, .y = 1 };
    const board = Board {
        .width = grid_width,
        .height = grid_height,
        .unit_size = 50,
        .border_width = 1,
        .background_color = ray.DARKBLUE,
        .border_color = ray.BLUE,
    };
    const tetromino_spawn_pos = tetromino.Position{ .x = board.width/2, .y = 0 };

    var active_tetromino: tetromino.Tetromino = undefined;
    var active = false;
    var game_over = false;
    const grid_position = tetromino.Position{ .x = board_position.x + board.border_width, .y = board_position.y };
    var grid = try Grid.init(gpa.allocator(), grid_width, grid_height, ray.DARKBLUE);
    defer grid.deinit();
    // state of points
    active_tetromino = tetromino.Tetromino.initRandom(&rand, tetromino_spawn_pos);
    try game_loop(&grid, &active_tetromino);
    while (!ray.WindowShouldClose()) {
        ray.BeginDrawing();
        defer ray.EndDrawing();

        ray.ClearBackground(ray.RAYWHITE);
        board.draw(board_position);
        grid.draw(grid_position);

        if (game_over) {
            ray.DrawText("Game Over!", (board_position.x + board.border_width)*squareSize, 0, squareSize, ray.RED);
            continue;
        }
        // Rotate it
        //piece.rotate_clockwise();

        // draw state points
        if (active) {
            const allocator = gpa.allocator();
            const cells = try active_tetromino.getGridCells(allocator);
            defer allocator.free(cells);

            drawCells(grid_position, cells);
            if (grid.readyToStop(cells)) {
                active = false;
                grid.append(cells);
       //         state.removeLines();
            } else {
                active_tetromino.position.y += 1;
                std.debug.print("INC!", .{});
            }
        } else {
            active_tetromino = tetromino.Tetromino.initRandom(&rand, tetromino_spawn_pos);
            std.debug.print("INIT!", .{});
            const allocator = gpa.allocator();
            const cells = try active_tetromino.getGridCells(allocator);
            defer allocator.free(cells);

            // no space - game over!
            if (!grid.hasSpace(cells)) {
                game_over = true;
                continue;
            }
            active = true;
        }
    }
}
