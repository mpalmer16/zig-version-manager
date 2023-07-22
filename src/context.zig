const std = @import("std");
const config = @import("config.zig").config;
const ClientInterface = @import("client/ClientInterface.zig");

const json = std.json;
const panic = std.debug.panic;
const log = std.log;

const expectEqualSlices = std.testing.expectEqualSlices;
const expectEqualStrings = std.testing.expectEqualStrings;

pub const Context = struct {
    const Self = @This();

    tarball_uri_str: []const u8,
    tarball_uri: std.Uri,
    name: []const u8,
    short_name: []const u8,
    export_line: []const u8,
    zigrc: []const u8,
    install_dir: []const u8,
    allocator: std.mem.Allocator,
    client: ClientInterface,

    pub fn new(allocator: std.mem.Allocator, client: ClientInterface) Self {
        const versions_uri = parseUri(config.VERSION_INFO_URI);
        const tarball_uri_str = parseTarballStr(allocator, client, versions_uri);
        const tarball_uri = parseUri(tarball_uri_str);
        const name = tailAfterNeedle(u8, tarball_uri_str);
        const short_name = name[0 .. name.len - 7];
        const export_line = createExportLine(allocator, short_name);

        return Self{
            .tarball_uri_str = tarball_uri_str,
            .tarball_uri = tarball_uri,
            .name = name,
            .short_name = short_name,
            .export_line = export_line,
            .zigrc = config.ZIGRC,
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

    pub fn fetch(self: Self) []const u8 {
        return fetchData(self.allocator, self.client, self.tarball_uri);
    }
};

fn createExportLine(allocator: std.mem.Allocator, short_name: []const u8) []const u8 {
    return std.fmt.allocPrint(allocator, "{s}{s}/{s}", .{
        config.ZIG_NIGHTLY_PATH,
        config.ZIG_INSTALLS_DIR,
        short_name,
    }) catch |err| {
        panic("could not create export line for {s}: {any}", .{ short_name, err });
    };
}

fn parseUri(str: []const u8) std.Uri {
    return std.Uri.parse(str) catch |err| {
        panic("Could not parse uri from {s}: {any}", .{ str, err });
    };
}

fn parseTarballStr(allocator: std.mem.Allocator, client: ClientInterface, uri: std.Uri) []u8 {
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

fn fetchData(allocator: std.mem.Allocator, client: ClientInterface, uri: std.Uri) []const u8 {
    log.info("fetching {any}", .{uri});
    var headers = std.http.Headers{ .allocator = allocator };
    defer headers.deinit();

    headers.append("accept", "*/*") catch |err| {
        panic("could not append headers: {any}", .{err});
    };

    client.request(.GET, uri, headers, .{}) catch |err| {
        panic("could not make client request: {any}", .{err});
    };
    defer client.deinit();

    client.start() catch |err| {
        panic("could not start client request: {any}", .{err});
    };
    client.wait() catch |err| {
        panic("could not wait for client request: {any}", .{err});
    };

    const max_size = if (client.response().content_length) |size| size else 40000;

    log.info("fetching size {d}", .{max_size});

    return client.reader().readAllAlloc(allocator, max_size) catch |err| {
        panic("Could not read response: {any} with size {d}\n", .{ err, max_size });
    };
}

test "fetch data" {
    const TestHttpClient = @import("client/TestHttpClient.zig");
    const allocator = std.testing.allocator;
    var test_client = TestHttpClient.new(allocator);
    var client = test_client.init();
    _ = client;
    const uri = try std.Uri.parse("http://example.org");
    _ = uri;
    const expected = "abc";
    _ = expected;
    //    const result = fetchData(allocator, client, uri);

    //    try std.testing.expectEqualStrings(expected, result);
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

test "get the tail from here" {
    const haystack = "https://ziglang.org/builds/zig-linux-x86_64-0.11.0-dev.4003+c6aa29b6f.tar.xz";
    const found = tailAfterNeedle(u8, haystack);

    try expectEqualStrings(
        "zig-linux-x86_64-0.11.0-dev.4003+c6aa29b6f.tar.xz",
        found,
    );
}
