const std = @import("std");
const print = std.debug.print;
const ast = @import("./abstract_syntax_tree.zig");
const token = @import("./token.zig");
const lexer = @import("./lexer.zig");
const Precedences = token.Precedences;
const tokens = token.tokens;

const ParserError = error{
    parseStatementIsUndefined,
    badStatement,
    expectedIdentifier,
    expectedAssign,
    parseIntError,
    OutOfMemory,
};

pub fn dbg(stmt: ast.Statement) void {
    std.debug.print("{}\n", .{stmt});
}

pub const Parser = struct {
    const Self = @This();
    l: *lexer.Lexer,
    allocator: *std.mem.Allocator,
    curToken: tokens = undefined,
    peekToken: tokens = undefined,
    pub fn nextToken(self: *Self) void {
        self.curToken = self.peekToken;
        self.peekToken = self.l.nextToken();
    }
    pub fn parse(self: *Self) !*ast.Program {
        var stmts = std.ArrayList(ast.Statement).init(self.allocator.*);
        defer stmts.deinit();
        var program = ast.Program{ .statements = stmts };
        while (@intFromEnum(self.curToken) != @intFromEnum(tokens.eof)) {
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
            self.nextToken();
        }
        return &program;
    }
    pub fn parseStatement(self: *Self) !ast.Statement {
        return switch (self.curToken) {
            .let => {
                const letStmt = self.parseLetStatement() catch |err| return err;
                return .{ .let = letStmt.* };
            },
            .return_stmt => {
                const returnStatement = self.parseReturnStatement() catch |err| return err;
                return .{ .return_stmt = returnStatement.* };
            },
            else => {
                const expStmt = self.parseExpressionStatement() catch |err| return err;
                return .{ .expression_stmt = expStmt.* };
            },
        };
    }

    pub fn parseReturnStatement(self: *Self) !*ast.ReturnStatement {
        const returnStatement = try self.allocator.create(ast.ReturnStatement);
        self.nextToken();
        while (@intFromEnum(self.curToken) != @intFromEnum(tokens.semicolon)) {
            self.nextToken();
        }
        return returnStatement;
    }

    pub fn parseLetStatement(self: *Self) !*ast.LetStatement {
        const letStmt = try self.allocator.create(ast.LetStatement);
        letStmt.value = ast.Expression{ .identifier = ast.Identifier{ .name = "tempval" } };
        switch (self.peekToken) {
            .ident => |val| {
                self.nextToken();
                letStmt.identifier = ast.Identifier{
                    .name = val,
                };
            },
            else => return ParserError.expectedIdentifier,
        }

        if (@intFromEnum(self.peekToken) == @intFromEnum(tokens.assign)) {
            self.nextToken();
        }
        while (@intFromEnum(self.curToken) != @intFromEnum(tokens.semicolon)) {
            self.nextToken();
        }
        return letStmt;
    }
    pub fn parseExpressionStatement(self: *Self) !*ast.ExpressionStatement {
        const expStmt = try self.allocator.create(ast.ExpressionStatement);
        expStmt.expression = try self.parseExpression(Precedences.lowest.intVal());
        if (@intFromEnum(self.peekToken) == @intFromEnum(tokens.semicolon)) {
            self.nextToken();
        }
        return expStmt;
    }
    pub fn parseExpression(self: *Self, precedence: i32) ParserError!ast.Expression {
        // std.debug.print("cur:{} peek:{} isCurPrexix:{}\n", .{
        //     self.curToken,
        //     self.peekToken,
        //     self.curToken.isPrefix(),
        // });
        var exp: ast.Expression = undefined;
        if (self.curToken.isPrefix()) {
            exp = try self.parsePrefixExpression();
        }
        // std.debug.print("({}!={}) and ({}<{})\n", .{
        //     @intFromEnum(self.curToken),
        //     @intFromEnum(tokens.semicolon),
        //     precedence,
        //     self.peekToken.precedence(),
        // });
        while (@intFromEnum(self.curToken) != @intFromEnum(tokens.semicolon) and
            precedence < self.peekToken.precedence())
        {
            self.nextToken();
            exp = try self.parseInfixExpression(exp);
        }
        return exp;
    }
    fn parsePrefixExpression(self: *Self) !ast.Expression {
        return switch (self.curToken) {
            .ident => |val| ast.Expression{ .identifier = ast.Identifier{ .name = val } },
            .int => |val| {
                const intVal = std.fmt.parseInt(i64, val, 10) catch |err| {
                    std.debug.print("Error parsing int: {}\n", .{err});
                    return ParserError.parseIntError;
                };
                const intExp = .{ .integer = ast.IntegerLiteral{ .value = intVal } };
                return intExp;
            },
            .minus, .bang => {
                const prefixExp = try self.allocator.create(ast.PrefixExpression);
                const op = self.curToken;
                self.nextToken();
                const rightExp = try self.allocator.create(ast.Expression);
                rightExp.* = try self.parseExpression(Precedences.prefix.intVal());

                prefixExp.* = ast.PrefixExpression{ .operator = op, .right = rightExp };

                return ast.Expression{ .prefix_exp = prefixExp.* };
            },
            else => @panic("prefix exp parsing"),
        };
    }
    fn parseInfixExpression(self: *Self, leftExp: ast.Expression) !ast.Expression {
        return switch (self.curToken) {
            .minus, .plus, .slash, .asterisk, .equal_to, .not_equal_to, .greaterThan, .lesserThan => {
                const infixExp = try self.allocator.create(ast.InfixExpression);
                const infixPrecedence = self.curToken.precedence();
                const op = self.curToken;
                self.nextToken();
                const rightExp = try self.allocator.create(ast.Expression);
                rightExp.* = try self.parseExpression(infixPrecedence);
                const left = try self.allocator.create(ast.Expression);
                left.* = leftExp;
                infixExp.* = ast.InfixExpression{
                    .operator = op,
                    .left = left,
                    .right = rightExp,
                };
                return ast.Expression{ .infix_exp = infixExp.* };
            },
            else => @panic("infix exp parsing"),
        };
    }
};

pub fn newParser(alloc: *std.mem.Allocator, l: *lexer.Lexer) !*Parser {
    var p_ptr = try alloc.create(Parser);
    p_ptr.* = .{ .l = l, .allocator = alloc };
    p_ptr.nextToken();
    p_ptr.nextToken();
    return p_ptr;
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
    //todo adjust this when implementing exp for let and return stmt
    const strings: [2][]const u8 = .{
        "let five = tempval;",
        "let ten = tempval;",
    };
    for (program.statements.items, 0..) |stmt, index| {
        var buf: [256]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{}", .{stmt});
        try std.testing.expect(std.mem.eql(u8, strings[index], str));
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
        var buf: [256]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{}", .{stmt});
        try std.testing.expect(std.mem.eql(u8, str, "rem"));
    }
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
        var buf: [256]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{}", .{stmt});
        try std.testing.expect(std.mem.eql(u8, str, "10"));
        try std.testing.expect(stmt.expression_stmt.expression.integer.value == 10);
    }
}

test "Test prefix Expression" {
    const input =
        \\ -10;
        \\!1;
    ;
    const testType = struct {
        ip: []const u8,
        op: []const u8,
        intval: i64,
    };
    const tests: [2]testType = .{
        testType{ .ip = "(-10)", .op = "-", .intval = 10 },
        testType{ .ip = "(!1)", .op = "!", .intval = 1 },
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const lex = try lexer.newLexer(&allocator, input);
    defer allocator.destroy(lex);
    var parser = try newParser(&allocator, lex);
    const program = try parser.parse();
    for (program.statements.items, 0..) |stmt, index| {
        const val = tests[index];
        var buf: [256]u8 = undefined;
        var buf2: [256]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{}", .{stmt});
        const opStr = try std.fmt.bufPrint(&buf2, "{}", .{stmt.expression_stmt.expression.prefix_exp.operator});
        try std.testing.expect(std.mem.eql(u8, str, val.ip));
        try std.testing.expect(std.mem.eql(u8, opStr, val.op));
        try std.testing.expect(stmt.expression_stmt.expression.prefix_exp.right.integer.value == val.intval);
    }
}

test "Test infix  Expression" {
    const input =
        \\5 + 5;
        \\5 - 5;
        \\5 * 5;
        \\5 / 5;
        \\5 > 5;
        \\5 < 5;
        \\5 == 5;
        \\5 != 5;
    ;
    const testType = struct {
        ip: []const u8,
        op: []const u8,
        right: i64 = 5,
        left: i64 = 5,
    };
    const tests: [8]testType = .{
        testType{ .ip = "(5 + 5)", .op = "+" },
        testType{ .ip = "(5 - 5)", .op = "-" },
        testType{ .ip = "(5 * 5)", .op = "*" },
        testType{ .ip = "(5 / 5)", .op = "/" },
        testType{ .ip = "(5 > 5)", .op = ">" },
        testType{ .ip = "(5 < 5)", .op = "<" },
        testType{ .ip = "(5 == 5)", .op = "==" },
        testType{ .ip = "(5 != 5)", .op = "!=" },
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const lex = try lexer.newLexer(&allocator, input);
    var parser = try newParser(&allocator, lex);
    const program = try parser.parse();
    for (program.statements.items, 0..) |stmt, index| {
        const val = tests[index];
        var buf: [256]u8 = undefined;
        var buf2: [256]u8 = undefined;
        const opStr = try std.fmt.bufPrint(&buf2, "{}", .{stmt.expression_stmt.expression.infix_exp.operator});
        const str = try std.fmt.bufPrint(&buf, "{}", .{stmt});
        try std.testing.expect(std.mem.eql(u8, str, val.ip));
        try std.testing.expect(std.mem.eql(u8, opStr, val.op));
        try std.testing.expect(stmt.expression_stmt.expression.infix_exp.right.integer.value == val.right);
        try std.testing.expect(stmt.expression_stmt.expression.infix_exp.left.integer.value == val.left);
    }
}

test "test a lot of expression combos" {
    const input =
        \\!-a;
        \\a + b + c;
        \\a + b - c;
        \\a * b * c;
        \\a * b / c;
        \\a + b / c;
        \\a + b * c + d / e - f;
        \\3 + 4;-5 * 5;
        \\5 > 4 == 3 < 4;
        \\5 < 4 != 3 > 4;
        \\3 + 4 * 5 == 3 * 1 + 4 * 5;
        \\3 + 4 * 5 == 3 * 1 + 4 * 5;
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const lex = try lexer.newLexer(&allocator, input);
    defer allocator.destroy(lex);
    var parser = try newParser(&allocator, lex);
    const program = try parser.parse();
    const strings: [13][]const u8 = .{
        "(!(-a))",
        "((a + b) + c)",
        "((a + b) - c)",
        "((a * b) * c)",
        "((a * b) / c)",
        "(a + (b / c))",
        "(((a + (b * c)) + (d / e)) - f)",
        "(3 + 4)",
        "((-5) * 5)",
        "((5 > 4) == (3 < 4))",
        "((5 < 4) != (3 > 4))",
        "((3 + (4 * 5)) == ((3 * 1) + (4 * 5)))",
        "((3 + (4 * 5)) == ((3 * 1) + (4 * 5)))",
    };
    for (program.statements.items, 0..) |stmt, index| {
        var buf: [256]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{}", .{stmt});
        try std.testing.expect(std.mem.eql(u8, strings[index], str));
    }
}
