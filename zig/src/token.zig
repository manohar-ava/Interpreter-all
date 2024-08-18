const std = @import("std");
pub const Precedences = enum {
    lowest,
    equals,
    comparision,
    sum,
    product,
    prefix,
    call,
    pub fn intVal(self: Precedences) i32 {
        return switch (self) {
            .lowest => @intFromEnum(Precedences.lowest),
            .equals => @intFromEnum(Precedences.equals),
            .comparision => @intFromEnum(Precedences.comparision),
            .sum => @intFromEnum(Precedences.sum),
            .product => @intFromEnum(Precedences.product),
            .prefix => @intFromEnum(Precedences.prefix),
            .call => @intFromEnum(Precedences.call),
        };
    }
};
pub const tokens = union(enum) {
    ident: []const u8,
    int: []const u8,
    illegal,
    eof,
    assign,
    plus,
    comma,
    semicolon,
    lparen,
    rparen,
    lbrace,
    rbrace,
    function,
    bool_true,
    bool_false,
    if_stmt,
    else_stmt,
    return_stmt,
    let,
    bang,
    minus,
    asterisk,
    slash,
    greaterThan,
    lesserThan,
    equal_to,
    not_equal_to,
    pub fn format(self: tokens, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .minus => try writer.writeByte('-'),
            .plus => try writer.writeByte('+'),
            .bang => try writer.writeByte('!'),
            .asterisk => try writer.writeByte('*'),
            .slash => try writer.writeByte('/'),
            .lesserThan => try writer.writeByte('<'),
            .greaterThan => try writer.writeByte('>'),
            .not_equal_to => try writer.writeAll("!="),
            .equal_to => try writer.writeAll("=="),
            .ident, .int => |val| try writer.writeAll(val),
            .semicolon => try writer.writeByte(';'),
            else => {},
        }
    }
    pub fn precedence(self: tokens) i32 {
        return switch (self) {
            .equal_to => Precedences.equals.intVal(),
            .not_equal_to => Precedences.equals.intVal(),
            .lesserThan => Precedences.comparision.intVal(),
            .greaterThan => Precedences.comparision.intVal(),
            .plus => Precedences.sum.intVal(),
            .minus => Precedences.sum.intVal(),
            .slash => Precedences.product.intVal(),
            .asterisk => Precedences.product.intVal(),
            else => Precedences.lowest.intVal(),
        };
    }
    pub fn isPrefix(self: tokens) bool {
        return switch (self) {
            .int, .ident, .minus, .bang => true,
            else => false,
        };
    }
};

const keyWord = struct { key: []const u8, val: tokens };
pub const key_words = [_]keyWord{ keyWord{ .key = "func", .val = .function }, keyWord{ .key = "let", .val = .let }, keyWord{ .key = "true", .val = .bool_true }, keyWord{ .key = "false", .val = .bool_false }, keyWord{ .key = "if", .val = .if_stmt }, keyWord{ .key = "else", .val = .else_stmt }, keyWord{ .key = "return", .val = .return_stmt } };

pub fn lookUpIdentifer(ident: []const u8) tokens {
    for (key_words) |pair| {
        if (std.mem.eql(u8, ident, pair.key)) {
            return pair.val;
        }
    }
    return .{ .ident = "" };
}
