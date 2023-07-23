const std = @import("std");
const ClientInterface = @import("ClientInterface.zig");

const Client = std.http.Client;
const RequestError = Client.RequestError;
const Request = Client.Request;
const StartError = Client.Request.StartError;
const WaitError = Client.Request.WaitError;
const Reader = Client.Request.Reader;
const Response = Client.Response;

const Self = @This();

internal_client: Client,
internal_request: Request = undefined,

pub fn new(allocator: std.mem.Allocator) Self {
    return Self{
        .internal_client = Client{ .allocator = allocator },
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
    try self.internal_request.start();
}

fn wait(ctx: *anyopaque) WaitError!void {
    const self: *Self = @ptrCast(@alignCast(ctx));
    try self.internal_request.wait();
}

fn reader(ctx: *anyopaque) Reader {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.internal_request.reader();
}

fn response(ctx: *anyopaque) Response {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.internal_request.response;
}
