const std = @import("std");

const Self = @This();

sessions: []Session,

pub const Session = struct {
    name: []const u8,
    dir: ?[]const u8 = null,
    windows: []Window = &[_]Window{},
};

pub const Window = struct {
    name: []const u8,
    dir: ?[]const u8 = null,
    cmd: ?[]const u8 = null,
    pane: ?Pane = null,
};

pub const Pane = struct {
    direction: SplitDirection = .horizontal,
    dir: ?[]const u8 = null,
    cmd: ?[]const u8 = null,
    children: ?[]Pane = null,
};

pub const SplitDirection = enum(u8) { horizontal, vertical };

pub fn parse(
    allocator: std.mem.Allocator,
    io: std.Io,
    file_name: []const u8,
    home: []const u8,
) !std.json.Parsed(Self) {
    const file = try std.Io.Dir.cwd().openFile(io, file_name, .{ .mode = .read_only });
    defer file.close(io);

    var buf: [1024 * 4]u8 = undefined;
    var file_reader = file.reader(io, &buf);
    var r = std.json.Reader.init(allocator, &file_reader.interface);
    defer r.deinit();

    var parsed = try std.json.parseFromTokenSource(Self, allocator, &r, .{ .ignore_unknown_fields = true });
    try normalizePaths(&parsed, home);
    return parsed;
}

fn normalizePaths(
    parsed: *std.json.Parsed(Self),
    home: []const u8,
) !void {
    const allocator = parsed.arena.allocator();

    for (parsed.value.sessions) |*sess| {
        if (sess.dir) |dir| {
            if (std.mem.startsWith(u8, dir, "~/")) {
                sess.dir = try std.fs.path.join(allocator, &.{ home, dir[2..] });
            }
        }
        for (sess.windows) |*window| {
            if (window.dir) |dir| {
                if (std.mem.startsWith(u8, dir, "~/")) {
                    window.dir = try std.fs.path.join(allocator, &.{ home, dir[2..] });
                }
            }
            if (window.pane) |*pane| {
                if (pane.dir) |dir| {
                    if (std.mem.startsWith(u8, dir, "~/")) {
                        window.pane.?.dir = try std.fs.path.join(allocator, &.{ home, dir[2..] });
                    }
                }
                try normalizeChildren(parsed.arena, pane, home);
            }
        }
    }
}

fn normalizeChildren(arena: *std.heap.ArenaAllocator, pane: *Pane, home: []const u8) !void {
    const allocator = arena.allocator();
    if (pane.children) |children| {
        for (children) |*p| {
            if (p.dir) |dir| {
                if (std.mem.startsWith(u8, dir, "~/")) {
                    p.dir = try std.fs.path.join(allocator, &.{ home, dir[2..] });
                }
            }
            try normalizeChildren(arena, p, home);
        }
    }
}

pub fn format(self: *const Self, w: *std.Io.Writer) !void {
    try indentedPrint(w, 0, "{{\n", .{});
    try indentedPrint(w, 1, "sessions: {{", .{});

    if (self.sessions.len > 0) {
        try w.print("\n", .{});
    }

    for (self.sessions) |session| {
        try indentedPrint(w, 2, "{{\n", .{});
        try indentedPrint(w, 3, "name: \"{s}\",\n", .{session.name});
        try indentedPrint(w, 3, "dir: \"{s}\",\n", .{session.dir});
        try indentedPrint(w, 3, "windows: {{", .{});

        if (session.windows.len > 0) {
            try w.print("\n", .{});
        }

        for (session.windows) |window| {
            try indentedPrint(w, 4, "{{\n", .{});
            try indentedPrint(w, 5, "name: \"{s}\",\n", .{window.name});
            try indentedPrint(w, 5, "pane: {{\n", .{});
            try indentedPrint(w, 6, "direction: \"{}\",\n", .{window.pane.direction});
            try indentedPrint(w, 6, "cmd: \"{s}\",\n", .{window.pane.cmd});
            try indentedPrint(w, 6, "children: {{", .{});

            if (window.pane.children.len > 0) {
                try w.print("\n", .{});
            }

            for (window.pane.children) |pane| {
                try indentedPrint(w, 7, "{{\n", .{});
                try indentedPrint(w, 8, "direction: \"{}\",\n", .{window.pane.direction});
                try indentedPrint(w, 8, "cmd: \"{s}\",\n", .{pane.cmd});
                try indentedPrint(w, 7, "}},\n", .{});
            }

            if (window.pane.children.len > 0) {
                try printTabs(6, w);
            }

            try indentedPrint(w, 0, "}},\n", .{});
            try indentedPrint(w, 5, "}},\n", .{});
            try indentedPrint(w, 4, "}},\n", .{});
        }

        if (session.windows.len > 0) {
            try printTabs(3, w);
        }

        try indentedPrint(w, 0, "}},\n", .{});
        try indentedPrint(w, 2, "}},\n", .{});
    }

    try indentedPrint(w, 1, "}},\n", .{});

    try w.print("}}", .{});
    try w.flush();
}

fn printTabs(n: usize, w: *std.Io.Writer) !void {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        try w.print("  ", .{});
    }
}

fn indentedPrint(w: *std.Io.Writer, tabs: usize, comptime fmt: []const u8, args: anytype) !void {
    try printTabs(tabs, w);
    try w.print(fmt, args);
}
