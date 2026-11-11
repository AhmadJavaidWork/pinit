const std = @import("std");

const Self = @This();

const Session = struct {
    name: []const u8,
    dir: []const u8,
};

sessions: []Session,

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
    try w.print("sessions: {{\n", .{});
    for (self.sessions) |session| {
        try w.print("\t{{\n\t\tname: {s},\n", .{session.name});
        try w.print("\t\tdir: {s},\n\t}},\n", .{session.dir});
        try w.flush();
    }
    try w.print("}}", .{});
}
