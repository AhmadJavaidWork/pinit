const std = @import("std");

const Self = @This();

sessions: []Session,

pub const Session = struct {
    name: []const u8,
    dir: []const u8 = "~/",
    windows: []Window = &[_]Window{},
};

const Window = struct {
    name: []const u8,
    pane: Pane,
};

const Pane = struct {
    direction: SplitDirection = .horizontal,
    cmd: []const u8,
    children: []Pane = &[_]Pane{},
};

const SplitDirection = enum(u8) { horizontal, vertical };

pub fn parse(allocator: std.mem.Allocator, io: std.Io, file_name: []const u8) !std.json.Parsed(Self) {
    const file = try std.Io.Dir.cwd().openFile(io, file_name, .{ .mode = .read_only });
    defer file.close(io);

    var buf: [1024 * 4]u8 = undefined;
    var file_reader = file.reader(io, &buf);
    var r = std.json.Reader.init(allocator, &file_reader.interface);
    defer r.deinit();

    return try std.json.parseFromTokenSource(Self, allocator, &r, .{ .ignore_unknown_fields = true });
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
