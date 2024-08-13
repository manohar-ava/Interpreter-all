const std = @import("std");
const print = std.debug.print;
const ast = @import("./abstract_syntax_tree.zig");
const token = @import("./token.zig");
const lexer = @import("./lexer.zig");

const ParserError = error{ parseStatementIsUndefined, badStatement, expectedIdentifier, expectedAssign, parseIntError };

const ParserFunctions = union(enum) { prefixFn: fn () ast.Expression, infixFn: fn (ast.Expression) ast.Expression };

const Precedences = enum { lowest, equals, comparision, sum, product, prefix, call };

pub const Parser = struct {
    const Self = @This();
    l: *lexer.Lexer,
    allocator: *std.mem.Allocator,
    curToken: token.tokens = undefined,
    peekToken: token.tokens = undefined,
    pub fn nextToken(self: *Self) void {
        self.curToken = self.peekToken;
        self.peekToken = self.l.nextToken();
    }
    pub fn parse(self: *Self) !*ast.Program {
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
    pub fn parseStatement(self: *Self) ParserError!ast.Statement {
        return switch (self.curToken) {
            .let => {
                const letStmt = self.parseLetStatement() catch |err| return err;
                return .{ .let = letStmt };
            },
            .return_stmt => {
                const returnStatement = self.parseReturnStatement() catch |err| return err;
                return .{ .return_stmt = returnStatement };
            },
            else => {
                const expStmt = self.parseExpressionStatement() catch |err| return err;
                return .{ .expression_stmt = expStmt };
            },
        };
    }
    pub fn parseReturnStatement(self: *Self) ParserError!ast.ReturnStatement {
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
    pub fn parseLetStatement(self: *Self) ParserError!ast.LetStatement {
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
    pub fn parseExpressionStatement(self: *Self) !ast.ExpressionStatement {
        var stmt = ast.ExpressionStatement{ .token = self.curToken };
        stmt.expression = try self.parseExpression(Precedences.lowest);
        if (@intFromEnum(self.peekToken) == @intFromEnum(token.tokens.semicolon)) {
            self.nextToken();
        }
        return stmt;
    }
    pub fn parseExpression(self: *Self, precedence: Precedences) !ast.Expression {
        print("Precedences to int {}\n", .{@intFromEnum(precedence)});
        switch (self.curToken) {
            .ident => |val| {
                return .{ .identifier = ast.Identifier{ .name = val } };
            },
            .int => |val| {
                const intVal = std.fmt.parseInt(i64, val, 10) catch |err| {
                    std.debug.print("Error parsing int: {}\n", .{err});
                    return ParserError.parseIntError;
                };
                return .{ .integer = ast.IntegerLiteral{ .value = intVal } };
            },
            else => unreachable,
        }
    }
};

pub fn newParser(alloc: *std.mem.Allocator, l: *lexer.Lexer) !*Parser {
    var p_ptr = try alloc.create(Parser);
    p_ptr.* = .{ .l = l, .allocator = alloc };
    p_ptr.nextToken();
    p_ptr.nextToken();
    return p_ptr;
}

test "Test integer Expression" {
    const input = "10;";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const lex = try lexer.newLexer(&allocator, input);
    defer allocator.destroy(lex);
    var parser = try newParser(&allocator, lex);
    const program = try parser.parse();
    for (program.statements.items) |stmt| {
        try std.testing.expect(stmt.expression_stmt.expression.integer.value == 10);
    }
}
test "Test Expression" {
    const input = "rem;";
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const lex = try lexer.newLexer(&allocator, input);
    defer allocator.destroy(lex);
    var parser = try newParser(&allocator, lex);
    const program = try parser.parse();
    for (program.statements.items) |stmt| {
        try std.testing.expect(std.mem.eql(u8, stmt.expression_stmt.expression.identifier.name, "rem"));
    }
}

test "Test let statements without expression" {
    const input =
        \\let five = ten;
        \\let ten = five;
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const lex = try lexer.newLexer(&allocator, input);
    defer allocator.destroy(lex);
    var parser = try newParser(&allocator, lex);
    const program = try parser.parse();
    const strings: [2][]const u8 = .{
        "let five = ;",
        "let ten = ;",
    };
    for (program.statements.items, 0..) |stmt, index| {
        var str = std.ArrayList(u8).init(allocator);
        defer str.deinit();
        try stmt.string(&str);
        const val = try str.toOwnedSlice();
        try std.testing.expect(std.mem.eql(u8, strings[index], val));
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
