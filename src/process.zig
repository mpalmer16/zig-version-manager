const std = @import("std");
const log = std.log;
const panic = std.debug.panic;

const config = @import("config.zig");

pub const Process = enum { unzip, move, cleanup_file, cleanup_directory };

pub fn run(process: Process, filename: []const u8, allocator: std.mem.Allocator) void {
    switch (process) {
        .unzip => {
            var unzip = [_][]const u8{
                "tar",
                "-xf",
                filename,
            };
            runProcess(allocator, &unzip, "unzip");
        },
        .move => {
            var move = [_][]const u8{
                "mv",
                filename,
                config.ZIG_INSTALLS_DIR,
            };
            runProcess(allocator, &move, "move");
        },
        .cleanup_file => {
            var cleanup = [_][]const u8{
                "rm",
                filename,
            };
            runProcess(allocator, &cleanup, "cleanup file");
        },
        .cleanup_directory => {
            var cleanup = [_][]const u8{
                "rm",
                "-rf",
                filename,
            };
            runProcess(allocator, &cleanup, "cleanup directory");
        },
    }
}

fn runProcess(
    allocator: std.mem.Allocator,
    commands: [][]const u8,
    command_name: []const u8,
) void {
    log.info("running command {s}", .{command_name});
    var process = std.ChildProcess.init(commands, allocator);
    var term = process.spawnAndWait() catch |err| {
        panic("could not spawn child process for command {s}: {any}", .{ command_name, err });
    };
    switch (term) {
        std.ChildProcess.Term.Exited => log.info("{s} completed!", .{command_name}),
        else => panic("could not run command {s}", .{command_name}),
    }
}
