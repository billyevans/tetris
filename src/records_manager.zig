const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});

pub const MAX_RECORDS = 10;

pub const ScoreRecord = struct {
    name: [16:0]u8, // Fixed-size, null-terminated string for player name
    score: u32,
    level: u32,
    lines: u32,
    timestamp: i64, // Unix timestamp

    pub fn init(name: []const u8, score: u32, level: u32, lines: u32) ScoreRecord {
        var result = ScoreRecord{
            .name = [_:0]u8{0} ** 16,
            .score = score,
            .level = level,
            .lines = lines,
            .timestamp = std.time.timestamp(),
        };

        const copy_len = @min(name.len, 15);
        @memcpy(result.name[0..copy_len], name[0..copy_len]);
        result.name[copy_len] = 0;

        return result;
    }
};

pub const RecordsManager = struct {
    records: [MAX_RECORDS]ScoreRecord,
    count: usize,
    records_file: []const u8,
    allocator: std.mem.Allocator,

    show_records: bool,
    default_name: []const u8,

    pub fn init(allocator: std.mem.Allocator, records_file: []const u8, default_name: []const u8) !RecordsManager {
        var manager = RecordsManager{
            .records = undefined,
            .count = 0,
            .records_file = records_file,
            .allocator = allocator,
            .show_records = false,
            .default_name = default_name,
        };

        // Initialize records with empty entries
        for (0..MAX_RECORDS) |i| {
            manager.records[i] = ScoreRecord.init("", 0, 0, 0);
        }

        // Try to load records from file
        try manager.loadRecords();
        return manager;
    }

    pub fn deinit(self: *RecordsManager) void {
        _ = self; // Currently nothing to deinit
    }

    // Save records to file
    pub fn saveRecords(self: *RecordsManager) !void {
        const file = try std.fs.cwd().createFile(self.records_file, .{});
        defer file.close();

        // Write records count
        try file.writeAll(std.mem.asBytes(&self.count));

        // Write records
        for (0..self.count) |i| {
            try file.writeAll(std.mem.asBytes(&self.records[i]));
        }
    }

    // Load records from file
    pub fn loadRecords(self: *RecordsManager) !void {
        const file = std.fs.cwd().openFile(self.records_file, .{}) catch |err| {
            if (err == error.FileNotFound) {
                // No records file yet, that's okay
                self.count = 0;
                return;
            }
            return err;
        };
        defer file.close();

        // Read records count
        _ = file.readAll(std.mem.asBytes(&self.count)) catch {
            self.count = 0;
            return;
        };

        if (self.count > MAX_RECORDS) {
            self.count = MAX_RECORDS;
        }

        // Read records
        for (0..self.count) |i| {
            _ = try file.readAll(std.mem.asBytes(&self.records[i]));
        }
    }

    // Insert a new score, maintaining sorted order by score
    pub fn insertScore(self: *RecordsManager, name: []const u8, score: u32, level: u32, lines: u32) !bool {
        // If we have fewer than MAX_RECORDS or the score is higher than the lowest
        const new_record = ScoreRecord.init(name, score, level, lines);

        // Check if this score qualifies as a high score
        if (self.count < MAX_RECORDS or score > self.records[self.count - 1].score) {
            // Find the insertion position
            var pos: usize = 0;
            while (pos < self.count and score <= self.records[pos].score) {
                pos += 1;
            }

            // Shift lower scores down
            if (self.count < MAX_RECORDS) {
                // We can add a new record
                var i = self.count;
                while (i > pos) : (i -= 1) {
                    self.records[i] = self.records[i - 1];
                }
                self.count += 1;
            } else {
                // We need to overwrite the lowest record
                var i: usize = MAX_RECORDS - 1;
                while (i > pos) : (i -= 1) {
                    self.records[i] = self.records[i - 1];
                }
            }

            // Insert the new record
            self.records[pos] = new_record;

            // Save to file
            try self.saveRecords();
            return true; // New high score!
        }

        return false; // Not a high score
    }

    // Check if a score would qualify as a high score
    pub fn isHighScore(self: *const RecordsManager, score: u32) bool {
        return self.count < MAX_RECORDS or score > self.records[self.count - 1].score;
    }

    // Toggle records display
    pub fn toggleRecordsDisplay(self: *RecordsManager) void {
        self.show_records = !self.show_records;
    }

    // Format a date from timestamp
    fn formatDate(timestamp: i64, buffer: []u8) ![]u8 {
        const seconds: u64 = @intCast(@mod(timestamp, 60));
        const minutes: u64 = @intCast(@mod(@divFloor(timestamp, 60), 60));
        const hours: u64 = @intCast(@mod(@divFloor(timestamp, 3600), 24));
        const days: u64 = @intCast(@mod(@divFloor(timestamp, 86400), 31) + 1);
        const months: u64 = @intCast(@mod(@divFloor(timestamp, 2629743), 12) + 1);
        const years: u64 = @intCast(1970 + @divFloor(timestamp, 31556926));

        return try std.fmt.bufPrintZ(
            buffer,
            "{d:0>4}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}",
            .{ years, months, days, hours, minutes, seconds }
        );
    }

    // Draw records table
    pub fn drawRecords(self: *RecordsManager, x: f32, y: f32, width: f32, height: f32, title_font_size: i32, text_font_size: i32) !void {
        const title_height = @as(f32, @floatFromInt(title_font_size)) * 1.5;
        const record_height = @as(f32, @floatFromInt(text_font_size)) * 1.2;
        const padding: f32 = 10;

        // Draw background
        ray.DrawRectangleRec(
            ray.Rectangle{ .x = x, .y = y, .width = width, .height = height },
            ray.ColorAlpha(ray.BLACK, 0.85)
        );

        // Draw title
        ray.DrawText(
            "HIGH SCORES",
            @intFromFloat(x + width / 2 - 100),
            @intFromFloat(y + padding),
            title_font_size,
            ray.GOLD
        );

        // Draw headers
        ray.DrawText("RANK", @intFromFloat(x + padding), @intFromFloat(y + title_height), text_font_size, ray.WHITE);
        ray.DrawText("NAME", @intFromFloat(x + padding + 60), @intFromFloat(y + title_height), text_font_size, ray.WHITE);
        ray.DrawText("SCORE", @intFromFloat(x + padding + 200), @intFromFloat(y + title_height), text_font_size, ray.WHITE);
        ray.DrawText("LEVEL", @intFromFloat(x + padding + 300), @intFromFloat(y + title_height), text_font_size, ray.WHITE);
        ray.DrawText("LINES", @intFromFloat(x + padding + 380), @intFromFloat(y + title_height), text_font_size, ray.WHITE);

        // Draw records
        var buffer: [64]u8 = undefined;
        var date_buffer: [64]u8 = undefined;

        for (0..self.count) |i| {
            const record_y = y + title_height + record_height * @as(f32, @floatFromInt(i + 1));

            // Draw rank
            const rank_str = try std.fmt.bufPrintZ(&buffer, "{d}", .{i + 1});
            ray.DrawText(rank_str.ptr, @intFromFloat(x + padding), @intFromFloat(record_y), text_font_size, ray.WHITE);

            // Draw name
            ray.DrawText(
                &self.records[i].name,
                @intFromFloat(x + padding + 60),
                @intFromFloat(record_y),
                text_font_size,
                ray.WHITE
            );

            // Draw score
            const score_str = try std.fmt.bufPrintZ(&buffer, "{d}", .{self.records[i].score});
            ray.DrawText(score_str.ptr, @intFromFloat(x + padding + 200), @intFromFloat(record_y), text_font_size, ray.WHITE);

            // Draw level
            const level_str = try std.fmt.bufPrintZ(&buffer, "{d}", .{self.records[i].level});
            ray.DrawText(level_str.ptr, @intFromFloat(x + padding + 300), @intFromFloat(record_y), text_font_size, ray.WHITE);

            // Draw lines
            const lines_str = try std.fmt.bufPrintZ(&buffer, "{d}", .{self.records[i].lines});
            ray.DrawText(lines_str.ptr, @intFromFloat(x + padding + 380), @intFromFloat(record_y), text_font_size, ray.WHITE);

            // Draw date
            if (self.records[i].timestamp > 0) {
                const date_str = try formatDate(self.records[i].timestamp, &date_buffer);
                std.debug.print("{s}\n", .{date_str});
                ray.DrawText(
                    date_str.ptr,
                    @intFromFloat(x + padding + 460),
                    @intFromFloat(record_y),
                    text_font_size - 2,
                    ray.LIGHTGRAY
                );
            }
        }

        // Draw 'Press H to close' at the bottom
        ray.DrawText(
            "Press H to close",
            @intFromFloat(x + width / 2 - 80),
            @intFromFloat(y + height - padding - 20),
            text_font_size,
            ray.WHITE
        );
    }
};
