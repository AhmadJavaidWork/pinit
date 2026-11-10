const std = @import("std");

const Self = @This();

session_name: []const u8,
work_dir: []const u8,

pub fn parse(allocator: std.mem.Allocator, io: std.Io, file_name: []const u8) !std.json.Parsed(Self) {
    const file = try std.Io.Dir.cwd().openFile(io, file_name, .{ .mode = .read_only });
    defer file.close(io);

    var buf: [1024 * 4]u8 = undefined;
    var file_reader = file.reader(io, &buf);
    var r = std.json.Reader.init(allocator, &file_reader.interface);
    defer r.deinit();

    return try std.json.parseFromTokenSource(Self, allocator, &r, .{});
}

pub fn format(self: *const Self, w: *std.Io.Writer) !void {
    try w.print("session_name: {s}\n", .{self.session_name});
    try w.print("work_dir: {s}", .{self.work_dir});
    try w.flush();
}
