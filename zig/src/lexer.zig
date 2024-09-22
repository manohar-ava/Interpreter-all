const std = @import("std");
const print = std.debug.print;
const token = @import("./token.zig");

pub const Lexer = struct {
    input: []const u8,
    position: usize = 0,
    readPosition: usize = 0,
    inputLen: usize = 0,
    ch: u8 = undefined,
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
            ']' => .r_sq_bracket,
            '[' => .l_sq_bracket,
            ':' => .colon,
            '"' => {
                const stringToken = token.tokens{ .string = self.readString() };
                try self.readChar();
                return stringToken;
            },
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
    fn readString(self: *Lexer) []const u8 {
        const pos = self.position + 1;
        try self.readChar();
        while (self.ch != '"') {
            try self.readChar();
        }
        return self.input[pos..self.position];
    }
    fn skipWhiteSpace(self: *Lexer) !void {
        while (true) {
            switch (self.ch) {
                '\t', '\n', '\x0C', '\r', ' ' => {
                    try self.readChar();
                },
                else => {
                    break;
                },
            }
        }
    }
};

pub fn newLexer(alloc: *std.mem.Allocator, input: []const u8) !*Lexer {
    var lex_ptr = try alloc.create(Lexer);
    lex_ptr.* = .{ .input = input, .inputLen = input.len };
    try lex_ptr.readChar();
    return lex_ptr;
}

fn isLetter(ch: u8) bool {
    return std.ascii.isAlphabetic(ch);
}

fn isDigit(ch: u8) bool {
    return std.ascii.isDigit(ch);
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
        \\"lol"
        \\"praise the lord"
        \\[1,true]
        \\{"key":"value"}
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
        .{ .string = "lol" },
        .{ .string = "praise the lord" },
        .l_sq_bracket,
        .{ .int = "1" },
        .comma,
        .bool_true,
        .r_sq_bracket,
        .lbrace,
        .{ .string = "key" },
        .colon,
        .{ .string = "value" },
        .rbrace,
        .eof,
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    var lex = try newLexer(&allocator, input);
    defer allocator.destroy(lex);
    for (tests) |value| {
        const tok = lex.nextToken();
        try std.testing.expectEqualDeep(value, tok);
    }
}
