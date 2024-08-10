const std = @import("std");
const print = @import("std").debug.print;
const ast = @import("./abstract_syntax_tree.zig");
const token = @import("./token.zig");
const lexer = @import("./lexer.zig");
const ParserError = error{parseStatementIsUndefined};
pub const Parser = struct {
    l: *lexer.Lexer,
    curToken: token.tokens = undefined,
    peekToken: token.tokens = undefined,
    allocator: *std.mem.Allocator,
    pub fn nextToken(self: *Parser) void {
        self.curToken = self.peekToken;
        self.peekToken = self.l.nextToken();
    }
    pub fn parse(self: *Parser) !*ast.Program {
        var stmts = std.ArrayList(ast.Statement).init(self.allocator.*);
        defer stmts.deinit();
        var program = ast.Program{ .statements = stmts };
        while (true) {
            switch (self.curToken) {
                .eof => {
                    break;
                },
                else => {
                    const stmt = self.parseStatement();
                    try program.statements.append(stmt);
                },
            }
            self.nextToken();
        }
        return &program;
    }
    pub fn parseStatement(self: *Parser) ast.Statement {
        return switch (self.curToken) {
            .let => {
                const letStmt = self.parseLetStatement();
                // print("{any} let smt\n\n", .{letStmt});
                return .{ .let = letStmt };
            },
            else => unreachable,
        };
    }
    pub fn parseLetStatement(self: *Parser) ast.LetStatement {
        var stmt = ast.LetStatement{};
        switch (self.peekToken) {
            .ident => |val| {
                self.nextToken();
                stmt.identifier = ast.Identifier{ .name = val };
            },
            else => unreachable,
        }
        switch (self.peekToken) {
            .assign => {
                self.nextToken();
            },
            else => unreachable,
        }
        // print("c - {} p - {}\n\n ", .{ self.curToken, self.peekToken });
        while (true) {
            // print("c - {} p - {} in loop\n\n ", .{ self.curToken, self.peekToken });
            switch (self.curToken) {
                .semicolon => {
                    break;
                },
                else => {
                    self.nextToken();
                },
            }
        }
        return stmt;
    }
    pub fn dinit() void {}
};

pub fn newParser(alloc: *std.mem.Allocator, l: *lexer.Lexer) !*Parser {
    var p_ptr = try alloc.create(Parser);
    p_ptr.* = .{ .l = l, .allocator = alloc };
    p_ptr.nextToken();
    p_ptr.nextToken();
    return p_ptr;
}

test "Test next tokens" {
    const input =
        \\let five = 5;
        \\let ten = 10;
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const lex = try lexer.newLexer(&allocator, input);
    defer allocator.destroy(lex);
    var parser = try newParser(&allocator, lex);
    const program = try parser.parse();
    const stmts = try program.statements.toOwnedSlice();
    const tests = [_]ast.Identifier{ .{ .name = "five" }, .{ .name = "ten" } };
    for (tests, 0..) |value, index| {
        const stmt = stmts[index];
        try std.testing.expectEqualDeep(stmt.let.identifier.name, value.name);
    }
}
