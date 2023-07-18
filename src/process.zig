const std = @import("std");
const log = std.log;
const panic = std.debug.panic;

const config = @import("config.zig");

const Process = enum { unzip, move, cleanup_file, cleanup_directory };

pub fn run(process: Process, filename: []const u8, allocator: std.mem.Allocator) !void {
    switch (process) {
        .unzip => {
            var unzip = [_][]const u8{
                "tar",
                "-xf",
                filename,
            };
            try runProcess(allocator, &unzip, "unzip");
        },
        .move => {
            var move = [_][]const u8{
                "mv",
                filename,
                config.ZIG_INSTALLS_DIR,
            };
            try runProcess(allocator, &move, "move");
        },
        .cleanup_file => {
            var cleanup = [_][]const u8{
                "rm",
                filename,
            };
            try runProcess(allocator, &cleanup, "cleanup file");
        },
        .cleanup_directory => {
            var cleanup = [_][]const u8{
                "rm",
                "-rf",
                filename,
            };
            try runProcess(allocator, &cleanup, "cleanup directory");
        },
    }
}

fn runProcess(
    allocator: std.mem.Allocator,
    commands: [][]const u8,
    command_name: []const u8,
) !void {
    log.info("running command {s}", .{command_name});
    var process = std.ChildProcess.init(commands, allocator);
    var term = try process.spawnAndWait();
    switch (term) {
        std.ChildProcess.Term.Exited => log.info("{s} completed!", .{command_name}),
        else => panic("could not run command {s}", .{command_name}),
    }
}
