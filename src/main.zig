const std = @import("std");
const json = std.json;
const panic = std.debug.panic;
const log = std.log;
const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqualStrings = std.testing.expectEqualStrings;

const config = @import("config.zig");

const run = @import("process.zig").run;

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var client = std.http.Client{ .allocator = allocator };
    const version_info_uri = std.Uri.parse(config.VERSION_INFO_URI) catch |err|
        panic("could not parse uri: {any}", .{err});

    const tarball_string = try parseTarballStr(allocator, &client, version_info_uri);

    var tarball_uri = std.Uri.parse(tarball_string) catch |err|
        panic("Could not parse taball uri from {s}: {any}", .{ tarball_string, err });

    const tarball_name = tailAfterNeedle(u8, tarball_string, config.NEEDLE);

    const dir_name = tarball_name[0 .. tarball_name.len - 7];

    if (try latestVersionInstalled(config.ZIG_INSTALLS_DIR, dir_name)) {
        log.info("system already has latest - nothing left to do", .{});
        const export_line = try createExportLine(allocator, dir_name);

        log.info("export line: {s}", .{export_line});
        try writeToFile(export_line, config.ZIGRC);
    } else {
        log.info("system does not have latest...fetching and installing", .{});
        const tarball_data = try fetchData(allocator, &client, tarball_uri);
        try writeToFile(tarball_data, tarball_name);
        try run(.unzip, tarball_name, allocator);
        try run(.move, dir_name, allocator);
        try run(.cleanup_file, tarball_name, allocator);
        try run(.cleanup_directory, dir_name, allocator);
        const export_line = try createExportLine(allocator, dir_name);
        try writeToFile(export_line, config.ZIGRC);
    }
}

fn parseTarballStr(allocator: std.mem.Allocator, client: *std.http.Client, uri: std.Uri) ![]u8 {
    const version_info = try fetchData(allocator, client, uri);
    defer allocator.free(version_info);

    const version_info_json = try json.parseFromSlice(json.Value, allocator, version_info, .{});
    defer version_info_json.deinit();

    return if (version_info_json.value.object.get(config.ZIG_VERSION)) |version| {
        if (version.object.get(config.OS_ARCH)) |os_arch| {
            if (os_arch.object.get(config.TARBALL)) |tarball| {
                return try allocator.dupe(u8, tarball.string);
            } else {
                panic("field {s} not found", .{config.TARBALL});
            }
        } else {
            panic("architecture {s} not found", .{config.OS_ARCH});
        }
    } else {
        panic("version {s} not found", .{config.ZIG_VERSION});
    };
}

fn createExportLine(allocator: std.mem.Allocator, dir_name: []const u8) ![]u8 {
    var export_line = try std.fmt.allocPrint(allocator, "{s}{s}/{s}", .{
        config.ZIG_NIGHTLY_PATH,
        config.ZIG_INSTALLS_DIR,
        dir_name,
    });
    log.info("created export line {s}", .{export_line});
    return export_line;
}

fn tailAfterNeedle(comptime T: type, haystack: []const T, needle: []const T) []const T {
    return if (std.mem.indexOf(u8, haystack, needle)) |idx|
        haystack[idx + needle.len ..]
    else
        panic("could not find {s} in {s}", .{ needle, haystack });
}

fn latestVersionInstalled(install_dir: []const u8, latest: []const u8) !bool {
    log.info("checking for local install of latest {s}", .{latest});
    var iter_installs = try std.fs.openIterableDirAbsolute(install_dir, .{});
    defer iter_installs.close();

    var iter = iter_installs.iterate();
    while (try iter.next()) |file| {
        if (std.mem.eql(u8, file.name, latest)) {
            log.info("found {s}", .{latest});
            return true;
        }
    }
    log.info("could not find local install of latest {s}", .{latest});
    return false;
}

fn writeToFile(data: []u8, filename: []const u8) !void {
    log.info("writing data to {s}", .{filename});
    const file = try std.fs.cwd().createFile(
        filename,
        .{ .read = true },
    );
    defer file.close();

    file.writeAll(data) catch |err|
        panic("could not write out data: {any}", .{err});
}

fn fetchData(allocator: std.mem.Allocator, client: *std.http.Client, uri: std.Uri) ![]u8 {
    log.info("fetching {any}", .{uri});
    var headers = std.http.Headers{ .allocator = allocator };
    defer headers.deinit();

    try headers.append("accept", "*/*");

    var req = try client.request(.GET, uri, headers, .{});
    defer req.deinit();

    try req.start();
    try req.wait();

    const max_size = if (req.response.content_length) |size| size else 40000;

    log.info("fetching size {d}", .{max_size});

    return req.reader().readAllAlloc(allocator, max_size) catch |err|
        panic("Could not read response: {any} with size {d}\n", .{ err, max_size });
}

test "parse nested json values" {
    const json_string =
        \\ {
        \\      "master": {
        \\          "x86_64-linux": {
        \\              "tarball": "some_tarball"
        \\          }
        \\      }
        \\ }
    ;
    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, json_string, .{});
    defer parsed.deinit();
    const tar_name = parsed.value.object.get("master").?.object.get("x86_64-linux").?.object.get("tarball").?.string;

    try expectEqualSlices(u8, "some_tarball", tar_name);
}

test "pull from headers" {
    var headers = std.http.Headers{ .allocator = std.testing.allocator };
    defer headers.deinit();

    try headers.append("foo", "bar");
    try headers.append("baz", "baf");

    const foo = headers.getFirstEntry("foo");
    const baf = headers.getFirstValue("baz");

    try expectEqualStrings("foo", foo.?.name);
    try expectEqualStrings("bar", foo.?.value);
    try expectEqualStrings("baf", baf.?);
}

test "get the tail from here" {
    const haystack = "https://ziglang.org/builds/zig-linux-x86_64-0.11.0-dev.4003+c6aa29b6f.tar.xz";
    const needle = "builds/";
    const found = tailAfterNeedle(u8, haystack, needle).?;

    try expectEqualStrings(
        "zig-linux-x86_64-0.11.0-dev.4003+c6aa29b6f.tar.xz",
        found,
    );

    const bad_needle = "foo";
    const bad_found = tailAfterNeedle(u8, haystack, bad_needle);

    try std.testing.expect(bad_found == null);
}
