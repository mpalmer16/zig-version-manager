const std = @import("std");
const config = @import("config.zig").config;

const json = std.json;
const panic = std.debug.panic;
const log = std.log;

const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqualStrings = std.testing.expectEqualStrings;

pub const Tarball = struct {
    const Self = @This();

    uri_str: []const u8,
    uri: std.Uri,
    name: []const u8,
    short_name: []const u8,
    export_line: []u8,
    zigrc: []const u8,
    install_dir: []const u8,
    data: *const fn (Tarball) []u8,
    allocator: std.mem.Allocator,
    client: *std.http.Client,

    pub fn new(allocator: std.mem.Allocator, client: *std.http.Client) Self {
        const uri_str = parseTarballStr(allocator, client);
        const uri = std.Uri.parse(uri_str) catch |err|
            panic("Could not parse taball uri from {s}: {any}", .{ uri_str, err });
        const name = tailAfterNeedle(u8, uri_str);
        const short_name = name[0 .. name.len - 7];
        const export_line = std.fmt.allocPrint(allocator, "{s}{s}/{s}", .{
            config.ZIG_NIGHTLY_PATH,
            config.ZIG_INSTALLS_DIR,
            short_name,
        }) catch |err| {
            panic("could not create export line for {s}: {any}", .{ short_name, err });
        };
        return Self{
            .uri_str = uri_str,
            .uri = uri,
            .name = name,
            .short_name = short_name,
            .export_line = export_line,
            .zigrc = config.ZIGRC,
            .data = internalFetch,
            .install_dir = config.ZIG_INSTALLS_DIR,
            .allocator = allocator,
            .client = client,
        };
    }

    pub fn systemHasLatest(self: Self) bool {
        return latestVersionInstalled(self.short_name) catch |err| {
            panic("unable to inspect system for existing install: {any}", .{err});
        };
    }

    fn internalFetch(self: Self) []u8 {
        return fetchData(self.allocator, self.client, self.uri);
    }
};

fn parseTarballStr(allocator: std.mem.Allocator, client: *std.http.Client) []u8 {
    const uri = std.Uri.parse(config.VERSION_INFO_URI) catch |err|
        panic("could not parse uri: {any}", .{err});

    const version_info = fetchData(allocator, client, uri);
    defer allocator.free(version_info);

    const version_info_json = json.parseFromSlice(json.Value, allocator, version_info, .{}) catch |err| {
        panic("could not parse version info as json: {any}", .{err});
    };
    defer version_info_json.deinit();

    return if (version_info_json.value.object.get(config.ZIG_VERSION)) |version| {
        if (version.object.get(config.OS_ARCH)) |os_arch| {
            if (os_arch.object.get(config.TARBALL)) |tarball| {
                return allocator.dupe(u8, tarball.string) catch |err| {
                    panic("could not copy tarball string: {any}", .{err});
                };
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

fn fetchData(allocator: std.mem.Allocator, client: *std.http.Client, uri: std.Uri) []u8 {
    log.info("fetching {any}", .{uri});
    var headers = std.http.Headers{ .allocator = allocator };
    defer headers.deinit();

    headers.append("accept", "*/*") catch |err| {
        panic("could not append headers: {any}", .{err});
    };

    var req = client.request(.GET, uri, headers, .{}) catch |err| {
        panic("could not make client request: {any}", .{err});
    };
    defer req.deinit();

    req.start() catch |err| {
        panic("could not start client request: {any}", .{err});
    };
    req.wait() catch |err| {
        panic("could not wait for client request: {any}", .{err});
    };

    const max_size = if (req.response.content_length) |size| size else 40000;

    log.info("fetching size {d}", .{max_size});

    return req.reader().readAllAlloc(allocator, max_size) catch |err| {
        panic("Could not read response: {any} with size {d}\n", .{ err, max_size });
    };
}

fn latestVersionInstalled(latest: []const u8) !bool {
    log.info("checking for local install of latest {s}", .{latest});
    var iter_installs = try std.fs.openIterableDirAbsolute(config.ZIG_INSTALLS_DIR, .{});
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

fn tailAfterNeedle(comptime T: type, haystack: []const T) []const T {
    return if (std.mem.indexOf(u8, haystack, config.NEEDLE)) |idx|
        haystack[idx + config.NEEDLE.len ..]
    else
        panic("could not find {s} in {s}", .{ config.NEEDLE, haystack });
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
    const found = tailAfterNeedle(u8, haystack, needle);

    try expectEqualStrings(
        "zig-linux-x86_64-0.11.0-dev.4003+c6aa29b6f.tar.xz",
        found,
    );
}
