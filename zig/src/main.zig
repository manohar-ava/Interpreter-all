const std = @import("std");
const lexer = @import("./lexer.zig");

pub fn main() !void {
    const stdout_file = std.io.getStdOut().writer();
    const stdin_file = std.io.getStdIn().reader();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();
    try stdout.print("Welcome let's start rat race!!!\n", .{});
    try bw.flush();
    try stdout.print(">>", .{});
    try bw.flush();
    var buffer: [512]u8 = undefined;
    while (try stdin_file.readUntilDelimiterOrEof(&buffer, '\n')) |line| repl: {
        var l = lexer.newLexer(line);
        while (l.hasTokens()) {
            const tok = l.nextToken();
            switch (tok) {
                .ident, .int => |value| {
                    try stdout.print("{} | value = {s}\n", .{ tok, value });
                    try bw.flush();
                },
                .illegal => {
                    try stdout.print("Illegal token, Please exit using CTRL+D \n", .{});
                    try bw.flush();
                    break :repl;
                },
                else => {
                    try stdout.print("{any}\n", .{tok});
                    try bw.flush();
                },
            }
        }
        try stdout.print(">>", .{});
        try bw.flush();
    }
}
