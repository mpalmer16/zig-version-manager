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
        tarball.updateZigrc();
    } else {
        log.info("system does not have latest...fetching and installing", .{});
        tarball.fetch();
        var commands = [_]process.RunCommand{
            create(.unzip, tarball.name),
            create(.move, tarball.short_name),
            create(.cleanup_file, tarball.name),
            create(.cleanup_directory, tarball.short_name),
        };
        const cr = process.CommandRunner(){ .commands = &commands };
        cr.run(allocator);
        tarball.updateZigrc();
    }
}
