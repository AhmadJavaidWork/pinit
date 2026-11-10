const std = @import("std");

const Self = @This();

session_name: []const u8,
work_dir: []const u8,

pub fn parse(allocator: std.mem.Allocator, io: std.Io, file_name: []const u8) !Self {
    const file = try std.Io.Dir.cwd().openFile(io, file_name, .{ .mode = .read_only });

    var buf: [1024 * 4]u8 = undefined;
    var file_reader = file.reader(io, &buf);
    const r = &file_reader.interface;

    var config: Self = .{
        .session_name = "",
        .work_dir = "",
    };

    while (true) {
        const line = try r.takeDelimiter('\n');
        if (line) |l| {
            const trimmed_line = std.mem.trim(u8, l, " \n");
            if (std.mem.startsWith(u8, trimmed_line, "session-name:")) {
                config.session_name = try parseValue(allocator, trimmed_line);
            } else if (std.mem.startsWith(u8, trimmed_line, "work-dir:")) {
                config.work_dir = try parseValue(allocator, trimmed_line);
            }
        } else {
            break;
        }
    }

    return config;
}

fn parseValue(allocator: std.mem.Allocator, line: []const u8) ![]const u8 {
    var it = std.mem.splitScalar(u8, line, ':');
    _ = it.next();
    var value = it.next() orelse return error.SessionNameNotFound;
    value = std.mem.trim(u8, value, " \n");
    return try allocator.dupe(u8, value);
}

pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    allocator.free(self.session_name);
    allocator.free(self.work_dir);
}

pub fn format(self: *const Self, w: *std.Io.Writer) !void {
    try w.print("session_name: {s}\n", .{self.session_name});
    try w.print("work_dir: {s}", .{self.work_dir});
    try w.flush();
}
