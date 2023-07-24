const std = @import("std");

const log = std.log;
const panic = std.debug.panic;

const Self = @This();

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{
        .allocator = allocator,
    };
}

pub fn writeToFile(self: Self, filename: []const u8, data: []const u8) void {
    _ = self;
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

pub fn unzip(self: Self, filename: []const u8) void {
    var args = [_][]const u8{
        "tar",
        "-xf",
        filename,
    };
    runProcess(self.allocator, &args, "unzip");
}

pub fn move(self: Self, filename: []const u8, dest: []const u8) void {
    var args = [_][]const u8{
        "mv",
        filename,
        dest,
    };
    runProcess(self.allocator, &args, "move");
}

pub fn cleanupFile(self: Self, filename: []const u8) void {
    var args = [_][]const u8{
        "rm",
        filename,
    };
    runProcess(self.allocator, &args, "cleanup file");
}

pub fn cleanupDir(self: Self, dirname: []const u8) void {
    var args = [_][]const u8{
        "rm",
        "-rf",
        dirname,
    };
    runProcess(self.allocator, &args, "cleanup directory");
}

fn runProcess(
    allocator: std.mem.Allocator,
    args: [][]const u8,
    command_name: []const u8,
) void {
    log.info("running command {s}", .{command_name});
    var process = std.process.Child.init(args, allocator);
    var term = process.spawnAndWait() catch |err| {
        panic("could not spawn child process for command {s}: {any}", .{ command_name, err });
    };
    switch (term) {
        std.ChildProcess.Term.Exited => log.info("{s} completed!", .{command_name}),
        else => panic("could not run command {s}", .{command_name}),
    }
}
