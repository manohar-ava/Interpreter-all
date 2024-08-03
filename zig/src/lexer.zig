const std = @import("std");
const print = @import("std").debug.print;
const token = @import("./token.zig");

const Lexer = struct {
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

    fn nextToken(self: *Lexer) token.Token {
        try self.skipWhiteSpace();
        if (self.inputLen == self.position) {
            return newToken(.eof, "");
        }
        const char_as_string = [1]u8{self.ch};
        // print("{any} {any} {} {} char as string\n", .{ &char_as_string, self.ch, self.input.len, self.position });
        const result: token.Token = switch (self.ch) {
            '=' => newToken(.assign, &char_as_string),
            '+' => newToken(.plus, &char_as_string),
            '{' => newToken(.lbrace, &char_as_string),
            '}' => newToken(.rbrace, &char_as_string),
            '(' => newToken(.lparen, &char_as_string),
            ')' => newToken(.rparen, &char_as_string),
            ',' => newToken(.comma, &char_as_string),
            ';' => newToken(.semicolon, &char_as_string),
            else => {
                return if (isLetter(self.ch)) {
                    const ident = self.readIdentifier();
                    const newTok = newToken(token.lookUpIdentifer(ident), ident);
                    // print("{s} {s} {} ident \n", .{ ident, newTok.literal, newTok.type });
                    return newTok;
                } else if (isDigit(self.ch)) {
                    const newTok = newToken(.int, self.readNumber());
                    // print("{s} {} ident \n", .{ newTok.literal, newTok.type });
                    return newTok;
                } else {
                    return newToken(.illegal, &char_as_string);
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

fn newLexer(input: []const u8) Lexer {
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

fn newToken(tok: token.tokens, ch: []const u8) token.Token {
    return if (ch.len == 1)
        token.Token{ .literal = ch[0..1], .type = tok }
    else
        token.Token{ .literal = ch, .type = tok };
}

const tokenTuple = struct { token: token.tokens, value: []const u8 };

test "Test next tokens" {
    const input =
        \\let five = 5;
        \\let ten = 10;
        \\let add = func(x, y) {
        \\x + y;
        \\};
        \\let result = add(five, ten);
    ;

    const tests = [_]tokenTuple{
        .{ .token = .let, .value = "let" },
        .{ .token = .ident, .value = "five" },
        .{ .token = .assign, .value = "=" },
        .{ .token = .int, .value = "5" },
        .{ .token = .semicolon, .value = ";" },
        .{ .token = .let, .value = "let" },
        .{ .token = .ident, .value = "ten" },
        .{ .token = .assign, .value = "=" },
        .{ .token = .int, .value = "10" },
        .{ .token = .semicolon, .value = ";" },
        .{ .token = .let, .value = "let" },
        .{ .token = .ident, .value = "add" },
        .{ .token = .assign, .value = "=" },
        .{ .token = .function, .value = "func" },
        .{ .token = .lparen, .value = "(" },
        .{ .token = .ident, .value = "x" },
        .{ .token = .comma, .value = "," },
        .{ .token = .ident, .value = "y" },
        .{ .token = .rparen, .value = ")" },
        .{ .token = .lbrace, .value = "{" },
        .{ .token = .ident, .value = "x" },
        .{ .token = .plus, .value = "+" },
        .{ .token = .ident, .value = "y" },
        .{ .token = .semicolon, .value = ";" },
        .{ .token = .rbrace, .value = "}" },
        .{ .token = .semicolon, .value = ";" },
        .{ .token = .let, .value = "let" },
        .{ .token = .ident, .value = "result" },
        .{ .token = .assign, .value = "=" },
        .{ .token = .ident, .value = "add" },
        .{ .token = .lparen, .value = "(" },
        .{ .token = .ident, .value = "five" },
        .{ .token = .comma, .value = "," },
        .{ .token = .ident, .value = "ten" },
        .{ .token = .rparen, .value = ")" },
        .{ .token = .semicolon, .value = ";" },
        .{ .token = .eof, .value = "" },
    };
    var lex = newLexer(input);
    for (tests) |value| {
        const tok = lex.nextToken();
        print("{s} {} === {s} {}\n", .{ tok.literal, tok.type, value.value, value.token });
        try std.testing.expectEqualDeep(value.value, tok.literal);
        try std.testing.expectEqualDeep(value.token, tok.type);
    }
}
