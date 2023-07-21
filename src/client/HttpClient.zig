const std = @import("std");
const ClientInterface = @import("ClientInterface.zig");

const Client = std.http.Client;
const RequestError = Client.RequestError;
const Request = Client.Request;
const StartError = Client.Request.StartError;
const WaitError = Client.Request.WaitError;
const Reader = Client.Request.Reader;

const Self = @This();

internal_client: std.http.Client,

pub fn new(allocator: std.mem.Allocator) Self {
    return Self{
        .internal_client = std.http.Client{ .allocator = allocator },
    };
}

pub fn init(self: *Self) ClientInterface {
    return .{
        .ptr = self,
        .fn_table = &.{
            .request = request,
        },
    };
}

fn request(
    ctx: *anyopaque,
    method: std.http.Method,
    uri: std.Uri,
    headers: std.http.Headers,
    options: std.http.Client.Options,
) RequestError!Request {
    const self: *Self = @ptrCast(@alignCast(ctx));
    return self.internal_client.request(method, uri, headers, options);
}
