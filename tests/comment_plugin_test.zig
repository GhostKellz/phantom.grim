const std = @import("std");
const ghostlang = @import("ghostlang");
const harness_support = @import("support/test_harness.zig");
const TestHarness = harness_support.TestHarness;

var active_harness: ?*TestHarness = null;

fn phantomHarnessSetBuffer(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    const harness = active_harness orelse return .{ .nil = {} };

    if (args.len < 1) return .{ .nil = {} };
    const buffer_id: u32 = 1;

    // Extract buffer content from args if string
    const content = switch (args[0]) {
        .string => |str| str,
        else => "",
    };

    harness.setBufferContent(buffer_id, content) catch return .{ .nil = {} };
    return .{ .nil = {} };
}

fn phantomHarnessSetCursor(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    const harness = active_harness orelse return .{ .nil = {} };

    if (args.len < 2) return .{ .nil = {} };

    const line = switch (args[0]) {
        .number => |n| @as(usize, @intFromFloat(n)),
        else => 1,
    };
    const col = switch (args[1]) {
        .number => |n| @as(usize, @intFromFloat(n)),
        else => 0,
    };

    harness.plugin_api.editor_context.cursor_position.* = .{
        .line = if (line > 0) line - 1 else 0,
        .column = col,
        .byte_offset = 0,
    };

    return .{ .nil = {} };
}

fn initGhostEngine(allocator: std.mem.Allocator) !ghostlang.ScriptEngine {
    const config = ghostlang.EngineConfig{
        .allocator = allocator,
        .allow_io = false,
        .allow_syscalls = false,
        .deterministic = false,
        .memory_limit = 8 * 1024 * 1024,
        .execution_timeout_ms = 5000,
    };

    var engine = try ghostlang.ScriptEngine.create(config);
    try engine.registerFunction("phantom_harness_set_buffer", phantomHarnessSetBuffer);
    try engine.registerFunction("phantom_harness_set_cursor", phantomHarnessSetCursor);
    return engine;
}

fn runScriptVoid(engine: *ghostlang.ScriptEngine, harness: *TestHarness, source: []const u8) !void {
    var script = engine.loadScript(source) catch |err| {
        std.debug.print("Ghostlang parse failed: {s}\n", .{@errorName(err)});
        return err;
    };
    defer script.deinit();

    const previous = active_harness;
    active_harness = harness;
    defer active_harness = previous;

    _ = try script.run();
}

test "comment plugin basic test via ghostlang" {
    const allocator = std.testing.allocator;

    var harness = try TestHarness.init(allocator);
    defer harness.deinit();

    var engine = try initGhostEngine(allocator);
    defer engine.deinit();

    // Load the comment.gza test file which has its own test cases
    const test_path = "tests/comment_plugin.gza";
    const test_source = try std.fs.cwd().readFileAlloc(test_path, allocator, @enumFromInt(64 * 1024));
    defer allocator.free(test_source);

    try runScriptVoid(&engine, &harness, test_source);

    // If we got here, the ghostlang test passed
    std.debug.print("[PASS] comment plugin ghostlang tests\n", .{});
}
