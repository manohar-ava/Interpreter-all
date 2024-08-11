const std = @import("std");
const token = @import("./token.zig");

pub const Statement = union(enum) {
    let: LetStatement,
    return_stmt: ReturnStatement,
};

pub const Expression = union(enum) {
    ident: Identifier,
};
pub const LetStatement = struct {
    identifier: Identifier = undefined,
    value: Expression = undefined,
};

pub const ReturnStatement = struct { value: Expression = undefined };

pub const Identifier = struct {
    name: []const u8,
};

pub const Program = struct {
    statements: std.ArrayList(Statement),
    pub fn getToken(self: *Program) token.tokens {
        return self.statements[0].getToken();
    }
};
