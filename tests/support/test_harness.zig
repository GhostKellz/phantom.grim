const std = @import("std");
const grim = @import("grim");
const core = grim.core;
const plugin_api = grim.runtime.plugin_api;
const syntax = grim.syntax;
const ArrayListManaged = std.array_list.Managed;

/// Adapted from grim/runtime/test_harness.zig (commit BbxsAa5S...)
/// Updated to Zig 0.16 ArrayList API for phantom.grim tests.
pub const TestHarness = struct {
    allocator: std.mem.Allocator,
    buffers: std.AutoHashMap(u32, TestBuffer),
    next_buffer_id: u32 = 1,
    plugin_api: plugin_api.PluginAPI,
    command_log: ArrayListManaged(LoggedCommand),
    event_log: ArrayListManaged(LoggedEvent),
    verbose: bool = false,

    pub const TestBuffer = struct {
        id: u32,
        rope: core.Rope,
        file_path: ?[]const u8 = null,
        modified: bool = false,
        cursor: plugin_api.PluginAPI.EditorContext.CursorPosition,

        pub fn init(allocator: std.mem.Allocator, id: u32) !TestBuffer {
            return TestBuffer{
                .id = id,
                .rope = try core.Rope.init(allocator),
                .cursor = .{ .line = 0, .column = 0, .byte_offset = 0 },
            };
        }

        pub fn deinit(self: *TestBuffer) void {
            self.rope.deinit();
            if (self.file_path) |path| {
                self.rope.allocator.free(path);
            }
        }

        pub fn setContent(self: *TestBuffer, content: []const u8) !void {
            const len = self.rope.len();
            if (len > 0) {
                try self.rope.delete(0, len);
            }
            if (content.len > 0) {
                try self.rope.insert(0, content);
            }
            self.modified = true;
        }

        pub fn getContent(self: *const TestBuffer, allocator: std.mem.Allocator) ![]const u8 {
            return try self.rope.copyRangeAlloc(allocator, .{ .start = 0, .end = self.rope.len() });
        }
    };

    pub const LoggedCommand = struct {
        timestamp: i64,
        command: []const u8,
        args: []const []const u8,
        success: bool,
        error_msg: ?[]const u8 = null,

        pub fn deinit(self: *LoggedCommand, allocator: std.mem.Allocator) void {
            allocator.free(self.command);
            for (self.args) |arg| allocator.free(arg);
            allocator.free(self.args);
            if (self.error_msg) |msg| allocator.free(msg);
        }
    };

    pub const LoggedEvent = struct {
        timestamp: i64,
        event_type: plugin_api.PluginAPI.EventType,
        plugin_id: []const u8,

        pub fn deinit(self: *LoggedEvent, allocator: std.mem.Allocator) void {
            allocator.free(self.plugin_id);
        }
    };

    pub const TestCase = struct {
        name: []const u8,
        setup: ?*const fn (harness: *TestHarness) anyerror!void = null,
        run: *const fn (harness: *TestHarness) anyerror!void,
        teardown: ?*const fn (harness: *TestHarness) anyerror!void = null,
        timeout_ms: u64 = 5000,
    };

    pub const TestResult = struct {
        name: []const u8,
        passed: bool,
        duration_ms: u64,
        error_msg: ?[]const u8 = null,

        pub fn deinit(self: *TestResult, allocator: std.mem.Allocator) void {
            if (self.error_msg) |msg| allocator.free(msg);
        }
    };

    pub fn init(allocator: std.mem.Allocator) !TestHarness {
        var buffers = std.AutoHashMap(u32, TestBuffer).init(allocator);
        errdefer buffers.deinit();

        var initial_buffer = try TestBuffer.init(allocator, 1);
        try buffers.put(1, initial_buffer);

        var cursor_storage = plugin_api.PluginAPI.EditorContext.CursorPosition{
            .line = 0,
            .column = 0,
            .byte_offset = 0,
        };
        var mode_storage = plugin_api.PluginAPI.EditorContext.EditorMode.normal;
        var highlighter = syntax.SyntaxHighlighter.init(allocator);

        const editor_context = try allocator.create(plugin_api.PluginAPI.EditorContext);
        editor_context.* = .{
            .rope = &initial_buffer.rope,
            .cursor_position = &cursor_storage,
            .current_mode = &mode_storage,
            .highlighter = &highlighter,
            .active_buffer_id = 1,
        };

        const api = plugin_api.PluginAPI.init(allocator, editor_context);

        return TestHarness{
            .allocator = allocator,
            .buffers = buffers,
            .plugin_api = api,
            .command_log = .{ .items = &.{}, .capacity = 0, .allocator = allocator },
            .event_log = .{ .items = &.{}, .capacity = 0, .allocator = allocator },
        };
    }

    pub fn deinit(self: *TestHarness) void {
        var it = self.buffers.iterator();
        while (it.next()) |entry| {
            var buffer = entry.value_ptr;
            buffer.deinit();
        }
        self.buffers.deinit();

        self.plugin_api.deinit();

        for (self.command_log.items) |*cmd| {
            cmd.deinit(self.allocator);
        }
        self.command_log.deinit();

        for (self.event_log.items) |*event| {
            event.deinit(self.allocator);
        }
        self.event_log.deinit();

        self.allocator.destroy(self.plugin_api.editor_context);
    }

    pub fn createBuffer(self: *TestHarness, content: []const u8) !u32 {
        const id = self.next_buffer_id;
        self.next_buffer_id += 1;

        var buffer = try TestBuffer.init(self.allocator, id);
        errdefer buffer.deinit();

        try buffer.setContent(content);
        try self.buffers.put(id, buffer);

        return id;
    }

    pub fn switchBuffer(self: *TestHarness, buffer_id: u32) !void {
        if (!self.buffers.contains(buffer_id)) return error.BufferNotFound;
        self.plugin_api.editor_context.active_buffer_id = buffer_id;

        const buffer = self.buffers.getPtr(buffer_id).?;
        self.plugin_api.editor_context.rope = &buffer.rope;
        self.plugin_api.editor_context.cursor_position.* = buffer.cursor;
    }

    pub fn getBufferContent(self: *TestHarness, buffer_id: u32) ![]const u8 {
        const buffer = self.buffers.get(buffer_id) orelse return error.BufferNotFound;
        return try buffer.getContent(self.allocator);
    }

    pub fn setBufferContent(self: *TestHarness, buffer_id: u32, content: []const u8) !void {
        var buffer = self.buffers.getPtr(buffer_id) orelse return error.BufferNotFound;
        try buffer.setContent(content);
    }

    pub fn execCommand(self: *TestHarness, command: []const u8, args: []const []const u8) !void {
        const start_time = std.time.milliTimestamp();

        const success = blk: {
            self.plugin_api.executeCommand(command, "test_harness", args) catch |err| {
                const error_msg = try std.fmt.allocPrint(self.allocator, "{}", .{err});
                try self.logCommand(command, args, false, error_msg);
                break :blk false;
            };
            try self.logCommand(command, args, true, null);
            break :blk true;
        };

        if (self.verbose) {
            const duration = std.time.milliTimestamp() - start_time;
            std.debug.print("[{d}ms] Command '{s}' {s}\n", .{ duration, command, if (success) "OK" else "FAILED" });
        }
    }

    pub fn sendKeys(self: *TestHarness, keys: []const u8, mode: plugin_api.PluginAPI.EditorContext.EditorMode) !void {
        _ = try self.plugin_api.handleKeystroke(keys, mode);
        if (self.verbose) {
            std.debug.print("Keys: '{s}' in {s} mode\n", .{ keys, @tagName(mode) });
        }
    }

    pub fn assertBufferContent(self: *TestHarness, buffer_id: u32, expected: []const u8) !void {
        const actual = try self.getBufferContent(buffer_id);
        defer self.allocator.free(actual);

        if (!std.mem.eql(u8, actual, expected)) {
            std.debug.print("Buffer content mismatch:\nExpected: {s}\nActual: {s}\n", .{ expected, actual });
            return error.AssertionFailed;
        }
    }

    pub fn assertCursorPosition(self: *TestHarness, line: usize, column: usize) !void {
        const cursor = self.plugin_api.editor_context.cursor_position.*;
        if (cursor.line != line or cursor.column != column) {
            std.debug.print("Cursor position mismatch:\nExpected: ({d}, {d})\nActual: ({d}, {d})\n", .{
                line,
                column,
                cursor.line,
                cursor.column,
            });
            return error.AssertionFailed;
        }
    }

    pub fn assertMode(self: *TestHarness, expected_mode: plugin_api.PluginAPI.EditorContext.EditorMode) !void {
        const actual_mode = self.plugin_api.editor_context.current_mode.*;
        if (actual_mode != expected_mode) {
            std.debug.print("Mode mismatch:\nExpected: {s}\nActual: {s}\n", .{
                @tagName(expected_mode),
                @tagName(actual_mode),
            });
            return error.AssertionFailed;
        }
    }

    pub fn runTest(self: *TestHarness, test_case: TestCase) !TestResult {
        const start_time = std.time.milliTimestamp();

        if (self.verbose) {
            std.debug.print("\n=== Running test: {s} ===\n", .{test_case.name});
        }

        if (test_case.setup) |setup| {
            try setup(self);
        }

        const outcome = blk: {
            test_case.run(self) catch |err| {
                const error_msg = try std.fmt.allocPrint(self.allocator, "{}", .{err});
                const duration = @as(u64, @intCast(std.time.milliTimestamp() - start_time));
                break :blk TestResult{
                    .name = test_case.name,
                    .passed = false,
                    .duration_ms = duration,
                    .error_msg = error_msg,
                };
            };
            break :blk TestResult{
                .name = test_case.name,
                .passed = true,
                .duration_ms = @as(u64, @intCast(std.time.milliTimestamp() - start_time)),
            };
        };

        if (test_case.teardown) |teardown| {
            try teardown(self);
        }

        if (self.verbose) {
            const status = if (outcome.passed) "PASS" else "FAIL";
            std.debug.print("[{s}] {s} ({d}ms)\n", .{ status, test_case.name, outcome.duration_ms });
        }

        return outcome;
    }

    pub fn runTests(self: *TestHarness, test_cases: []const TestCase) ![]TestResult {
        var results = try self.allocator.alloc(TestResult, test_cases.len);
        errdefer self.allocator.free(results);

        for (test_cases, 0..) |test_case, idx| {
            results[idx] = try self.runTest(test_case);
        }

        return results;
    }

    fn logCommand(self: *TestHarness, command: []const u8, args: []const []const u8, success: bool, error_msg: ?[]const u8) !void {
        var args_copy = try self.allocator.alloc([]const u8, args.len);
        for (args, 0..) |arg, i| {
            args_copy[i] = try self.allocator.dupe(u8, arg);
        }

        const entry = LoggedCommand{
            .timestamp = std.time.milliTimestamp(),
            .command = try self.allocator.dupe(u8, command),
            .args = args_copy,
            .success = success,
            .error_msg = error_msg,
        };

        try self.command_log.append(self.allocator, entry);
    }
};
