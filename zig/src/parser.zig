const std = @import("std");
const print = @import("std").debug.print;
const ast = @import("./abstract_syntax_tree.zig");
const token = @import("./token.zig");
const lexer = @import("./lexer.zig");
const ParserError = error{ parseStatementIsUndefined, badStatement, expectedIdentifier, expectedAssign };
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
                    const stmt = self.parseStatement() catch |err| {
                        switch (err) {
                            ParserError.expectedAssign => {
                                print("{} expected assign found {}\n", .{ err, self.peekToken });
                                @panic("parserError:");
                            },
                            ParserError.expectedIdentifier => {
                                print("{} expected identifier found {}\n", .{ err, self.peekToken });
                                @panic("parserError:");
                            },
                            ParserError.badStatement => {
                                print("{} bad statement synatx \n", .{err});
                                @panic("parserError:");
                            },
                            else => @panic("parserError: unknown"),
                        }
                    };
                    try program.statements.append(stmt);
                },
            }
            self.nextToken();
        }
        return &program;
    }
    pub fn parseStatement(self: *Parser) ParserError!ast.Statement {
        return switch (self.curToken) {
            .let => {
                const letStmt = self.parseLetStatement() catch |err| return err;
                return .{ .let = letStmt };
            },
            .return_stmt => {
                const returnStatement = self.parseReturnStatement() catch |err| return err;
                return .{ .return_stmt = returnStatement };
            },
            else => ParserError.badStatement,
        };
    }
    pub fn parseReturnStatement(self: *Parser) ParserError!ast.ReturnStatement {
        var stmt = ast.ReturnStatement{};
        //remove after handling expression
        stmt.value = undefined;
        self.nextToken();
        while (true) {
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
    pub fn parseLetStatement(self: *Parser) ParserError!ast.LetStatement {
        var stmt = ast.LetStatement{};
        switch (self.peekToken) {
            .ident => |val| {
                self.nextToken();
                stmt.identifier = ast.Identifier{ .name = val };
            },
            else => return ParserError.expectedIdentifier,
        }
        switch (self.peekToken) {
            .assign => {
                self.nextToken();
            },
            else => return ParserError.expectedAssign,
        }
        while (true) {
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
};

pub fn newParser(alloc: *std.mem.Allocator, l: *lexer.Lexer) !*Parser {
    var p_ptr = try alloc.create(Parser);
    p_ptr.* = .{ .l = l, .allocator = alloc };
    p_ptr.nextToken();
    p_ptr.nextToken();
    return p_ptr;
}

test "Test let statements" {
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
    const tests = [_]ast.Identifier{ .{ .name = "five" }, .{ .name = "ten" } };
    for (tests, 0..) |value, index| {
        const stmt = program.statements.items[index];
        try std.testing.expectEqualDeep(stmt.let.identifier.name, value.name);
    }
}

test "Test return statements" {
    const input =
        \\return 100;
        \\return 9;
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const lex = try lexer.newLexer(&allocator, input);
    defer allocator.destroy(lex);
    var parser = try newParser(&allocator, lex);
    const program = try parser.parse();
    for (0..2) |index| {
        const stmt = program.statements.items[index];
        try std.testing.expect(@TypeOf(stmt.return_stmt) == ast.ReturnStatement);
    }
}
