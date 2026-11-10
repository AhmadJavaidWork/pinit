const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena = init.arena.allocator();

    var err_buf: [1024]u8 = undefined;
    const stderr = std.Io.File.stderr();

    var stderr_writer = stderr.writer(io, &err_buf);
    const err = &stderr_writer.interface;

    const args = try init.minimal.args.toSlice(arena);
    defer arena.free(args);

    var conf_file: []const u8 = "";

    var i: usize = 0;

    while (i < args.len) : (i += 1) {
        if (std.mem.eql(u8, args[i], "-f")) {
            i += 1;
            conf_file = args[i];
        }
    }

    if (conf_file.len == 0) {
        try err.print("Please provide conf file\n", .{});
        try usage(err, args);
        std.process.exit(1);
    }

    const file = try std.Io.Dir.cwd().openFile(io, conf_file, .{ .mode = .read_only });
    var read_buf: [1024 * 4]u8 = undefined;
    var reader = file.reader(io, &read_buf);
    const r = &reader.interface;

    while (true) {
        const line = try r.takeDelimiter('\n');
        if (line) |l| {
            std.debug.print("{s}\n", .{l});
        } else {
            break;
        }
    }
}

fn usage(err: *std.Io.Writer, args: []const [:0]const u8) !void {
    try err.print("Usage: {s} -f [conf-file-path]\n", .{args[0]});
    try err.flush();
}
