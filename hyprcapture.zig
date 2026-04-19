const std = @import("std");
const lib = @import("hyprcapture");
const sqlite = @import("sqlite");

const min_refresh_rate_ms = 10 * std.time.ns_per_ms;
const max_refresh_rate_ms = 10_000 * std.time.ns_per_ms;

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
    \\  date TEXT NOT NULL DEFAULT CURRENT_DATE,
    \\  duration INTEGER NOT NULL DEFAULT 0,
    \\  UNIQUE(class, title, date)
    \\);
;

const insert =
    \\INSERT INTO usage(class,title,duration) VALUES(?,?,?)
    \\  ON CONFLICT(class,title,date)
    \\  DO UPDATE SET duration = duration + excluded.duration;
;

pub fn main() !void {
    try std.posix.setrlimit(.STACK, .{
        .cur = 1024 * 1024,
        .max = 1024 * 1024,
    });

    var __string_storage_buffer: [8 * 1024]u8 = undefined;
    var string_fba = std.heap.FixedBufferAllocator.init(&__string_storage_buffer);

    var gpa_with_fallback = std.heap.stackFallback(256 * 1024, std.heap.page_allocator);
    const alloc = gpa_with_fallback.get();

    const socket_path = try getSocketPath(string_fba.allocator());

    const config = parseCmdline() catch |e| help(e);
    var db = try initDatabase(config.database_path);
    defer db.deinit();
    var insert_statement = try db.prepare(insert);
    defer insert_statement.deinit();

    var usage_data_list = try std.ArrayList(UsageData).initCapacity(alloc, 128);

    var timer = std.time.Timer.start() catch unreachable;
    while (true) : (timer.reset()) {
        defer std.Thread.sleep(config.refresh_rate -| timer.lap());

        const end_index = string_fba.end_index;
        defer string_fba.end_index = end_index;

        {
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
                if (client_info.focusHistoryID == .focused) {
                    usage_data_list.append(alloc, .{
                        .class = client_info.class,
                        .title = client_info.title,
                        .duration = config.refresh_rate,
                    }) catch @panic("oom!");
                }
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

fn help(maybe_error: ?anyerror) noreturn {
    if (maybe_error) |e| {
        std.log.err(
            \\An error occured ({s}). See help below.
            \\
        , .{@errorName(e)});
    }

    var file = std.fs.File.stderr();
    var iobuf: [256]u8 = undefined;
    var fwriter = file.writer(&iobuf);
    fwriter.interface.print(
        \\An application usage tracker for hyprland.
        \\
        \\Usage: hyprcapture [OPTIONS] [DATABASE]
        \\
        \\Arguments:
        \\  [DATABASE]...
        \\          sqlite database file to write stuff to.
        \\
        \\Options:
        \\  -r, --refresh-rate
        \\          Modify the rate at which the program samples application usage.
        \\          This variable is specified in milliseconds. Default is {}. The
        \\          value is clamped to the range [{}, {}].
        \\
    , .{
        Config.default.refresh_rate / std.time.ns_per_ms,
        min_refresh_rate_ms / std.time.ns_per_ms,
        max_refresh_rate_ms / std.time.ns_per_ms,
    }) catch {};

    fwriter.interface.flush() catch {};

    std.process.exit(@intFromBool(maybe_error != null));
}

fn parseCmdline() !Config {
    var args = std.process.args();
    _ = args.skip();

    var config = Config.default;

    while (args.next()) |raw_arg| {
        var arg = trim(raw_arg);
        if (std.mem.eql(u8, arg, "--refresh-rate") or
            std.mem.eql(u8, arg, "-r"))
        {
            arg = trim(args.next() orelse return error.ExpectedRefreshRate);
            config.refresh_rate =
                std.time.ns_per_ms *
                try std.fmt.parseInt(@TypeOf(config.refresh_rate), arg, 10);
            config.refresh_rate = std.math.clamp(config.refresh_rate, min_refresh_rate_ms, max_refresh_rate_ms);
        } else //
        if (std.mem.eql(u8, arg, "--help") or
            std.mem.eql(u8, arg, "-h") or
            std.mem.startsWith(u8, arg, "-"))
        {
            help(null);
        } else {
            config.database_path = raw_arg;
        }
    }

    std.log.info(
        \\Current configuration:
        \\config.refresh_rate = {}ms
        \\config.database_path = {s}
    , .{
        config.refresh_rate / std.time.ns_per_ms,
        config.database_path,
    });

    return config;
}

const Config = struct {
    refresh_rate: u64,
    database_path: [:0]const u8,

    pub const default = Config{
        .refresh_rate = 100 * std.time.ns_per_ms,
        .database_path = "hyprcapture.sqlite",
    };
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
