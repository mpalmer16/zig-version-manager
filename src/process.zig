const std = @import("std");

const log = std.log;
const panic = std.debug.panic;

pub const Process = enum { unzip, move, cleanup_file, cleanup_directory, write_to_file };

pub fn CommandRunner() type {
    return struct {
        const Self = @This();

        commands: []RunCommand,
        allocator: std.mem.Allocator,

        pub fn new(commands: []RunCommand, allocator: std.mem.Allocator) Self {
            return Self{
                .commands = commands,
                .allocator = allocator,
            };
        }

        pub fn run(self: Self) void {
            for (self.commands) |command| {
                processCommand(command.p, command.arg, self.allocator, command.data, command.dest);
            }
        }
    };
}

pub const RunCommand = struct {
    const Self = @This();
    p: Process,
    arg: []const u8,
    data: ?[]const u8,
    dest: ?[]const u8,

    pub fn command(prc: Process, arg: []const u8, data: ?[]const u8, dest: ?[]const u8) Self {
        return Self{
            .p = prc,
            .arg = arg,
            .data = data,
            .dest = dest,
        };
    }
};

fn processCommand(process: Process, filename: []const u8, allocator: std.mem.Allocator, data: ?[]const u8, dest: ?[]const u8) void {
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
                dest orelse panic("no destination passed for move command", .{}),
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
        .write_to_file => {
            writeToFile(data.?, filename);
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

fn writeToFile(data: []const u8, filename: []const u8) void {
    log.info("writing data to {s}", .{filename});
    const file = std.fs.cwd().createFile(
        filename,
        .{ .read = true },
    ) catch |err| {
        panic("could not create file {s}: {any}", .{ filename, err });
    };
    defer file.close();

    file.writeAll(data) catch |err|
        panic("could not write out data: {any}", .{err});
}
