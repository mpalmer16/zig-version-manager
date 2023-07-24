const std = @import("std");
const Context = @import("context.zig").Context;

const HttpClient = @import("client/HttpClient.zig");

const log = std.log;

const CommandRunner = @import("command/CommandRunner.zig");

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

        const cr = CommandRunner.init(allocator);
        cr.writeToFile(context.filename_with_ext, context.fetch());
        cr.unzip(context.filename_with_ext);
        cr.move(context.short_name, context.install_dir);
        cr.cleanupFile(context.filename_with_ext);
        cr.cleanupDir(context.short_name);
        cr.writeToFile(context.zigrc, context.export_line);
    }
}
