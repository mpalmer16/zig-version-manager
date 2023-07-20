const std = @import("std");
const util = @import("util.zig");
const process = @import("process.zig");

const panic = std.debug.panic;
const log = std.log;

const create = process.RunCommand.create;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = std.http.Client{ .allocator = allocator };

    const tarball_string = util.parseTarballStr(allocator, &client);

    var tarball_uri = std.Uri.parse(tarball_string) catch |err|
        panic("Could not parse taball uri from {s}: {any}", .{ tarball_string, err });

    const tarball_name = util.tailAfterNeedle(u8, tarball_string);

    const dir_name = tarball_name[0 .. tarball_name.len - 7];

    if (try util.latestVersionInstalled(dir_name)) {
        log.info("system already has latest - nothing left to do", .{});

        util.createExportLine(allocator, dir_name);
    } else {
        log.info("system does not have latest...fetching and installing", .{});

        util.fetchTarball(allocator, &client, tarball_uri, tarball_name);

        var commands = [_]process.RunCommand{
            create(.unzip, tarball_name),
            create(.move, dir_name),
            create(.cleanup_file, tarball_name),
            create(.cleanup_directory, dir_name),
        };
        const cr = process.CommandRunner(){ .commands = &commands };
        cr.run(allocator);

        util.createExportLine(allocator, dir_name);
    }
}
