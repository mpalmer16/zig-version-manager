const std = @import("std");
const process = @import("process.zig");
const Tarball = @import("tarball.zig").Tarball;

const log = std.log;
const RunCommand = process.RunCommand;
const command = RunCommand.command;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();
    var client = std.http.Client{ .allocator = allocator };

    const tarball = Tarball.new(allocator, &client);

    if (tarball.systemHasLatest()) {
        log.info("system already has latest - nothing left to do", .{});
    } else {
        log.info("system does not have latest...fetching and installing", .{});
        var commands = [_]RunCommand{
            command(.write_to_file, tarball.name, tarball.fetch(), null),
            command(.unzip, tarball.name, null, null),
            command(.move, tarball.short_name, null, tarball.install_dir),
            command(.cleanup_file, tarball.name, null, null),
            command(.cleanup_directory, tarball.short_name, null, null),
            command(.write_to_file, tarball.zigrc, tarball.export_line, null),
        };
        const cr = process.CommandRunner(){ .commands = &commands };
        cr.run(allocator);
    }
}
