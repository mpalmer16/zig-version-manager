const std = @import("std");
const util = @import("util.zig");
const config = @import("config.zig");
const process = @import("process.zig");

const panic = std.debug.panic;
const log = std.log;

const create = util.RunCommand.create;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = std.http.Client{ .allocator = allocator };
    const version_info_uri = std.Uri.parse(config.VERSION_INFO_URI) catch |err|
        panic("could not parse uri: {any}", .{err});

    const tarball_string = util.parseTarballStr(allocator, &client, version_info_uri);

    var tarball_uri = std.Uri.parse(tarball_string) catch |err|
        panic("Could not parse taball uri from {s}: {any}", .{ tarball_string, err });

    const tarball_name = util.tailAfterNeedle(u8, tarball_string, config.NEEDLE);

    const dir_name = tarball_name[0 .. tarball_name.len - 7];

    if (try util.latestVersionInstalled(config.ZIG_INSTALLS_DIR, dir_name)) {
        log.info("system already has latest - nothing left to do", .{});

        const export_line = util.createExportLine(allocator, dir_name);
        util.writeToFile(export_line, config.ZIGRC);
    } else {
        log.info("system does not have latest...fetching and installing", .{});

        const tarball_data = util.fetchData(allocator, &client, tarball_uri);
        util.writeToFile(tarball_data, tarball_name);

        var commands = [_]util.RunCommand{
            create(.unzip, tarball_name),
            create(.move, dir_name),
            create(.cleanup_file, tarball_name),
            create(.cleanup_directory, dir_name),
        };
        const cr = util.CommandRunner(){ .commands = &commands };
        cr.run(allocator);

        const export_line = util.createExportLine(allocator, dir_name);
        util.writeToFile(export_line, config.ZIGRC);
    }
}
