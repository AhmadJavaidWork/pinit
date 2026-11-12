const std = @import("std");
const Conf = @import("conf.zig");
const Launcher = @import("launcher.zig");

const Args = struct {
    file_name: []const u8,
    session_name: []const u8,
    home: []const u8,
    inside_tmux: bool = false,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;
    const arena = init.arena.allocator();

    var err_buf: [1024]u8 = undefined;
    const stderr = std.Io.File.stderr();

    var stderr_writer = stderr.writer(io, &err_buf);
    const err = &stderr_writer.interface;

    const args = try prepareArgs(init.arena, init, err);
    defer arena.free(args.file_name);

    const file_path = try prepareConfigFile(allocator, io, args.file_name, err);
    defer allocator.free(file_path);

    const parsed = try Conf.parse(allocator, io, file_path, args.home);
    defer parsed.deinit();

    const config = parsed.value;

    var session: ?Conf.Session = null;

    for (config.sessions) |sess| {
        if (std.mem.eql(u8, args.session_name, sess.name)) {
            session = sess;
            break;
        }
    }

    if (session) |sess| {
        try Launcher.launch(allocator, io, sess, args.home, args.inside_tmux);
    } else {
        try errorExit(
            err,
            "No session: {s} found in the conf file: {s}\n",
            .{ args.session_name, file_path },
        );
        std.process.exit(1);
    }
}

fn prepareConfigFile(
    allocator: std.mem.Allocator,
    io: std.Io,
    file_name: []const u8,
    err: *std.Io.Writer,
) ![:0]const u8 {
    return std.Io.Dir.cwd().realPathFileAlloc(io, file_name, allocator) catch |e| {
        switch (e) {
            std.Io.File.RealPathError.FileNotFound => {
                try errorExit(err, "Config file not found: {s}\n", .{file_name});
                std.process.exit(1);
            },
            else => return e,
        }
    };
}

fn prepareArgs(
    arena: *std.heap.ArenaAllocator,
    init: std.process.Init,
    err: *std.Io.Writer,
) !Args {
    const allocator = arena.allocator();
    const args = try init.minimal.args.toSlice(allocator);
    defer allocator.free(args);

    var file_name: []const u8 = "";
    var session_name: []const u8 = "";
    const home = init.environ_map.get("HOME") orelse {
        try errorExit(err, "Please set HOME environment variable", .{});
        std.process.exit(1);
    };

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

    if (file_name.len == 0) {
        file_name = try std.fs.path.join(allocator, &.{ home, ".config/pinit/conf.json" });
    }

    if (session_name.len == 0) {
        try errorExit(err, "Please provide a session name\n", .{});
        try usage(err, args);
        std.process.exit(1);
    }

    return .{
        .file_name = file_name,
        .session_name = session_name,
        .home = home,
        .inside_tmux = init.environ_map.get("TMUX") != null,
    };
}

fn usage(err: *std.Io.Writer, args: []const [:0]const u8) !void {
    try err.print("Usage: {s} -s [session-name] -f [conf-file-path]\n", .{args[0]});
    try err.flush();
}

fn errorExit(err: *std.Io.Writer, comptime fmt: []const u8, args: anytype) !void {
    try err.print(fmt, args);
    try err.flush();
}
