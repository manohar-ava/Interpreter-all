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
    pub fn parse(self: *Parser) *ast.Program {
        const stmts = std.ArrayList(*ast.Statement).init(self.allocator.*);
        var program = ast.Program{ .statements = stmts };
        print("{}\n", .{program});
        while (true) {
            switch (self.curToken) {
                .eof => break,
                else => {
                    const stmt = self.parseStatement();
                    try program.statements.append(stmt);
                },
            }
            self.nextToken();
        }
        return &program;
    }
    pub fn parseStatement(self: *Parser) *ast.Statement {
        return switch (self.curToken) {
            .let => {
                const letStmt = self.parseLetStatement();
                .{ .let = letStmt };
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
        while (true) {
            switch (self.curToken) {
                .semicolon => {
                    self.nextToken();
                },
                else => unreachable,
            }
        }
        return stmt;
    }
};

pub fn newParser(alloc: *std.mem.Allocator, l: *lexer.Lexer) *Parser {
    var parser = Parser{ .l = l, .allocator = alloc };
    parser.nextToken();
    parser.nextToken();
    return &parser;
}

test "Test next tokens" {
    // const MyError = error{
    //     ProgramUndefined,
    // };
    const input =
        \\let five = 5;
        \\let ten = 10;
    ;
    var lex = lexer.newLexer(input);
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    var allocator = arena.allocator();

    const parser = newParser(&allocator, &lex);

    const program = parser.parse();
    print(" {any} \n", .{program});
    // if (program == undefined) {
    //     return MyError.ProgramUndefined;
    // }
    // if (program.statements.len != 3) {
    //     return MyError.ProgramDoesNotHaveThreeStatements;
    // }

    // print(" {} \n", .{program});
    // const tests = [_]token.tokens{ .{ .ident = "five" }, .{ .ident = "ten" } };
    // for (tests) |value| {
    //     // const stmt = program.statements[index];
    //     // print(" {} \n", .{value});
    //     // try std.testing.expectEqualDeep(value, tok);
    // }
}
