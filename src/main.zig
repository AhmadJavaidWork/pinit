const std = @import("std");
const Conf = @import("conf.zig");
const Launcher = @import("launcher.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;
    const arena = init.arena.allocator();

    var err_buf: [1024]u8 = undefined;
    const stderr = std.Io.File.stderr();

    var stderr_writer = stderr.writer(io, &err_buf);
    const err = &stderr_writer.interface;

    const args = try init.minimal.args.toSlice(arena);
    defer arena.free(args);

    var file_name: []const u8 = "";
    var session_name: []const u8 = "";

    var i: usize = 0;

    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-f")) {
            i += 1;
            file_name = args[i];
        } else if (std.mem.eql(u8, args[i], "-s")) {
            i += 1;
            session_name = args[i];
        }
    }

    if (file_name.len == 0 or session_name.len == 0) {
        try err.print("Please provide a conf file\n", .{});
        try err.flush();
        try usage(err, args);
        std.process.exit(1);
    }

    const file_path = try std.Io.Dir.cwd().realPathFileAlloc(io, file_name, allocator);
    defer allocator.free(file_path);

    const parsed = try Conf.parse(allocator, io, file_path);
    defer parsed.deinit();

    const config = parsed.value;

    var session: ?Conf.Session = null;

    for (config.sessions) |sess| {
        if (std.mem.eql(u8, session_name, sess.name)) {
            session = sess;
            break;
        }
    }

    if (session) |sess| {
        try Launcher.launch(allocator, io, sess);
    } else {
        try err.print("No session: {s} found in the conf file: {s}\n", .{ session_name, file_path });
        try err.flush();
        std.process.exit(1);
    }
}

fn usage(err: *std.Io.Writer, args: []const [:0]const u8) !void {
    try err.print("Usage: {s} -f [conf-file-path] -s [session-name]\n", .{args[0]});
    try err.flush();
}
