const std = @import("std");
const ray = @cImport({
    @cInclude("raylib.h");
});
const rm = @import("records_manager");
const testing = std.testing;

test "RecordsManager basic functionality" {
    const allocator = testing.allocator;
    const test_file = "test_records.dat";

    // Clean up any leftover test file
    std.fs.cwd().deleteFile(test_file) catch |err| {
        if (err != error.FileNotFound) {
            return err;
        }
    };

    // Create a new records manager
    var records = try rm.RecordsManager.init(allocator, test_file, "Tester");
    defer records.deinit();

    try testing.expectEqual(@as(usize, 0), records.count);

    // Insert some test scores
    _ = try records.insertScore("Player1", 1000, 5, 30);
    _ = try records.insertScore("Player2", 2000, 10, 60);
    _ = try records.insertScore("Player3", 500, 2, 15);

    // Should have 3 records now, in descending score order
    try testing.expectEqual(@as(usize, 3), records.count);
    try testing.expectEqual(@as(u32, 2000), records.records[0].score);
    try testing.expectEqual(@as(u32, 1000), records.records[1].score);
    try testing.expectEqual(@as(u32, 500), records.records[2].score);

    // Add a new high score that should take the top position
    _ = try records.insertScore("Player4", 3000, 15, 90);
    try testing.expectEqual(@as(usize, 4), records.count);
    try testing.expectEqual(@as(u32, 3000), records.records[0].score);

    // Test isHighScore
    try testing.expect(records.isHighScore(600));  // Better than the lowest score
    _ = try records.insertScore("Player3", 500, 2, 15);
    _ = try records.insertScore("Player3", 500, 2, 15);
    _ = try records.insertScore("Player3", 500, 2, 15);
    _ = try records.insertScore("Player3", 500, 2, 15);
    _ = try records.insertScore("Player3", 500, 2, 15);
    _ = try records.insertScore("Player3", 500, 2, 15);
    _ = try records.insertScore("Player3", 500, 2, 15);
    try testing.expect(!records.isHighScore(100)); // Worse than all scores

    var records2 = try rm.RecordsManager.init(allocator, test_file, "Tester");
    defer records2.deinit();

    try testing.expectEqual(records.count, records2.count);
    try testing.expectEqual(records.records[0].score, records2.records[0].score);

    std.fs.cwd().deleteFile(test_file) catch {};
}

test "ScoreRecord initialization" {
    const name = "TestPlayer";
    const score: u32 = 2500;
    const level: u32 = 12;
    const lines: u32 = 75;

    const record = rm.ScoreRecord.init(name, score, level, lines);

    try testing.expectEqualStrings(name, std.mem.sliceTo(&record.name, 0));
    try testing.expectEqual(score, record.score);
    try testing.expectEqual(level, record.level);
    try testing.expectEqual(lines, record.lines);
    try testing.expect(record.timestamp > 0);  // Should have a valid timestamp
}

test "Toggle records display" {
    const allocator = testing.allocator;
    const test_file = "test_records.dat";

    var records = try rm.RecordsManager.init(allocator, test_file, "Tester");
    defer records.deinit();

    try testing.expect(!records.show_records);

    records.toggleRecordsDisplay();
    try testing.expect(records.show_records);

    records.toggleRecordsDisplay();
    try testing.expect(!records.show_records);

    std.fs.cwd().deleteFile(test_file) catch {};
}
