const std = @import("std");
const ClientInterface = @import("ClientInterface.zig");

const Client = std.http.Client;
const Request = Client.Request;
const RequestError = Client.RequestError;
const StartError = Client.Request.StartError;
const WaitError = Client.Request.WaitError;
const Reader = Client.Request.Reader;
const Response = Client.Response;

const Self = @This();

internal_allocator: std.mem.Allocator,
internal_client: Client,
internal_request: Request = undefined,

pub fn new(allocator: std.mem.Allocator) Self {
    return Self{
        .internal_allocator = allocator,
        .internal_client = std.http.Client{ .allocator = allocator },
    };
}

pub fn init(self: *Self) ClientInterface {
    return .{
        .ptr = self,
        .fn_table = &.{
            .request = request,
            .deinit = deinit,
            .start = start,
            .wait = wait,
            .reader = reader,
            .response = response,
        },
    };
}

fn request(
    ctx: *anyopaque,
    method: std.http.Method,
    uri: std.Uri,
    headers: std.http.Headers,
    options: std.http.Client.Options,
) RequestError!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.internal_request = try self.internal_client.request(
        method,
        uri,
        headers,
        options,
    );
}

fn deinit(ctx: *anyopaque) void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    self.internal_request.deinit();
}

fn start(ctx: *anyopaque) StartError!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    _ = self;
}

fn wait(ctx: *anyopaque) WaitError!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    var data = "some data to send";
    _ = self.internal_request.writeAll(data) catch |err| {
        std.debug.panic("test error on wait: {any}", .{err});
    };
    _ = self.internal_request.finish() catch |err| {
        std.debug.panic("test error on finish: {any}", .{err});
    };
}

fn reader(ctx: *anyopaque) Reader {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.internal_request.reader();
}

fn response(ctx: *anyopaque) Response {
    const self: *Self = @ptrCast(@alignCast(ctx));
    const resp: Response = .{
        .version = std.http.Version.@"HTTP/1.0",
        .status = std.http.Status.ok,
        .reason = "some reason",
        .content_length = 100,
        .headers = std.http.Headers.init(self.internal_allocator),
        .parser = std.http.protocol.HeadersParser.initDynamic(256),
    };
    return resp;
}
