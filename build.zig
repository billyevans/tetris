const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "tetris",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const tetromino_module = b.addModule("tetromino", .{
        .root_source_file = b.path("src/tetromino.zig"),
        .target = target,
        .optimize = optimize,
    });
    tetromino_module.linkSystemLibrary("raylib", .{});

    const game_state_module = b.addModule("game_state", .{
        .root_source_file = b.path("src/game_state.zig"),
        .target = target,
        .optimize = optimize,
    });
    game_state_module.linkSystemLibrary("raylib", .{});
    game_state_module.addImport("tetromino", tetromino_module);

    const records_manager_module = b.addModule("records_manager", .{
        .root_source_file = b.path("src/records_manager.zig"),
        .target = target,
        .optimize = optimize,
    });
    records_manager_module.linkSystemLibrary("raylib", .{});

    const game_manager_module = b.addModule("game_manager", .{
        .root_source_file = b.path("src/game_manager.zig"),
        .target = target,
        .optimize = optimize,
    });
    game_manager_module.linkSystemLibrary("raylib", .{});
    game_manager_module.addImport("tetromino", tetromino_module);
    game_manager_module.addImport("game_state", game_state_module);
    game_manager_module.addImport("records_manager", records_manager_module);

    exe.root_module.addImport("tetromino", tetromino_module);
    exe.root_module.addImport("game_state", game_state_module);
    exe.root_module.addImport("game_manager", game_manager_module);
    exe.root_module.addImport("records_manager", records_manager_module);

    exe.linkSystemLibrary("raylib");
    exe.linkLibC();

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const game_state_tests = b.addTest(.{
        .root_source_file = b.path("src/game_state_test.zig" ),
        .target = target,
        .optimize = optimize,
    });
    game_state_tests.root_module.addImport("tetromino", tetromino_module);
    game_state_tests.root_module.addImport("game_state", game_state_module);
    game_state_tests.linkSystemLibrary("raylib");
    game_state_tests.linkLibC();

    const tetromino_tests = b.addTest(.{
        .root_source_file = b.path("src/tetromino_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    tetromino_tests.root_module.addImport("tetromino", tetromino_module);
    tetromino_tests.root_module.addImport("game_state", game_state_module);
    tetromino_tests.linkSystemLibrary("raylib");
    tetromino_tests.linkLibC();

    // Create tests for the game manager
    const game_manager_tests = b.addTest(.{
        .root_source_file = b.path("src/game_manager_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    game_manager_tests.root_module.addImport("tetromino", tetromino_module);
    game_manager_tests.root_module.addImport("game_state", game_state_module);
    game_manager_tests.root_module.addImport("game_manager", game_manager_module);
    game_manager_tests.linkSystemLibrary("raylib");
    game_manager_tests.linkLibC();

    const records_manager_tests = b.addTest(.{
        .root_source_file = b.path("src/records_manager_test.zig"),
        .target = target,
        .optimize = optimize,
    });
    records_manager_tests.root_module.addImport("records_manager", records_manager_module);
    records_manager_tests.linkSystemLibrary("raylib");
    records_manager_tests.linkLibC();

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&b.addRunArtifact(game_state_tests).step);
    test_step.dependOn(&b.addRunArtifact(tetromino_tests).step);
    test_step.dependOn(&b.addRunArtifact(game_manager_tests).step);
    test_step.dependOn(&b.addRunArtifact(records_manager_tests).step);
}
