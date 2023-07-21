const std = @import("std");

const ClientInterface = @This();

const Client = std.http.Client;
const RequestError = Client.RequestError;
const Request = Client.Request;

ptr: *anyopaque,
fn_table: *const FnTable,

const FnTable = struct {
    request: *const fn (
        ctx: *anyopaque,
        method: std.http.Method,
        uri: std.Uri,
        headers: std.http.Headers,
        options: std.http.Client.Options,
    ) RequestError!Request,
};

pub fn request(
    self: ClientInterface,
    method: std.http.Method,
    uri: std.Uri,
    headers: std.http.Headers,
    options: std.http.Client.Options,
) RequestError!Request {
    return self.fn_table.request(
        self.ptr,
        method,
        uri,
        headers,
        options,
    );
}
