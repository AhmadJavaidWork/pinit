const std = @import("std");
const Session = @import("conf.zig").Session;

pub fn launch(allocator: std.mem.Allocator, io: std.Io, session: Session) !void {
    const stderr = std.Io.File.stderr();
    var stderr_write_buf: [1024 * 4]u8 = undefined;
    var stderr_writer = stderr.writer(io, &stderr_write_buf);

    const err = &stderr_writer.interface;

    const code_pane = try spawnSession(allocator, io, session.name, session.dir, session.windows[0].name, err);
    try runByPaneId(allocator, io, code_pane, session.windows[0].pane.cmd, err);
    defer allocator.free(code_pane);
}

fn spawnSession(
    allocator: std.mem.Allocator,
    io: std.Io,
    session_name: []const u8,
    work_dir: []const u8,
    window_name: []const u8,
    err: *std.Io.Writer,
) ![]u8 {
    const result = try std.process.run(allocator, io, .{
        .argv = &.{
            "tmux",
            "new",
            "-d",
            "-s",
            session_name,
            "-c",
            work_dir,
            "-n",
            window_name,
            "-P",
            "-F",
            "#{pane_id}",
        },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try printResult(result, err);

    return allocator.dupe(u8, std.mem.trim(u8, result.stdout, " \t\r\n"));
}

fn runByPaneId(
    allocator: std.mem.Allocator,
    io: std.Io,
    pane_id: []const u8,
    cmd: []const u8,
    err: *std.Io.Writer,
) !void {
    const result = try std.process.run(allocator, io, .{
        .argv = &.{ "tmux", "send-keys", "-t", pane_id, cmd, "C-m" },
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    try printResult(result, err);
}

fn printResult(result: std.process.RunResult, err: *std.Io.Writer) !void {
    switch (result.term) {
        .exited => |code| {
            if (code != 0) {
                try err.print("{s}", .{result.stderr});
                try err.flush();
                std.process.exit(code);
            } else {}
        },
        else => {
            try err.print("Process was killed or stopped unexpectedly.\n", .{});
            try err.flush();

            std.process.exit(1);
        },
    }
}
