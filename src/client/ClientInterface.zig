const std = @import("std");

const ClientInterface = @This();

const Client = std.http.Client;
const RequestError = Client.RequestError;
const Request = Client.Request;
const StartError = Request.StartError;
const WaitError = Request.WaitError;
const Reader = Request.Reader;
const Response = Client.Response;

ptr: *anyopaque,
fn_table: *const FnTable,

const FnTable = struct {
    request: *const fn (
        ctx: *anyopaque,
        method: std.http.Method,
        uri: std.Uri,
        headers: std.http.Headers,
        options: std.http.Client.Options,
    ) RequestError!void,
    deinit: *const fn (
        ctx: *anyopaque,
    ) void,
    start: *const fn (
        ctx: *anyopaque,
    ) StartError!void,
    wait: *const fn (
        ctx: *anyopaque,
    ) WaitError!void,
    reader: *const fn (
        ctx: *anyopaque,
    ) Reader,
    response: *const fn (
        ctx: *anyopaque,
    ) Response,
};

pub fn request(
    self: ClientInterface,
    method: std.http.Method,
    uri: std.Uri,
    headers: std.http.Headers,
    options: std.http.Client.Options,
) RequestError!void {
    return self.fn_table.request(
        self.ptr,
        method,
        uri,
        headers,
        options,
    );
}

pub fn deinit(self: ClientInterface) void {
    self.fn_table.deinit(self.ptr);
}

pub fn start(self: ClientInterface) StartError!void {
    try self.fn_table.start(self.ptr);
}

pub fn wait(self: ClientInterface) WaitError!void {
    try self.fn_table.wait(self.ptr);
}

pub fn reader(self: ClientInterface) Reader {
    return self.fn_table.reader(self.ptr);
}

pub fn response(self: ClientInterface) Response {
    return self.fn_table.response(self.ptr);
}
