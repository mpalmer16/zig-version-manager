const std = @import("std");
const Client = std.http.Client;
const RequestError = Client.RequestError;
const Request = Client.Request;
const StartError = Client.Request.StartError;
const WaitError = Client.Request.WaitError;
const Reader = Client.Request.Reader;

const RequestInterface = @This();

ptr: *const anyopaque,
fn_table: *const FnTable,

const FnTable = struct {
    deinit: *const fn (
        ctx: *const anyopaque,
    ) void,
    start: *const fn (
        ctx: *const anyopaque,
    ) StartError!void,
    wait: *const fn (
        ctx: *const anyopaque,
    ) WaitError!void,
    reader: *const fn (
        ctx: *const anyopaque,
    ) Reader,
};

pub fn deinit(self: RequestInterface) void {
    self.fn_table.deinit(self.ptr);
}

pub fn start(self: RequestInterface) StartError!void {
    self.fn_table.start(self.ptr);
}

pub fn wait(self: RequestInterface) WaitError!void {
    self.fn_table.wait(self.ptr);
}

pub fn reader(self: RequestInterface) Reader {
    self.fn_table.reader(self.ptr);
}
