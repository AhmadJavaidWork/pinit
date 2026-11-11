const std = @import("std");

const Self = @This();

sessions: []Session,

const Session = struct {
    name: []const u8,
    dir: []const u8,
    windows: []Window,
};

const Window = struct {
    name: []const u8,
};

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
    try w.print("sessions: ", .{});
    try printOpenBraces(w);
    try printNewLine(w);

    for (self.sessions) |session| {
        try printTabs(1, w);
        try printOpenBraces(w);
        try printNewLine(w);

        try printTabs(2, w);
        try w.print("name: ", .{});
        try printDoubleQuotes(w);
        try w.print("{s}", .{session.name});
        try printDoubleQuotes(w);
        try printComma(w);
        try printNewLine(w);

        try printTabs(2, w);
        try w.print("dir: ", .{});
        try printDoubleQuotes(w);
        try w.print("{s}", .{session.dir});
        try printDoubleQuotes(w);

        try printComma(w);
        try printNewLine(w);

        try printTabs(2, w);
        try w.print("windows: ", .{});
        try printOpenBraces(w);
        try printNewLine(w);

        for (session.windows) |window| {
            try printTabs(3, w);
            try printOpenBraces(w);
            try printNewLine(w);

            try printTabs(4, w);
            try w.print("name: ", .{});
            try printDoubleQuotes(w);
            try w.print("{s}", .{window.name});
            try printDoubleQuotes(w);
            try printComma(w);
            try printNewLine(w);

            try printTabs(3, w);
            try printCloseBraces(w);
            try printComma(w);
            try printNewLine(w);
        }
        try printTabs(2, w);
        try printCloseBraces(w);
        try printComma(w);
        try printNewLine(w);

        try printTabs(1, w);
        try printCloseBraces(w);
        try printComma(w);
        try printNewLine(w);
    }

    try printCloseBraces(w);
    try w.flush();
}

fn printTabs(n: usize, w: *std.Io.Writer) !void {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        try w.print("  ", .{});
    }
}

fn printOpenBraces(w: *std.Io.Writer) !void {
    try w.print("{{", .{});
}

fn printCloseBraces(w: *std.Io.Writer) !void {
    try w.print("}}", .{});
}

fn printNewLine(w: *std.Io.Writer) !void {
    try w.print("\n", .{});
}

fn printComma(w: *std.Io.Writer) !void {
    try w.print(",", .{});
}

fn printDoubleQuotes(w: *std.Io.Writer) !void {
    try w.print("\"", .{});
}
