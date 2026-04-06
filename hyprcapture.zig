const std = @import("std");
const lib = @import("hyprcapture");
const sqlite = @import("sqlite");

const ping_ns = 500 * std.time.ns_per_ms;
const ping_seconds = @as(comptime_float, ping_ns) / @as(comptime_float, std.time.ns_per_s);

const create =
    \\create table if not exists usage (
    \\  class text not null,
    \\  title text not null,
    \\  duration sqlite_uint64 not null default 0,
    \\  unique(class, title)
    \\);
;
const insert =
    \\insert into usage (class, title, duration)
    \\  values (?, ?, ?)
    \\  on conflict(class, title)
    \\  do update set duration = duration + excluded.duration;
;

/// Communictes over the hyprland socket like hyprctl
pub fn main() !void {
    var __string_storage_buffer: [1024 * 1024]u8 = undefined;
    var string_fba = std.heap.FixedBufferAllocator.init(&__string_storage_buffer);
    const string_alloc = string_fba.allocator();

    // Get the database path
    var args = std.process.args();
    _ = args.skip();

    const database_path = args.next() orelse return error.ExpectedSqliteDatabaseFilePath;
    var db = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = database_path },
        .open_flags = .{ .write = true, .create = true },
        .threading_mode = .MultiThread,
    });
    defer db.deinit();

    try db.exec(create, .{ .diags = null }, .{});

    const socket_path = try getSocketPath(string_alloc);

    var timer = std.time.Timer.start() catch unreachable;
    while (true) : (timer.reset()) {
        defer std.Thread.sleep(ping_ns -| timer.lap());

        const stream = try std.net.connectUnixSocket(socket_path);
        defer stream.close();

        {
            var stream_writer = stream.writer(&.{});
            const writer: *std.Io.Writer = &stream_writer.interface;
            try writer.writeAll("clients");
        }

        // read the output
        var stream_reader_buf: [1024]u8 = undefined;
        var stream_reader = stream.reader(&stream_reader_buf);

        const reader: *std.Io.Reader = stream_reader.interface();
        while (try parsing.takeNext(reader, string_alloc, &db)) |_| {}
    }
}

fn getSocketPath(allocator: std.mem.Allocator) ![]u8 {
    const xdg_runtime_dir =
        try std.process.getEnvVarOwned(allocator, "XDG_RUNTIME_DIR");
    defer allocator.free(xdg_runtime_dir);

    const hyprland_instance_signature =
        try std.process.getEnvVarOwned(allocator, "HYPRLAND_INSTANCE_SIGNATURE");
    defer allocator.free(hyprland_instance_signature);

    return std.fmt.allocPrint(
        allocator,
        "{s}/hypr/{s}/.socket.sock",
        .{ xdg_runtime_dir, hyprland_instance_signature },
    );
}

const parsing = struct {
    const FocusHistoryID = enum(i16) {
        not_found = -1,
        focused = 0,
        _,
    };

    const ClientInfo = struct {
        class: []const u8,
        title: []const u8,
        focusHistoryID: FocusHistoryID,
    };

    /// Reads one `ClientInfo` from the reader and puts it into the usage data
    /// struct, otherwise outputs `null` if at the end of the stream.
    fn takeNext(
        reader: *std.Io.Reader,
        string_alloc: std.mem.Allocator,
        database: *sqlite.Db,
    ) !?void {
        var info = ClientInfo{
            .class = &.{},
            .title = &.{},
            .focusHistoryID = FocusHistoryID.not_found,
        };

        defer string_alloc.free(info.class);
        defer string_alloc.free(info.title);

        // Skip the first line as we dont need the title and address
        {
            const num_discarded = reader.discardDelimiterInclusive('\n') catch |e| switch (e) {
                error.EndOfStream => return null,
                error.ReadFailed => return error.ReadFailed,
            };
            std.debug.assert(num_discarded > 0);
        }

        while (try reader.takeDelimiter('\n')) |line| {
            const trimmed_line = trim(line);
            if (trimmed_line.len == 0) break;

            const @":" = std.mem.indexOfScalar(u8, trimmed_line, ':') orelse unreachable;
            const T = std.meta.FieldEnum(ClientInfo);
            const field = std.meta.stringToEnum(T, trimmed_line[0..@":"]) orelse continue;

            switch (field) {
                .class => info.class = try string_alloc.dupe(u8, trim(trimmed_line[@":" + 1 ..])),
                .title => info.title = try string_alloc.dupe(u8, trim(trimmed_line[@":" + 1 ..])),
                .focusHistoryID => {
                    const id = try std.fmt.parseInt(i16, trim(trimmed_line[@":" + 1 ..]), 10);
                    info.focusHistoryID = @enumFromInt(id);
                },
            }
        }

        if (info.focusHistoryID == .focused) {
            try database.exec(insert, .{ .diags = null }, .{
                .class = info.class,
                .title = info.title,
                .duration = ping_ns,
            });
        }
    }
};

/// Value is the total time it is focused for
const WindowUsageData = std.StringArrayHashMapUnmanaged(f32);

/// Note: keys are not managed :)
fn windowUsageDataDeinit(data: *WindowUsageData, gpa: std.mem.Allocator) void {
    var it = data.iterator();
    while (it.next()) |kv| {
        gpa.free(kv.key_ptr.*);
    }
    data.deinit(gpa);
}

fn writeUsageDataToFile(data: *WindowUsageData) !void {
    var iobuf: [1024]u8 = undefined;
    var file = try std.fs.cwd().createFile("stats.json", .{});
    defer file.close();
    var file_writer = file.writer(&iobuf);

    const map = std.json.fmt(
        std.json.ArrayHashMap(f32){ .map = data.* },
        .{ .whitespace = .indent_4 },
    );
    try map.format(&file_writer.interface);
    try file_writer.interface.flush();
}

fn trim(list: []const u8) []const u8 {
    return std.mem.trim(u8, list, &std.ascii.whitespace);
}
