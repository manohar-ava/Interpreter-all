const std = @import("std");
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
