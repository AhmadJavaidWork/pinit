const std = @import("std");
const Conf = @import("conf.zig");

pub fn launch(allocator: std.mem.Allocator, io: std.Io, session: Conf.Session) !void {
    const stderr = std.Io.File.stderr();
    var stderr_write_buf: [1024 * 4]u8 = undefined;
    var stderr_writer = stderr.writer(io, &stderr_write_buf);

    const err = &stderr_writer.interface;

    for (session.windows, 0..) |window, i| {
        var pid: []u8 = "";
        defer allocator.free(pid);
        const dir = if (window.dir) |d| d else session.dir;

        if (i == 0) {
            pid = try spawnSession(allocator, io, dir, session.name, window.name, err);
        } else {
            pid = try makeWindow(allocator, io, dir, session.name, window.name, err);
        }

        if (window.pane) |p| {
            if (p.cmd) |cmd| {
                try runByPaneId(allocator, io, pid, cmd, err);
            } else if (window.cmd) |cmd| {
                try runByPaneId(allocator, io, pid, cmd, err);
            }
            try spawnChildren(allocator, io, dir, p, pid, err);
        } else if (window.cmd) |cmd| {
            try runByPaneId(allocator, io, pid, cmd, err);
        }
    }
}

fn spawnSession(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: []const u8,
    session_name: []const u8,
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
            "-n",
            window_name,
            "-c",
            dir,
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

fn makeWindow(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: []const u8,
    session_name: []const u8,
    window_name: []const u8,
    err: *std.Io.Writer,
) ![]u8 {
    const result = try std.process.run(allocator, io, .{
        .argv = &.{
            "tmux",
            "new-window",
            "-d",
            "-t",
            session_name,
            "-n",
            window_name,
            "-c",
            dir,
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

fn spawnChildren(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: []const u8,
    pane: Conf.Pane,
    pid: []const u8,
    err: *std.Io.Writer,
) !void {
    if (pane.children) |children| {
        for (children) |p| {
            const directory = if (p.dir) |d| d else if (pane.dir) |d| d else dir;
            const cid = try splitPane(allocator, io, directory, pid, p.direction, err);
            defer allocator.free(cid);

            if (p.cmd) |cmd| {
                try runByPaneId(allocator, io, cid, cmd, err);
            }
            try spawnChildren(allocator, io, dir, p, cid, err);
        }
    }
}

fn splitPane(
    allocator: std.mem.Allocator,
    io: std.Io,
    dir: []const u8,
    pane: []const u8,
    split_direction: Conf.SplitDirection,
    err: *std.Io.Writer,
) ![]u8 {
    const split_flag = if (split_direction == .horizontal) "-h" else "-v";

    const result = try std.process.run(allocator, io, .{
        .argv = &.{
            "tmux",
            "split-window",
            split_flag,
            "-t",
            pane,
            "-c",
            dir,
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
