const std = @import("std");
const process = @import("process.zig");
const Tarball = @import("tarball.zig").Tarball;

const log = std.log;
const create = process.RunCommand.create;

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
        tarball.fetch();
        var commands = [_]process.RunCommand{
            create(.write_to_file, tarball.name, tarball.data, null),
            create(.unzip, tarball.name, null, null),
            create(.move, tarball.short_name, null, tarball.install_dir),
            create(.cleanup_file, tarball.name, null, null),
            create(.cleanup_directory, tarball.short_name, null, null),
            create(.write_to_file, tarball.zigrc, tarball.export_line, null),
        };
        const cr = process.CommandRunner(){ .commands = &commands };
        cr.run(allocator);
    }
}
