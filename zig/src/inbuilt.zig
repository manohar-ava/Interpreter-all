const std = @import("std");
const object = @import("object.zig");

pub const TRUE = object.Boolean{ .value = true };
pub const FALSE = object.Boolean{ .value = false };
pub const NULL = object.Null{};

pub var TRUE_OBJECT = object.Object{ .Boolean = TRUE };
pub var FALSE_OBJECT = object.Object{ .Boolean = FALSE };
pub var NULL_OBJECT = object.Object{ .Null = NULL };
