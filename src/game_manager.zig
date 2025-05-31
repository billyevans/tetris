const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const tetromino = @import("tetromino");
const gs = @import("game_state");
const rm = @import("records_manager");

pub const GameStatus = enum {
    playing,
    paused,
    game_over,
    high_score,
};

pub const InputEvent = enum {
    move_left,
    move_right,
    rotate_clockwise,
    rotate_counterclockwise,
    soft_drop,
    hard_drop,
    toggle_pause,
    toggle_records,
    restart,
    none,
};

pub const MoveResult = struct {
    piece_moved: bool = false,
    piece_rotated: bool = false,
    piece_dropped: bool = false,
    state_changed: bool = false,
};

pub const SoundFiles = struct {
    drop: [:0]const u8,
    move: [:0]const u8,
    rotate: [:0]const u8,
    line_clear: [:0]const u8,
    level_up: [:0]const u8,
};

pub const SoundType = enum {
    drop,
    move,
    rotate,
    line_clear,
    level_up,
};

pub const SoundManager = struct {
    drop_sound: ray.Sound,
    move_sound: ray.Sound,
    rotate_sound: ray.Sound,
    line_clear_sound: ray.Sound,
    level_up_sound: ray.Sound,
    enabled: bool,

    pub fn init(sound_files_ptr: ?SoundFiles) SoundManager {
        if (sound_files_ptr) |sound_files| {
            return SoundManager{
                .drop_sound = ray.LoadSound(sound_files.drop),
                .move_sound = ray.LoadSound(sound_files.move),
                .rotate_sound = ray.LoadSound(sound_files.rotate),
                .line_clear_sound = ray.LoadSound(sound_files.line_clear),
                .level_up_sound = ray.LoadSound(sound_files.level_up),
                .enabled = true,
            };
        }
        return SoundManager{
            .drop_sound = .{},
            .move_sound = .{},
            .rotate_sound = .{},
            .line_clear_sound = .{},
            .level_up_sound = .{},
            .enabled = false,
        };
    }

    pub fn deinit(self: *SoundManager) void {
        ray.UnloadSound(self.drop_sound);
        ray.UnloadSound(self.move_sound);
        ray.UnloadSound(self.rotate_sound);
        ray.UnloadSound(self.line_clear_sound);
        ray.UnloadSound(self.level_up_sound);
    }

    pub fn play(self: *SoundManager, sound_type: SoundType) void {
        if (!self.enabled) return;

        switch (sound_type) {
            .drop => ray.PlaySound(self.drop_sound),
            .move => ray.PlaySound(self.move_sound),
            .rotate => ray.PlaySound(self.rotate_sound),
            .line_clear => ray.PlaySound(self.line_clear_sound),
            .level_up => ray.PlaySound(self.level_up_sound),
        }
    }

    pub fn setEnabled(self: *SoundManager, enabled: bool) void {
        self.enabled = enabled;
    }
};

pub const GameManager = struct {
    // Game components
    grid: *gs.Grid,
    preview_grid: *gs.Grid,
    current_piece: tetromino.Tetromino,
    next_piece: tetromino.Tetromino,
    ghost_piece: ?tetromino.Tetromino,

    // Game state
    game_state: gs.GameState,
    status: GameStatus,
    falling_state: gs.FallingState,

    // Input handling
    horizontal_move_delay: f32,
    horizontal_move_timer: f32,
    vertical_move_delay: f32,
    vertical_move_timer: f32,

    prng: std.Random.DefaultPrng,

    sound_manager: SoundManager,

    records_manager: ?*rm.RecordsManager,
    achieved_high_score: bool,
    was_previously_paused: bool,

    pub fn init(
        grid: *gs.Grid,
        preview_grid: *gs.Grid,
        seed: u64,
        sound_files: ?SoundFiles,
        records_manager: ?*rm.RecordsManager,
    ) GameManager {
        var prng = std.Random.DefaultPrng.init(seed);
        const rand = prng.random();
        const spawn_pos = tetromino.Position{
            .x = @divFloor(@as(i32, @intCast(grid.width)), 2),
            .y = 0
        };
        const next_spawn_pos = tetromino.Position{
            .x = @divFloor(@as(i32, @intCast(preview_grid.width)), 2),
            .y = 1
        };

        const current_piece = tetromino.Tetromino.initRandom(rand, spawn_pos);
        const next_piece = tetromino.Tetromino.initRandom(rand, next_spawn_pos);

        const sound_manager = SoundManager.init(sound_files);

        return GameManager{
            .grid = grid,
            .preview_grid = preview_grid,
            .current_piece = current_piece,
            .next_piece = next_piece,
            .ghost_piece = null,
            .game_state = gs.GameState.init(),
            .status = .playing,
            .falling_state = gs.FallingState.init(0),
            .horizontal_move_delay = 0.10,
            .horizontal_move_timer = 0.05,
            .vertical_move_delay = 0.05,
            .vertical_move_timer = 0.05,
            .prng = prng,
            .sound_manager = sound_manager,
            .records_manager = records_manager,
            .achieved_high_score = false,
            .was_previously_paused = false,
        };
    }

    pub fn deinit(self: *GameManager) void {
        self.sound_manager.deinit();
    }

    fn playSound(self: *GameManager, sound_type: SoundType) void {
        self.sound_manager.play(sound_type);
    }

    pub fn update(self: *GameManager) void {
        if (self.status != .playing) {
            return;
        }

        if (self.falling_state.update()) {
            self.tryMovePiece(0, 1) catch |err| {
                if (err == error.PieceLocked) {
                    self.lockPiece();
                }
            };
        }

        self.horizontal_move_timer -= ray.GetFrameTime();
        self.vertical_move_timer -= ray.GetFrameTime();
    }

    fn lockPiece(self: *GameManager) void {
        self.grid.addPiece(&self.current_piece);

        const removed = self.grid.removeCompletedLines();
        self.game_state.clearLines(removed);
        self.falling_state.setLevel(self.game_state.level);

        if (removed > 0) {
            self.playSound(.line_clear);
        }

        self.current_piece = self.next_piece;
        const spawn_pos = tetromino.Position{
            .x = @divFloor(@as(i32, @intCast(self.grid.width)), 2),
            .y = 0
        };
        self.current_piece.position = spawn_pos;

        const next_spawn_pos = tetromino.Position{
            .x = @divFloor(@as(i32, @intCast(self.preview_grid.width)), 2),
            .y = 1
        };
        self.next_piece = tetromino.Tetromino.initRandom(self.prng.random(), next_spawn_pos);

        self.ghost_piece = null;

        if (!self.grid.hasSpaceForPiece(&self.current_piece)) {
            self.checkHighScore();
        }
    }
    fn checkHighScore(self: *GameManager) void {
        if (self.records_manager) |records| {
            if (records.isHighScore(@intCast(self.game_state.score))) {
                self.status = .high_score;
                self.achieved_high_score = true;
            } else {
                self.status = .game_over;
            }
        } else {
            self.status = .game_over;
        }
    }

    pub fn submitHighScore(self: *GameManager, name: []const u8) !void {
        if (self.records_manager) |records| {
            if (self.achieved_high_score) {
                _ = try records.insertScore(
                    name,
                    @intCast(self.game_state.score),
                    @intCast(self.game_state.level),
                    @intCast(self.game_state.lines_cleared)
                );
            }
        }
        self.status = .game_over;
        self.achieved_high_score = false;
    }

    pub fn restart(self: *GameManager) void {
        self.grid.clear();
        self.game_state = gs.GameState.init();
        self.falling_state = gs.FallingState.init(0);

        const spawn_pos = tetromino.Position{
            .x = @divFloor(@as(i32, @intCast(self.grid.width)), 2),
            .y = 0
        };
        const next_spawn_pos = tetromino.Position{
            .x = @divFloor(@as(i32, @intCast(self.preview_grid.width)), 2),
            .y = 1
        };
        const rand = self.prng.random();
        self.current_piece = tetromino.Tetromino.initRandom(rand, spawn_pos);
        self.next_piece = tetromino.Tetromino.initRandom(rand, next_spawn_pos);
        self.ghost_piece = null;
        self.status = .playing;
    }

    pub fn togglePause(self: *GameManager) void {
        if (self.status == .playing) {
            self.status = .paused;
        } else if (self.status == .paused) {
            // Only unpause if records are not being shown
            if (self.records_manager == null or !self.records_manager.?.show_records) {
                self.status = .playing;
            }
        }
    }

    pub fn toggleRecords(self: *GameManager) void {
        if (self.records_manager) |records| {
            records.toggleRecordsDisplay();
            if (records.show_records) {
                self.was_previously_paused = (self.status == .paused);

                if (self.status == .playing) {
                    self.status = .paused;
                }
            } else {
                if (!self.was_previously_paused and self.status == .paused) {
                    self.status = .playing;
                }
            }
        }
    }

    fn tryMovePiece(self: *GameManager, dx: i32, dy: i32) !void {
        var new_piece = self.current_piece;
        new_piece.position.x += dx;
        new_piece.position.y += dy;

        if (self.grid.hasSpaceForPiece(&new_piece)) {
            if (dy > 0) {
                self.game_state.addSoftDrop(@intCast(dy));
            }

            self.current_piece = new_piece;
            self.ghost_piece = null;  // Reset ghost piece
            return;
        }

        // If we tried to move down and couldn't, the piece is locked
        if (dy > 0) {
            return error.PieceLocked;
        }
    }

    fn tryRotatePiece(self: *GameManager, clockwise: bool) bool {
        var rotated_piece = self.current_piece;
        if (rotated_piece.tryRotate(clockwise, self.grid)) {
            self.current_piece = rotated_piece;
            self.ghost_piece = null;  // Reset ghost piece
            return true;
        }
        return false;
    }

    fn hardDrop(self: *GameManager) void {
        self.updateGhostPiece();
        if (self.ghost_piece) |ghost| {
            self.current_piece = ghost;
            self.playSound(.drop);
            self.lockPiece();

            // Add a short input freeze after hard drop
            self.horizontal_move_timer = 0.2;
            self.vertical_move_timer = 0.2;
        }
    }

    pub fn updateGhostPiece(self: *GameManager) void {
        if (self.ghost_piece == null) {
            self.ghost_piece = self.grid.findDropPosition(&self.current_piece);
        }
    }

    pub fn processInput(self: *GameManager, event: InputEvent) MoveResult {
        var result = MoveResult{};

        switch (self.status) {
            .playing => {
                switch (event) {
                    .move_left => {
                        self.tryMovePiece(-1, 0) catch {};
                        self.horizontal_move_timer = self.horizontal_move_delay;
                        self.playSound(.move);
                        result.piece_moved = true;
                    },
                    .move_right => {
                        self.tryMovePiece(1, 0) catch {};
                        self.horizontal_move_timer = self.horizontal_move_delay;
                        self.playSound(.move);
                        result.piece_moved = true;
                    },
                    .rotate_clockwise => {
                        if (self.tryRotatePiece(true)) {
                            self.playSound(.rotate);
                            result.piece_rotated = true;
                        }
                    },
                    .rotate_counterclockwise => {
                        if (self.tryRotatePiece(false)) {
                            self.playSound(.rotate);
                            result.piece_rotated = true;
                        }
                    },
                    .soft_drop => {
                        self.tryMovePiece(0, 1) catch |err| {
                            if (err == error.PieceLocked) {
                                self.lockPiece();
                            }
                        };
                        self.vertical_move_timer = self.vertical_move_delay;
                        result.piece_moved = true;
                    },
                    .hard_drop => {
                        self.hardDrop();
                        result.piece_dropped = true;
                    },
                    .toggle_pause => {
                        self.togglePause();
                        result.state_changed = true;
                    },
                    .toggle_records => {
                        self.toggleRecords();
                        result.state_changed = true;
                    },
                    .restart => {},
                    .none => {},
                }
            },
            .paused => {
                if (event == .toggle_pause) {
                    self.togglePause();
                    result.state_changed = true;
                } else if (event == .toggle_records) {
                    self.toggleRecords();
                    result.state_changed = true;
                }
            },
            .game_over => {
                if (event == .restart) {
                    self.restart();
                    result.state_changed = true;
                } else if (event == .toggle_records) {
                    self.toggleRecords();
                    result.state_changed = true;
                }
            },
            .high_score => {
                // just wait for name input
            },
        }

        return result;
    }

    pub fn setSoundEnabled(self: *GameManager, enabled: bool) void {
        self.sound_manager.setEnabled(enabled);
    }

    pub fn canMovePiece(self: *const GameManager, direction: enum { horizontal, vertical }) bool {
        switch (direction) {
            .horizontal => return self.horizontal_move_timer <= 0,
            .vertical => return self.vertical_move_timer <= 0,
        }
    }
};
