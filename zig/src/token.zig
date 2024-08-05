const std = @import("std");
pub const Token = struct { type: tokens, literal: []const u8 };
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
    let,
    bang,
    minus,
    asterisk,
    slash,
    greaterThan,
    lesserThan,
};

const keyWord = struct { key: []const u8, val: tokens };
pub const key_words = [_]keyWord{ keyWord{ .key = "func", .val = .function }, keyWord{ .key = "let", .val = .let } };

pub fn lookUpIdentifer(ident: []const u8) tokens {
    for (key_words) |pair| {
        if (std.mem.eql(u8, ident, pair.key)) {
            return pair.val;
        }
    }
    return .{ .ident = "" };
}
