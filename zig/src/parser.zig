const std = @import("std");
const print = std.debug.print;
const ast = @import("./abstract_syntax_tree.zig");
const token = @import("./token.zig");
const lexer = @import("./lexer.zig");
const Precedences = token.Precedences;
const String = @import("string.zig").String;
const tokens = token.tokens;

const ParserError = error{
    parseIntError,
    OutOfMemory,
};

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
    pub fn parse(self: *Self) anyerror!ast.Program {
        var stmts = std.ArrayList(ast.Statement).init(self.allocator.*);
        while (!self.isCurToken(tokens.eof)) {
            const stmt = try self.parseStatement();
            try stmts.append(stmt);
            self.nextToken();
        }
        return ast.Program{ .statements = stmts };
    }
    pub fn parseStatement(self: *Self) anyerror!ast.Statement {
        return switch (self.curToken) {
            .let => .{ .let = try self.parseLetStatement() },
            .return_stmt => .{ .return_stmt = try self.parseReturnStatement() },
            else => return .{ .expression_stmt = try self.parseExpressionStatement() },
        };
    }

    pub fn parseReturnStatement(self: *Self) !ast.ReturnStatement {
        self.nextToken();
        const returnValPtr = try self.allocator.create(ast.Expression);
        returnValPtr.* = try self.parseExpression(Precedences.lowest.intVal());
        if (self.isPeekToken(tokens.semicolon)) {
            self.nextToken();
        }
        return ast.ReturnStatement{ .value = returnValPtr };
    }

    pub fn parseLetStatement(self: *Self) !ast.LetStatement {
        var ident: ast.Identifier = undefined;
        switch (self.peekToken) {
            .ident => |val| {
                self.nextToken();
                ident = ast.Identifier{
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
        const expr = try self.allocator.create(ast.Expression);
        expr.* = try self.parseExpression(Precedences.lowest.intVal());
        if (self.isPeekToken(tokens.semicolon)) {
            self.nextToken();
        }
        return ast.LetStatement{ .value = expr, .identifier = ident };
    }
    pub fn parseExpressionStatement(self: *Self) !ast.ExpressionStatement {
        const exp = try self.allocator.create(ast.Expression);
        exp.* = try self.parseExpression(Precedences.lowest.intVal());
        if (self.isPeekToken(tokens.semicolon)) {
            self.nextToken();
        }
        return ast.ExpressionStatement{ .expression = exp };
    }
    pub fn parseExpression(self: *Self, precedence: i32) anyerror!ast.Expression {
        var exp: ast.Expression = undefined;
        if (self.curToken.isPrefix()) {
            exp = try self.parsePrefixExpression();
        }
        while (!self.isCurToken(tokens.semicolon) and
            precedence < self.peekToken.precedence())
        {
            self.nextToken();
            const leftExpPtr = try self.allocator.create(ast.Expression);
            leftExpPtr.* = exp;
            exp = try self.parseInfixExpression(leftExpPtr);
        }
        return exp;
    }
    fn parsePrefixExpression(self: *Self) !ast.Expression {
        return switch (self.curToken) {
            .ident => ast.Expression{ .identifier = ast.Identifier{ .name = self.curToken.getIdentValue() } },
            .string => |val| ast.Expression{ .string_literal = ast.StringLiteral{ .value = val } },
            .bool_true, .bool_false => ast.Expression{
                .boolean_exp = ast.BooleanExpression{ .value = self.isCurToken(tokens.bool_true) },
            },
            .int => |val| {
                const intVal = std.fmt.parseInt(i64, val, 10) catch |err| {
                    std.debug.print("Error parsing int: {}\n", .{err});
                    return ParserError.parseIntError;
                };
                return ast.Expression{ .integer = ast.IntegerLiteral{ .value = intVal } };
            },
            .minus, .bang => {
                const op = self.curToken;
                self.nextToken();
                const rightExp = try self.allocator.create(ast.Expression);
                rightExp.* = try self.parseExpression(Precedences.prefix.intVal());
                return ast.Expression{
                    .prefix_exp = ast.PrefixExpression{ .right = rightExp, .operator = op },
                };
            },
            .lparen => {
                self.nextToken();
                const exp = try self.parseExpression(Precedences.lowest.intVal());
                if (!self.isPeekToken(tokens.rparen)) {
                    try self.appendPeekError(tokens.rparen);
                }
                self.nextToken();
                return exp;
            },
            .if_stmt => {
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

                const ifConsequence = try self.parseBlockStatement();
                var elseBlock: ?ast.BlockStatement = null;

                if (self.isPeekToken(tokens.else_stmt)) {
                    self.nextToken();

                    if (!self.isPeekToken(tokens.lbrace)) {
                        try self.appendPeekError(tokens.lbrace);
                    }
                    self.nextToken();
                    elseBlock = try self.parseBlockStatement();
                }

                return ast.Expression{ .if_exp = .{
                    .condition = conditionExp,
                    .consequence = ifConsequence,
                    .alternative = elseBlock,
                } };
            },
            .function => {
                if (!self.isPeekToken(tokens.lparen)) {
                    try self.appendPeekError(tokens.lparen);
                }
                self.nextToken();
                const parameters = try self.parseFunctionParameters();
                if (!self.isPeekToken(tokens.lbrace)) {
                    try self.appendPeekError(tokens.lbrace);
                }
                self.nextToken();
                const body = try self.parseBlockStatement();
                return ast.Expression{ .fn_literal = .{
                    .body = body,
                    .parameters = parameters,
                } };
            },
            .l_sq_bracket => ast.Expression{ .array_literal = .{
                .elements = try self.parseArguments(.r_sq_bracket),
            } },
            .lbrace => {
                var pairs = std.ArrayList(ast.HashPair).init(self.allocator.*);
                while (!self.isPeekToken(tokens.rbrace)) {
                    self.nextToken();
                    const key = try self.parseExpression(Precedences.lowest.intVal());
                    if (!self.isPeekToken(tokens.colon)) {
                        try self.appendPeekError(tokens.colon);
                    }
                    if (self.isCurToken(tokens.eof)) {
                        break;
                    }
                    self.nextToken();
                    self.nextToken();
                    const value = try self.parseExpression(Precedences.lowest.intVal());
                    try pairs.append(.{ .key = key, .value = value });
                    if (!self.isPeekToken(tokens.rbrace)) {
                        if (!self.isPeekToken(tokens.comma)) {
                            try self.appendPeekError(tokens.comma);
                        }
                        self.nextToken();
                    }
                }
                if (!self.isPeekToken(tokens.rbrace)) {
                    try self.appendPeekError(tokens.rbrace);
                }
                self.nextToken();
                return ast.Expression{ .hash_literal = .{ .pairs = pairs } };
            },
            else => @panic("prefix exp parsing"),
        };
    }
    fn parseInfixExpression(self: *Self, leftExp: *ast.Expression) !ast.Expression {
        return switch (self.curToken) {
            .minus, .plus, .slash, .asterisk, .equal_to, .not_equal_to, .greaterThan, .lesserThan => {
                const infixPrecedence = self.curToken.precedence();
                const op = self.curToken;
                self.nextToken();
                const rightExp = try self.allocator.create(ast.Expression);
                rightExp.* = try self.parseExpression(infixPrecedence);
                return ast.Expression{ .infix_exp = ast.InfixExpression{
                    .operator = op,
                    .left = leftExp,
                    .right = rightExp,
                } };
            },
            .lparen => ast.Expression{ .call_exp = .{
                .function = leftExp,
                .arguments = try self.parseArguments(.rparen),
            } },
            .l_sq_bracket => {
                self.nextToken();
                const indexPtr = try self.allocator.create(ast.Expression);
                indexPtr.* = try self.parseExpression(Precedences.lowest.intVal());
                if (!self.isPeekToken(tokens.r_sq_bracket)) {
                    try self.appendPeekError(tokens.r_sq_bracket);
                }
                self.nextToken();
                return ast.Expression{ .index_exp = .{ .left = leftExp, .index = indexPtr } };
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
    fn parseArguments(self: *Self, endToken: tokens) !std.ArrayList(ast.Expression) {
        var args = std.ArrayList(ast.Expression).init(self.allocator.*);
        if (self.isPeekToken(endToken)) {
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
        if (!self.isPeekToken(endToken)) {
            try self.appendPeekError(endToken);
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

fn getProgramForTest(allocator: *std.mem.Allocator, input: []const u8) anyerror!std.ArrayList(String) {
    const lex = try lexer.newLexer(allocator, input);
    var parser = try newParser(allocator, lex);
    const program = try parser.parse();
    var stmts = std.ArrayList(String).init(allocator.*);
    for (program.statements.items) |stmt| {
        var printBuf = String.init(allocator.*);
        try stmt.stringValue(&printBuf);
        try stmts.append(printBuf);
    }
    return stmts;
}

test "test hashmap" {
    const input =
        \\{"key":"value","k":"v"};
        \\{1:2,1<2:"yes"};
    ;
    const strings: [2][]const u8 = .{
        "{\"key\":\"value\",\"k\":\"v\"}",
        "{1:2,(1 < 2):\"yes\"}",
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const opStrings = try getProgramForTest(&allocator, input);
    for (opStrings.items, 0..) |value, index| {
        try std.testing.expect(std.mem.eql(u8, strings[index], value.str()));
    }
}

test "test array literal" {
    const input =
        \\[1,2+4,3-1,"hello",false];
        \\[1,3,4][1];
        \\[1,3,true][a+b];
    ;
    const strings: [3][]const u8 = .{
        "[1, (2 + 4), (3 - 1), \"hello\", false]",
        "([1, 3, 4][1])",
        "([1, 3, true][(a + b)])",
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const opStrings = try getProgramForTest(&allocator, input);
    for (opStrings.items, 0..) |value, index| {
        try std.testing.expect(std.mem.eql(u8, strings[index], value.str()));
    }
}

test "test string literal" {
    const input =
        \\"yello world!!";
    ;
    const strings: [1][]const u8 = .{"\"yello world!!\""};
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const opStrings = try getProgramForTest(&allocator, input);
    for (opStrings.items, 0..) |value, index| {
        try std.testing.expect(std.mem.eql(u8, strings[index], value.str()));
    }
}

test "test function literal" {
    const input =
        \\func(a) { x };
        \\func(a,b) { x + y };
        \\func(a,b,c) { true == true };
    ;
    const strings: [3][]const u8 = .{
        "func(a){ x }",
        "func(a,b){ (x + y) }",
        "func(a,b,c){ (true == true) }",
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const opStrings = try getProgramForTest(&allocator, input);
    for (opStrings.items, 0..) |value, index| {
        try std.testing.expect(std.mem.eql(u8, strings[index], value.str()));
    }
}

test "test if-else expression" {
    const input =
        \\if (a > b) { x };
        \\if (a > b) { x } else { z };
    ;
    const strings: [2][]const u8 = .{
        "if (a > b) { x }",
        "if (a > b) { x } else { z }",
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const opStrings = try getProgramForTest(&allocator, input);
    for (opStrings.items, 0..) |value, index| {
        try std.testing.expect(std.mem.eql(u8, strings[index], value.str()));
    }
}

test "test grouped expression" {
    const input =
        \\1 + (2 + 3) + 4;
    ;
    const strings: [1][]const u8 = .{
        "((1 + (2 + 3)) + 4)",
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const opStrings = try getProgramForTest(&allocator, input);
    for (opStrings.items, 0..) |value, index| {
        try std.testing.expect(std.mem.eql(u8, strings[index], value.str()));
    }
}

test "Test let statements with expression" {
    const input =
        \\let five = ten;
        \\let ten = five;
    ;
    const strings: [2][]const u8 = .{
        "let five = ten",
        "let ten = five",
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const opStrings = try getProgramForTest(&allocator, input);
    for (opStrings.items, 0..) |value, index| {
        try std.testing.expect(std.mem.eql(u8, strings[index], value.str()));
    }
}

test "Test return statements" {
    const input =
        \\return 100;
        \\return 9;
    ;
    const strings: [2][]const u8 = .{
        "return 100",
        "return 9",
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const opStrings = try getProgramForTest(&allocator, input);
    for (opStrings.items, 0..) |value, index| {
        try std.testing.expect(std.mem.eql(u8, strings[index], value.str()));
    }
}

test "Test Expression" {
    const input =
        \\rem;
        \\10;
    ;
    const strings: [2][]const u8 = .{
        "rem",
        "10",
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const opStrings = try getProgramForTest(&allocator, input);
    for (opStrings.items, 0..) |value, index| {
        try std.testing.expect(std.mem.eql(u8, strings[index], value.str()));
    }
}

test "Test prefix Expression" {
    const input =
        \\ -10;
        \\!1;
    ;
    const strings: [2][]const u8 = .{
        "(-10)",
        "(!1)",
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const opStrings = try getProgramForTest(&allocator, input);
    for (opStrings.items, 0..) |value, index| {
        try std.testing.expect(std.mem.eql(u8, strings[index], value.str()));
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
    const strings: [8][]const u8 = .{
        "(5 + 5)",
        "(5 - 5)",
        "(5 * 5)",
        "(5 / 5)",
        "(5 > 5)",
        "(5 < 5)",
        "(5 == 5)",
        "(5 != 5)",
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const opStrings = try getProgramForTest(&allocator, input);
    for (opStrings.items, 0..) |value, index| {
        try std.testing.expect(std.mem.eql(u8, strings[index], value.str()));
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
    const strings: [13][]const u8 = .{
        "(!(-a))",
        "((a + add((b * d))) + c)",
        "((a + sub(10, 5)) - c)",
        "add(1, a, (x + y), sub(a, b, (x + y)))",
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
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const opStrings = try getProgramForTest(&allocator, input);
    for (opStrings.items, 0..) |value, index| {
        try std.testing.expect(std.mem.eql(u8, strings[index], value.str()));
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
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var allocator = arena.allocator();
    const opStrings = try getProgramForTest(&allocator, input);
    for (opStrings.items, 0..) |value, index| {
        try std.testing.expect(std.mem.eql(u8, strings[index], value.str()));
    }
}
