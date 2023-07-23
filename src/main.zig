const std = @import("std");
const process = @import("process.zig");
const Context = @import("context.zig").Context;

const HttpClient = @import("client/HttpClient.zig");

const log = std.log;
const RunCommand = process.RunCommand;
const command = RunCommand.command;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    var hc = HttpClient.new(allocator);
    var http_client = hc.init();

    const context = Context.new(allocator, http_client);

    if (context.systemHasLatest()) {
        log.info("system already has latest - nothing left to do", .{});
    } else {
        log.info("system does not have latest...fetching and installing", .{});
        var commands = [_]RunCommand{
            command(.write_to_file, context.name, context.fetch(), null),
            command(.unzip, context.name, null, null),
            command(.move, context.short_name, null, context.install_dir),
            command(.cleanup_file, context.name, null, null),
            command(.cleanup_directory, context.short_name, null, null),
            command(.write_to_file, context.zigrc, context.export_line, null),
        };
        process.CommandRunner().new(&commands, allocator).run();
    }
}
