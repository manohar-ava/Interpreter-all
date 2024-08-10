const std = @import("std");
const print = @import("std").debug.print;
const token = @import("./token.zig");

pub const Lexer = struct {
    input: []const u8,
    position: usize,
    readPosition: usize,
    inputLen: usize,
    ch: u8,
    fn readChar(self: *Lexer) !void {
        if (self.readPosition >= self.input.len) {
            self.ch = undefined;
        } else {
            self.ch = self.input[self.readPosition];
        }
        self.position = self.readPosition;
        self.readPosition += 1;
        // print("|{c}|{}|{}|\n", .{ self.ch, self.readPosition, self.position });
    }
    fn peekChar(self: *Lexer) u8 {
        return if (self.readPosition >= self.inputLen)
            undefined
        else
            self.input[self.readPosition];
    }
    pub fn hasTokens(self: *Lexer) bool {
        return self.readPosition <= self.inputLen;
    }

    pub fn nextToken(self: *Lexer) token.tokens {
        try self.skipWhiteSpace();
        if (self.inputLen == self.position) {
            return .eof;
        }
        const result: token.tokens = switch (self.ch) {
            '=' => b: {
                if (self.peekChar() == '=') {
                    try self.readChar();
                    break :b .equal_to;
                } else {
                    break :b .assign;
                }
            },
            '+' => .plus,
            '{' => .lbrace,
            '}' => .rbrace,
            '(' => .lparen,
            ')' => .rparen,
            ',' => .comma,
            ';' => .semicolon,
            '!' => b: {
                if (self.peekChar() == '=') {
                    try self.readChar();
                    break :b .not_equal_to;
                } else {
                    break :b .bang;
                }
            },
            '-' => .minus,
            '/' => .slash,
            '*' => .asterisk,
            '<' => .lesserThan,
            '>' => .greaterThan,
            else => {
                return if (isLetter(self.ch)) {
                    const ident = self.readIdentifier();
                    const identType = token.lookUpIdentifer(ident);
                    return switch (identType) {
                        .ident => .{ .ident = ident },
                        else => identType,
                    };
                } else if (isDigit(self.ch)) {
                    return .{ .int = self.readNumber() };
                } else {
                    return .illegal;
                };
            },
        };
        try self.readChar();
        return result;
    }
    fn readNumber(self: *Lexer) []const u8 {
        const pos = self.position;
        while (isDigit(self.ch)) {
            try self.readChar();
        }
        return self.input[pos..self.position];
    }
    fn readIdentifier(self: *Lexer) []const u8 {
        const pos = self.position;
        while (isLetter(self.ch)) {
            try self.readChar();
        }
        return self.input[pos..self.position];
    }
    fn skipWhiteSpace(self: *Lexer) !void {
        if (self.ch == ' ' or self.ch == '\n' or self.ch == '\r' or self.ch == '\t') {
            try self.readChar();
        }
    }
};

pub fn newLexer(input: []const u8) Lexer {
    var l = Lexer{ .input = input, .inputLen = input.len, .ch = undefined, .position = 0, .readPosition = 0 };
    try l.readChar();
    return l;
}

fn isLetter(ch: u8) bool {
    return if ((ch >= 97 and ch <= 122) or (ch >= 65 and ch <= 90)) true else false;
}

fn isDigit(ch: u8) bool {
    return if (ch >= 48 and ch <= 57) true else false;
}

test "Test next tokens" {
    const input =
        \\let five = 5;
        \\let ten = 10;
        \\let add = func(x, y) {
        \\x + y;
        \\};
        \\let result = add(five, ten);
        \\!-/*5;
        \\5 < 10 > 5;
        \\if(1 > 0){
        \\return true;
        \\}
        \\else{
        \\return false;
        \\}
        \\1 == 1;
        \\1 != 0;
    ;

    const tests = [_]token.tokens{
        .let,
        .{ .ident = "five" },
        .assign,
        .{ .int = "5" },
        .semicolon,
        .let,
        .{ .ident = "ten" },
        .assign,
        .{ .int = "10" },
        .semicolon,
        .let,
        .{ .ident = "add" },
        .assign,
        .function,
        .lparen,
        .{ .ident = "x" },
        .comma,
        .{ .ident = "y" },
        .rparen,
        .lbrace,
        .{ .ident = "x" },
        .plus,
        .{ .ident = "y" },
        .semicolon,
        .rbrace,
        .semicolon,
        .let,
        .{ .ident = "result" },
        .assign,
        .{ .ident = "add" },
        .lparen,
        .{ .ident = "five" },
        .comma,
        .{ .ident = "ten" },
        .rparen,
        .semicolon,
        .bang,
        .minus,
        .slash,
        .asterisk,
        .{ .int = "5" },
        .semicolon,
        .{ .int = "5" },
        .lesserThan,
        .{ .int = "10" },
        .greaterThan,
        .{ .int = "5" },
        .semicolon,
        .if_stmt,
        .lparen,
        .{ .int = "1" },
        .greaterThan,
        .{ .int = "0" },
        .rparen,
        .lbrace,
        .return_stmt,
        .bool_true,
        .semicolon,
        .rbrace,
        .else_stmt,
        .lbrace,
        .return_stmt,
        .bool_false,
        .semicolon,
        .rbrace,
        .{ .int = "1" },
        .equal_to,
        .{ .int = "1" },
        .semicolon,
        .{ .int = "1" },
        .not_equal_to,
        .{ .int = "0" },
        .semicolon,
        .eof,
    };
    var lex = newLexer(input);
    for (tests) |value| {
        const tok = lex.nextToken();
        // print(" {} {} \n", .{ value, tok });
        try std.testing.expectEqualDeep(value, tok);
    }
}
