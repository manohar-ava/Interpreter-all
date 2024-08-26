const std = @import("std");
const print = std.debug.print;
const ast = @import("./abstract_syntax_tree.zig");
const token = @import("./token.zig");
const lexer = @import("./lexer.zig");
const Precedences = token.Precedences;
const tokens = token.tokens;

const ParserError = error{
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
    errors: std.ArrayList([]const u8),
    pub fn nextToken(self: *Self) void {
        self.curToken = self.peekToken;
        self.peekToken = self.l.nextToken();
    }
    fn isPeekToken(self: *Self, tok: tokens) bool {
        return @intFromEnum(self.peekToken) == @intFromEnum(tok);
    }
    fn isCurToken(self: *Self, tok: tokens) bool {
        return @intFromEnum(self.curToken) == @intFromEnum(tok);
    }
    fn appendPeekError(self: *Self, tok: tokens) !void {
        const str = try std.fmt.allocPrint(self.allocator.*, "expected token {} but found {}", .{
            tok,
            self.peekToken,
        });
        // defer self.allocator.free(str);
        try self.errors.append(str);
    }
    pub fn printErrors(self: *Self) bool {
        if (self.errors.items.len == 0) {
            return false;
        }
        for (self.errors.items) |stmt| {
            std.debug.print("ParserError: {s}\n", .{stmt});
        }
        return true;
    }
    pub fn parse(self: *Self) !*ast.Program {
        var stmts = std.ArrayList(ast.Statement).init(self.allocator.*);
        defer stmts.deinit();
        var program = ast.Program{ .statements = stmts };
        while (!self.isCurToken(tokens.eof)) {
            const stmt = try self.parseStatement();
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
        returnStatement.value = try self.parseExpression(Precedences.lowest.intVal());
        if (self.isPeekToken(tokens.semicolon)) {
            self.nextToken();
        }
        return returnStatement;
    }

    pub fn parseLetStatement(self: *Self) !*ast.LetStatement {
        const letStmt = try self.allocator.create(ast.LetStatement);
        switch (self.peekToken) {
            .ident => |val| {
                self.nextToken();
                letStmt.identifier = ast.Identifier{
                    .name = val,
                };
            },
            else => {
                try self.appendPeekError(tokens{ .ident = "identifier" });
            },
        }
        if (!self.isPeekToken(tokens.assign)) {
            try self.appendPeekError(tokens.assign);
        }
        self.nextToken(); // jump to =
        self.nextToken(); // jump to expression token
        letStmt.value = try self.parseExpression(Precedences.lowest.intVal());
        if (self.isPeekToken(tokens.semicolon)) {
            self.nextToken();
        }
        return letStmt;
    }
    pub fn parseExpressionStatement(self: *Self) !*ast.ExpressionStatement {
        const expStmt = try self.allocator.create(ast.ExpressionStatement);
        expStmt.expression = try self.parseExpression(Precedences.lowest.intVal());
        if (self.isPeekToken(tokens.semicolon)) {
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
        // std.debug.print("({}!={}) and ({}<{}) \n", .{
        //     @intFromEnum(self.curToken),
        //     @intFromEnum(tokens.semicolon),
        //     precedence,
        //     self.peekToken.precedence(),
        // });
        while (!self.isCurToken(tokens.semicolon) and
            precedence < self.peekToken.precedence())
        {
            self.nextToken();
            exp = try self.parseInfixExpression(exp);
        }
        return exp;
    }
    fn parsePrefixExpression(self: *Self) !ast.Expression {
        return switch (self.curToken) {
            .ident => ast.Expression{ .identifier = ast.Identifier{ .name = self.curToken.getIdentValue() } },
            .bool_true, .bool_false => ast.Expression{
                .boolean_exp = ast.BooleanExpression{ .value = self.isCurToken(tokens.bool_true) },
            },
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
            .lparen => {
                self.nextToken();
                const exp = try self.allocator.create(ast.Expression);
                exp.* = try self.parseExpression(Precedences.lowest.intVal());
                if (!self.isPeekToken(tokens.rparen)) {
                    try self.appendPeekError(tokens.rparen);
                }
                self.nextToken();
                return exp.*;
            },
            .if_stmt => {
                const ifExp = try self.allocator.create(ast.IfExpression);
                if (!self.isPeekToken(tokens.lparen)) {
                    try self.appendPeekError(tokens.lparen);
                }
                self.nextToken();
                self.nextToken();
                const conditionExp = try self.allocator.create(ast.Expression);
                conditionExp.* = try self.parseExpression(Precedences.lowest.intVal());
                if (!self.isPeekToken(tokens.rparen)) {
                    try self.appendPeekError(tokens.rparen);
                }
                self.nextToken();
                if (!self.isPeekToken(tokens.lbrace)) {
                    try self.appendPeekError(tokens.lbrace);
                }
                self.nextToken();

                const ifConsequence = try self.allocator.create(ast.BlockStatement);
                ifConsequence.* = try self.parseBlockStatement();

                ifExp.* = ast.IfExpression{
                    .condition = conditionExp,
                    .consequence = ifConsequence,
                    .alternative = null,
                };

                if (self.isPeekToken(tokens.else_stmt)) {
                    self.nextToken();

                    if (!self.isPeekToken(tokens.lbrace)) {
                        try self.appendPeekError(tokens.lbrace);
                    }
                    self.nextToken();
                    const ifAlternative = try self.allocator.create(ast.BlockStatement);
                    ifAlternative.* = try self.parseBlockStatement();
                    ifExp.alternative = ifAlternative;
                }

                return ast.Expression{ .if_exp = ifExp.* };
            },
            .function => {
                const func = try self.allocator.create(ast.FunctionLiteral);
                func.token = self.curToken;
                if (!self.isPeekToken(tokens.lparen)) {
                    try self.appendPeekError(tokens.lparen);
                }
                self.nextToken();
                const parameters = try self.parseFunctionParameters();
                func.parameters = parameters;
                if (!self.isPeekToken(tokens.lbrace)) {
                    try self.appendPeekError(tokens.lbrace);
                }
                self.nextToken();
                const body = try self.allocator.create(ast.BlockStatement);
                body.* = try self.parseBlockStatement();

                func.body = body;
                return ast.Expression{ .fn_literal = func.* };
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
            .lparen => {
                const callExpression = try self.allocator.create(ast.CallExpressin);
                const function = try self.allocator.create(ast.Expression);
                function.* = leftExp;
                callExpression.arguments = try self.parseArguments();
                callExpression.function = function;
                return ast.Expression{ .call_exp = callExpression.* };
            },
            else => @panic("infix exp parsing"),
        };
    }
    fn parseBlockStatement(self: *Self) !ast.BlockStatement {
        var stmts = std.ArrayList(ast.Statement).init(self.allocator.*);
        self.nextToken();
        while (!self.isCurToken(tokens.rbrace) and !self.isCurToken(tokens.eof)) {
            const parsedStmt = try self.parseStatement();
            try stmts.append(parsedStmt);
            self.nextToken();
        }
        return ast.BlockStatement{ .statements = stmts };
    }
    fn parseFunctionParameters(self: *Self) !std.ArrayList(ast.Identifier) {
        var params = std.ArrayList(ast.Identifier).init(self.allocator.*);
        if (self.isPeekToken(tokens.rparen)) {
            self.nextToken();
            return params;
        }
        self.nextToken();
        try params.append(ast.Identifier{ .name = self.curToken.getIdentValue() });
        while (self.isPeekToken(tokens.comma)) {
            self.nextToken(); // jump current ident
            self.nextToken(); // jump comma
            try params.append(ast.Identifier{ .name = self.curToken.getIdentValue() });
        }
        if (!self.isPeekToken(tokens.rparen)) {
            try self.appendPeekError(tokens.rparen);
        }
        self.nextToken();
        return params;
    }
    fn parseArguments(self: *Self) !std.ArrayList(ast.Expression) {
        var args = std.ArrayList(ast.Expression).init(self.allocator.*);
        if (self.isPeekToken(tokens.rparen)) {
            self.nextToken();
            return args;
        }
        self.nextToken();
        try args.append(try self.parseExpression(Precedences.lowest.intVal()));
        while (self.isPeekToken(tokens.comma)) {
            self.nextToken(); // jump current ident
            self.nextToken(); // jump comma
            try args.append(try self.parseExpression(Precedences.lowest.intVal()));
        }
        if (!self.isPeekToken(tokens.rparen)) {
            try self.appendPeekError(tokens.rparen);
        }
        self.nextToken();
        return args;
    }
};

pub fn newParser(alloc: *std.mem.Allocator, l: *lexer.Lexer) !*Parser {
    var p_ptr = try alloc.create(Parser);
    const errors = std.ArrayList([]const u8).init(alloc.*);
    p_ptr.* = .{ .l = l, .allocator = alloc, .errors = errors };
    p_ptr.nextToken();
    p_ptr.nextToken();
    return p_ptr;
}
test "test function literal" {
    const input =
        \\func(a) { x };
        \\func(a,b) { x + y };
        \\func(a,b,c) { true == true };
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const lex = try lexer.newLexer(&allocator, input);
    defer allocator.destroy(lex);
    var parser = try newParser(&allocator, lex);
    const program = try parser.parse();
    const strings: [3][]const u8 = .{
        "func(a){x}",
        "func(a,b){(x + y)}",
        "func(a,b,c){(true == true)}",
    };
    for (program.statements.items, 0..) |stmt, index| {
        var buf: [256]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{}", .{stmt});
        try std.testing.expect(std.mem.eql(u8, strings[index], str));
    }
}

test "test if-else expression" {
    const input =
        \\if (a > b) { x };
        \\if (a > b) { x } else { z };
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const lex = try lexer.newLexer(&allocator, input);
    defer allocator.destroy(lex);
    var parser = try newParser(&allocator, lex);
    const program = try parser.parse();
    const strings: [2][]const u8 = .{
        "if(a > b) {x}",
        "if(a > b) {x} else {z}",
    };
    for (program.statements.items, 0..) |stmt, index| {
        var buf: [256]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{}", .{stmt});
        try std.testing.expect(std.mem.eql(u8, strings[index], str));
    }
}

test "test grouped expression" {
    const input =
        \\1 + (2 + 3) + 4;
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const lex = try lexer.newLexer(&allocator, input);
    defer allocator.destroy(lex);
    var parser = try newParser(&allocator, lex);
    const program = try parser.parse();
    const strings: [1][]const u8 = .{
        "((1 + (2 + 3)) + 4)",
    };
    for (program.statements.items, 0..) |stmt, index| {
        var buf: [256]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{}", .{stmt});
        try std.testing.expect(std.mem.eql(u8, strings[index], str));
    }
}

test "Test let statements with expression" {
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
        "let five = ten",
        "let ten = five",
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
    const strings: [2][]const u8 = .{
        "return 100",
        "return 9",
    };
    for (program.statements.items, 0..) |stmt, index| {
        var buf: [256]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{}", .{stmt});
        try std.testing.expect(std.mem.eql(u8, strings[index], str));
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

test "test a lot of expression combos and function callExpression" {
    const input =
        \\!-a;
        \\a + add(b * d) + c;
        \\a + sub(10, 5) - c;
        \\add(1,a,x+y,sub(a,b,x+y))
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
        "((a + add((b * d))) + c)",
        "((a + sub(10,5)) - c)",
        "add(1,a,(x + y),sub(a,b,(x + y)))",
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

test "test boolean expression" {
    const input =
        \\true;
        \\!true
        \\false;
        \\!false;
        \\true == true;
        \\false != true;
        \\false == false;
        \\3 < 4 == true;
        \\4 > 10 == false;
        \\1 != 1 == false;
    ;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const lex = try lexer.newLexer(&allocator, input);
    defer allocator.destroy(lex);
    var parser = try newParser(&allocator, lex);
    const program = try parser.parse();
    const strings: [10][]const u8 = .{
        "true",
        "(!true)",
        "false",
        "(!false)",
        "(true == true)",
        "(false != true)",
        "(false == false)",
        "((3 < 4) == true)",
        "((4 > 10) == false)",
        "((1 != 1) == false)",
    };
    for (program.statements.items, 0..) |stmt, index| {
        var buf: [256]u8 = undefined;
        const str = try std.fmt.bufPrint(&buf, "{}", .{stmt});
        try std.testing.expect(std.mem.eql(u8, strings[index], str));
    }
}
