const std = @import("std");
const String = @import("string.zig").String;

pub const Precedences = enum {
    lowest,
    equals,
    comparision,
    sum,
    product,
    prefix,
    call,
    index,
    pub fn intVal(self: Precedences) i32 {
        return switch (self) {
            .lowest => @intFromEnum(Precedences.lowest),
            .equals => @intFromEnum(Precedences.equals),
            .comparision => @intFromEnum(Precedences.comparision),
            .sum => @intFromEnum(Precedences.sum),
            .product => @intFromEnum(Precedences.product),
            .prefix => @intFromEnum(Precedences.prefix),
            .call => @intFromEnum(Precedences.call),
            .index => @intFromEnum(Precedences.index),
        };
    }
};
pub const tokens = union(enum) {
    ident: []const u8,
    int: []const u8,
    string: []const u8,
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
    l_sq_bracket,
    r_sq_bracket,
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
    colon,
    while_loop,
    break_loop,
    continue_loop,
    pub fn stringValue(self: tokens, buf: *String) String.Error!void {
        switch (self) {
            .minus => try buf.concat("-"),
            .plus => try buf.concat("+"),
            .bang => try buf.concat("!"),
            .asterisk => try buf.concat("*"),
            .slash => try buf.concat("/"),
            .lesserThan => try buf.concat("<"),
            .greaterThan => try buf.concat(">"),
            .not_equal_to => try buf.concat("!="),
            .equal_to => try buf.concat("=="),
            .ident, .int, .string => |val| try buf.concat(val),
            .semicolon => try buf.concat(";"),
            .bool_true => try buf.concat("true"),
            .bool_false => try buf.concat("false"),
            .rparen => try buf.concat(")"),
            .lparen => try buf.concat("("),
            .lbrace => try buf.concat("{"),
            .rbrace => try buf.concat("}"),
            .if_stmt => try buf.concat("if"),
            .else_stmt => try buf.concat("else"),
            .function => try buf.concat("func"),
            .assign => try buf.concat("="),
            .l_sq_bracket => try buf.concat("["),
            .colon => try buf.concat(":"),
            .r_sq_bracket => try buf.concat("]"),
            .while_loop => try buf.concat("while"),
            .break_loop => try buf.concat("break"),
            .continue_loop => try buf.concat("continue"),
            else => {},
        }
    }
    pub fn toString(self: tokens) []const u8 {
        return switch (self) {
            .assign => "=",
            .plus => "+",
            .minus => "-",
            .bang => "!",
            .asterisk => "*",
            .slash => "/",
            .equal_to => "==",
            .not_equal_to => "!=",
            .lesserThan => "<",
            .greaterThan => ">",
            inline else => "invalid operator",
        };
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
            .lparen => Precedences.call.intVal(),
            .l_sq_bracket => Precedences.index.intVal(),
            else => Precedences.lowest.intVal(),
        };
    }
    pub fn isPrefix(self: tokens) bool {
        return switch (self) {
            .int,
            .ident,
            .minus,
            .bang,
            .bool_true,
            .bool_false,
            .lparen,
            .if_stmt,
            .function,
            .string,
            .l_sq_bracket,
            .lbrace,
            => true,
            else => false,
        };
    }
    pub fn getIdentValue(self: tokens) []const u8 {
        return switch (self) {
            .ident, .string => |val| val,
            else => "",
        };
    }
};

const keyWord = struct { key: []const u8, val: tokens };
pub const key_words = [_]keyWord{
    keyWord{ .key = "func", .val = .function },
    keyWord{ .key = "let", .val = .let },
    keyWord{ .key = "true", .val = .bool_true },
    keyWord{ .key = "false", .val = .bool_false },
    keyWord{ .key = "if", .val = .if_stmt },
    keyWord{ .key = "else", .val = .else_stmt },
    keyWord{ .key = "return", .val = .return_stmt },
    keyWord{ .key = "while", .val = .while_loop },
    keyWord{ .key = "break", .val = .break_loop },
    keyWord{ .key = "continue", .val = .continue_loop },
};

pub fn lookUpIdentifer(ident: []const u8) tokens {
    for (key_words) |pair| {
        if (std.mem.eql(u8, ident, pair.key)) {
            return pair.val;
        }
    }
    return .{ .ident = "" };
}
