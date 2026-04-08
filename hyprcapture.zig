const std = @import("std");
const lib = @import("hyprcapture");
const sqlite = @import("sqlite");

const ping_ns = 50 * std.time.ns_per_ms;
const ping_seconds = @as(comptime_float, ping_ns) / @as(comptime_float, std.time.ns_per_s);

/// What we actually store in the db
const UsageData = struct {
    class: []const u8,
    title: []const u8,
    duration: u64, // ns
};

const create_table =
    \\CREATE TABLE IF NOT EXISTS usage (
    \\  class TEXT NOT NULL,
    \\  title TEXT NOT NULL,
    \\  duration INTEGER NOT NULL DEFAULT 0,
    \\  UNIQUE(class, title)
    \\);
;

const insert =
    \\INSERT INTO usage(class,title,duration) VALUES(?,?,?)
    \\  ON CONFLICT(class, title)
    \\  DO UPDATE SET duration = duration + excluded.duration;
;

/// Communictes over the hyprland socket like hyprctl
pub fn main() !void {
    var __string_storage_buffer: [1024 * 1024]u8 = undefined;
    var string_fba = std.heap.FixedBufferAllocator.init(&__string_storage_buffer);

    var gpa_with_fallback = std.heap.stackFallback(4 * 1024 * 1024, std.heap.page_allocator);
    const alloc = gpa_with_fallback.get();

    const socket_path = try getSocketPath(string_fba.allocator());

    const cmdline_args = try parseArgs();
    var db = try initDatabase(cmdline_args.database_path);
    defer db.deinit();
    var insert_statement = try db.prepare(insert);
    defer insert_statement.deinit();

    var usage_data_list = try std.ArrayList(UsageData).initCapacity(alloc, 1024);

    var timer = std.time.Timer.start() catch unreachable;
    while (true) : (timer.reset()) {
        defer std.Thread.sleep(ping_ns -| timer.lap());

        const end_index = string_fba.end_index;
        defer string_fba.end_index = end_index;

        {
            defer std.log.info("Took {}ns", .{timer.read()});
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

            usage_data_list.clearRetainingCapacity();

            const reader: *std.Io.Reader = stream_reader.interface();
            while (try parsing.takeNext(reader, &string_fba)) |client_info| {
                usage_data_list.append(alloc, .{
                    .class = client_info.class,
                    .title = client_info.title,
                    .duration = ping_ns,
                }) catch @panic("oom!");
            }
        }

        try db.exec("begin transaction", .{}, .{});
        defer db.exec("commit", .{}, .{}) catch {};
        for (usage_data_list.items) |usage_data| {
            insert_statement.reset();
            try insert_statement.exec(.{}, usage_data);
        }
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
        string_buffer: *std.heap.FixedBufferAllocator,
    ) !?ClientInfo {
        const stralloc = string_buffer.allocator();

        var info = ClientInfo{
            .class = &.{},
            .title = &.{},
            .focusHistoryID = FocusHistoryID.not_found,
        };

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
            const field = std.meta.stringToEnum(
                std.meta.FieldEnum(ClientInfo),
                trimmed_line[0..@":"],
            ) orelse continue;

            const value = trim(trimmed_line[@":" + 1 ..]);

            switch (field) {
                .class => info.class = try stralloc.dupe(u8, value),
                .title => info.title = try stralloc.dupe(u8, value),
                .focusHistoryID => info.focusHistoryID = @enumFromInt(try std.fmt.parseInt(i16, value, 10)),
            }
        }

        return info;
    }
};

fn parseArgs() !Args {
    var args = std.process.args();
    _ = args.skip();
    const database_path = if (args.next()) |path| path else blk: {
        std.log.err("Expected a path to a sqlite database file. Falling back to ./hyprcapture.sqlite", .{});
        break :blk "./hyprcapture.sqlite";
    };

    return .{ .database_path = database_path };
}

const Args = struct {
    database_path: [:0]const u8,
};

fn initDatabase(database_path: [:0]const u8) !sqlite.Db {
    var db = try sqlite.Db.init(.{
        .mode = sqlite.Db.Mode{ .File = database_path },
        .open_flags = .{ .write = true, .create = true },
        .threading_mode = .MultiThread,
    });
    try db.exec(create_table, .{ .diags = null }, .{});
    return db;
}

fn trim(list: []const u8) []const u8 {
    return std.mem.trim(u8, list, &std.ascii.whitespace);
}
