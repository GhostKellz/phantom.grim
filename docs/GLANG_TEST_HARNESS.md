# Ghostlang TestHarness API Reference

Complete API documentation for Grim's `runtime.TestHarness` - a headless testing environment for Ghostlang plugins.

## Source Location

```
/data/projects/grim/runtime/test_harness.zig (394 lines)
```

## Import

```zig
const runtime = @import("runtime");
const TestHarness = runtime.TestHarness;
```

---

## Core API

### Initialization

```zig
pub fn init(allocator: std.mem.Allocator) !TestHarness

pub fn deinit(self: *TestHarness) void
```

**Example:**
```zig
var harness = try TestHarness.init(allocator);
defer harness.deinit();
```

---

## Buffer Management

### Create Buffer

```zig
pub fn createBuffer(self: *TestHarness, content: []const u8) !u32
```

Creates a new test buffer with initial content. Returns buffer ID.

**Example:**
```zig
const buf_id = try harness.createBuffer("hello world");
```

### Switch Buffer

```zig
pub fn switchBuffer(self: *TestHarness, buffer_id: u32) !void
```

Switches active buffer context (updates rope, cursor in editor_context).

**Example:**
```zig
try harness.switchBuffer(buf_id);
```

### Get Buffer Content

```zig
pub fn getBufferContent(self: *TestHarness, buffer_id: u32) ![]const u8
```

Returns buffer content. **Caller must free the returned slice.**

**Example:**
```zig
const content = try harness.getBufferContent(buf_id);
defer allocator.free(content);
```

### Set Buffer Content

```zig
pub fn setBufferContent(self: *TestHarness, buffer_id: u32, content: []const u8) !void
```

Replaces entire buffer content.

**Example:**
```zig
try harness.setBufferContent(buf_id, "new content");
```

---

## Command Execution

### Execute Command

```zig
pub fn execCommand(self: *TestHarness, command: []const u8, args: []const []const u8) !void
```

Executes a plugin command with arguments. Logs success/failure with timestamps.

**Example:**
```zig
try harness.execCommand("autopair", &.{ "enable", "()" });
```

### Send Keys

```zig
pub fn sendKeys(self: *TestHarness, keys: []const u8, mode: plugin_api.PluginAPI.EditorContext.EditorMode) !void
```

Simulates keystroke input in a specific editor mode.

**Modes:** `.normal`, `.insert`, `.visual`, `.command`

**Example:**
```zig
try harness.sendKeys("i", .normal);  // Enter insert mode
try harness.sendKeys("hello", .insert);
```

---

## Assertions

### Assert Buffer Content

```zig
pub fn assertBufferContent(self: *TestHarness, buffer_id: u32, expected: []const u8) !void
```

Asserts buffer content matches expected string. Returns `error.AssertionFailed` on mismatch.

**Example:**
```zig
try harness.assertBufferContent(buf_id, "expected text");
```

### Assert Cursor Position

```zig
pub fn assertCursorPosition(self: *TestHarness, line: usize, column: usize) !void
```

Asserts cursor at (line, column). 0-indexed.

**Example:**
```zig
try harness.assertCursorPosition(0, 5);  // Line 1, column 6
```

### Assert Mode

```zig
pub fn assertMode(self: *TestHarness, expected_mode: plugin_api.PluginAPI.EditorContext.EditorMode) !void
```

Asserts current editor mode.

**Example:**
```zig
try harness.assertMode(.insert);
```

---

## Test Case Framework

### TestCase Struct

```zig
pub const TestCase = struct {
    name: []const u8,
    setup: ?*const fn (harness: *TestHarness) anyerror!void = null,
    run: *const fn (harness: *TestHarness) anyerror!void,
    teardown: ?*const fn (harness: *TestHarness) anyerror!void = null,
    timeout_ms: u64 = 5000,
};
```

### Run Test

```zig
pub fn runTest(self: *TestHarness, test_case: TestCase) !TestResult
```

Executes a single test case with setup/run/teardown lifecycle.

**Example:**
```zig
const test_case = TestHarness.TestCase{
    .name = "autopair parentheses",
    .setup = setupAutopair,
    .run = testParensPair,
    .teardown = null,
};

const result = try harness.runTest(test_case);
defer if (result.error_msg) |msg| allocator.free(msg);

if (!result.passed) {
    std.debug.print("Test failed: {s}\n", .{result.error_msg.?});
}
```

### Run Tests (Batch)

```zig
pub fn runTests(self: *TestHarness, test_cases: []const TestCase) ![]TestResult
```

Runs multiple test cases and returns array of results.

**Example:**
```zig
const tests = &[_]TestHarness.TestCase{
    test1, test2, test3,
};

const results = try harness.runTests(tests);
defer allocator.free(results);

for (results) |result| {
    defer if (result.error_msg) |msg| allocator.free(msg);
    std.debug.print("{s}: {s}\n", .{result.name, if (result.passed) "PASS" else "FAIL"});
}
```

### TestResult Struct

```zig
pub const TestResult = struct {
    name: []const u8,
    passed: bool,
    duration_ms: u64,
    error_msg: ?[]const u8 = null,

    pub fn deinit(self: *TestResult, allocator: std.mem.Allocator) void
};
```

---

## Internal Data Structures

### TestBuffer

```zig
pub const TestBuffer = struct {
    id: u32,
    rope: core.Rope,
    file_path: ?[]const u8 = null,
    modified: bool = false,
    cursor: plugin_api.PluginAPI.EditorContext.CursorPosition,

    pub fn init(allocator: std.mem.Allocator, id: u32) !TestBuffer
    pub fn deinit(self: *TestBuffer) void
    pub fn setContent(self: *TestBuffer, content: []const u8) !void
    pub fn getContent(self: *const TestBuffer, allocator: std.mem.Allocator) ![]const u8
};
```

### LoggedCommand

```zig
pub const LoggedCommand = struct {
    timestamp: i64,
    command: []const u8,
    args: []const []const u8,
    success: bool,
    error_msg: ?[]const u8 = null,

    pub fn deinit(self: *LoggedCommand, allocator: std.mem.Allocator) void
};
```

### LoggedEvent

```zig
pub const LoggedEvent = struct {
    timestamp: i64,
    event_type: plugin_api.PluginAPI.EventType,
    plugin_id: []const u8,

    pub fn deinit(self: *LoggedEvent, allocator: std.mem.Allocator) void
};
```

---

## Complete Example: Autopair Testing

```zig
const std = @import("std");
const runtime = @import("runtime");
const TestHarness = runtime.TestHarness;

fn setupAutopair(harness: *TestHarness) !void {
    try harness.execCommand("autopair", &.{"enable"});
    _ = try harness.createBuffer("");
    try harness.switchBuffer(2);  // Switch to new buffer
}

fn testParensPair(harness: *TestHarness) !void {
    // Type opening paren
    try harness.sendKeys("(", .insert);

    // Assert closing paren was inserted
    try harness.assertBufferContent(2, "()");

    // Assert cursor is between parens
    try harness.assertCursorPosition(0, 1);
}

fn testNestedPairs(harness: *TestHarness) !void {
    try harness.setBufferContent(2, "");
    try harness.sendKeys("(", .insert);
    try harness.sendKeys("{", .insert);
    try harness.sendKeys("[", .insert);

    try harness.assertBufferContent(2, "([{}])");
    try harness.assertCursorPosition(0, 3);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var harness = try TestHarness.init(allocator);
    defer harness.deinit();
    harness.verbose = true;  // Enable debug output

    const tests = &[_]TestHarness.TestCase{
        .{
            .name = "autopair: parentheses",
            .setup = setupAutopair,
            .run = testParensPair,
        },
        .{
            .name = "autopair: nested pairs",
            .setup = setupAutopair,
            .run = testNestedPairs,
        },
    };

    const results = try harness.runTests(tests);
    defer allocator.free(results);

    var passed: usize = 0;
    for (results) |result| {
        defer if (result.error_msg) |msg| allocator.free(msg);

        const status = if (result.passed) "✓" else "✗";
        std.debug.print("{s} {s} ({d}ms)\n", .{
            status, result.name, result.duration_ms
        });

        if (result.error_msg) |msg| {
            std.debug.print("  Error: {s}\n", .{msg});
        }

        if (result.passed) passed += 1;
    }

    std.debug.print("\n{d}/{d} tests passed\n", .{passed, results.len});
}
```

---

## Comment Plugin Example

```zig
fn setupCommentPlugin(harness: *TestHarness) !void {
    try harness.execCommand("comment", &.{"enable"});
}

fn testSingleLineComment(harness: *TestHarness) !void {
    const buf = try harness.createBuffer("local x = 10");
    try harness.switchBuffer(buf);

    // Trigger comment command
    try harness.execCommand("comment", &.{"toggle"});

    // Assert comment was added
    try harness.assertBufferContent(buf, "-- local x = 10");
}

fn testBlockComment(harness: *TestHarness) !void {
    const buf = try harness.createBuffer("function test()\n  return 42\nend");
    try harness.switchBuffer(buf);

    // Select lines 1-3 (entire function)
    try harness.sendKeys("V", .normal);  // Visual line mode
    try harness.sendKeys("jj", .visual); // Select 3 lines
    try harness.execCommand("comment", &.{"block"});

    const expected =
        \\--[[
        \\function test()
        \\  return 42
        \\end
        \\--]]
    ;

    try harness.assertBufferContent(buf, expected);
}
```

---

## Running Tests

### From Grim Build System

```bash
zig build test --summary all
```

### Standalone Test File

Create `test_ghostlang_plugin.zig` in your plugin directory:

```zig
const std = @import("std");
const runtime = @import("runtime");  // From grim dependency

test "ghostlang plugin autopair" {
    var harness = try runtime.TestHarness.init(std.testing.allocator);
    defer harness.deinit();

    // Your tests here
}
```

Run with:
```bash
zig test test_ghostlang_plugin.zig --deps runtime --mod runtime::/data/projects/grim/runtime/mod.zig
```

---

## Accessing TestBuffer Fields

The harness maintains buffers internally. Access via:

```zig
// Get buffer reference (internal API, use with caution)
const buffer = harness.buffers.getPtr(buffer_id).?;

// Access rope directly
const rope_len = buffer.rope.len();

// Modify cursor
buffer.cursor.line = 5;
buffer.cursor.column = 10;
buffer.cursor.byte_offset = 50;
```

---

## Verbose Mode

Enable detailed logging:

```zig
harness.verbose = true;
```

Output example:
```
=== Running test: autopair: parentheses ===
Keys: '(' in insert mode
[15ms] Command 'autopair' OK
[PASS] autopair: parentheses (15ms)
```

---

## Command and Event Logs

Access execution history:

```zig
// Inspect command log
for (harness.command_log.items) |cmd| {
    std.debug.print("Cmd: {s} @ {d} - {s}\n", .{
        cmd.command,
        cmd.timestamp,
        if (cmd.success) "OK" else "FAIL"
    });
}

// Inspect event log
for (harness.event_log.items) |event| {
    std.debug.print("Event: {s} from {s} @ {d}\n", .{
        @tagName(event.event_type),
        event.plugin_id,
        event.timestamp,
    });
}
```

---

## Integration with Grim Runtime

The TestHarness provides a full `PluginAPI.EditorContext`:

```zig
pub const TestHarness = struct {
    allocator: std.mem.Allocator,
    buffers: std.AutoHashMap(u32, TestBuffer),
    next_buffer_id: u32 = 1,
    plugin_api: plugin_api.PluginAPI,
    command_log: std.ArrayList(LoggedCommand),
    event_log: std.ArrayList(LoggedEvent),
    verbose: bool = false,
};
```

Access the editor context:
```zig
const ctx = harness.plugin_api.editor_context;
const current_rope = ctx.rope;
const cursor = ctx.cursor_position.*;
const mode = ctx.current_mode.*;
```

---

## Best Practices

1. **Always defer deinit**: Both TestHarness and TestResult allocate memory
2. **Free buffer content**: `getBufferContent()` returns owned slices
3. **Use setup/teardown**: Isolate test state to avoid cross-contamination
4. **Check error messages**: `TestResult.error_msg` provides assertion details
5. **Enable verbose mode**: During development for detailed execution traces
6. **Test cursor state**: Verify cursor position after editor operations
7. **Test mode transitions**: Ensure your plugin respects editor modes

---

## Troubleshooting

### "BufferNotFound" Error
- Ensure buffer ID exists via `createBuffer()` or initial buffer (ID=1)
- Check `switchBuffer()` was called with correct ID

### Assertion Failures
- Enable `verbose = true` to see actual vs expected values
- Use `getBufferContent()` to inspect buffer state before assertions

### Command Execution Fails
- Check command is registered in PluginAPI
- Verify args array matches command signature
- Review `command_log` for error messages

### Memory Leaks
- Always defer `harness.deinit()`
- Free `getBufferContent()` returned slices
- Free `TestResult.error_msg` if present

---

## Source Code Reference

Full implementation: `/data/projects/grim/runtime/test_harness.zig`

Key sections:
- Lines 1-97: Struct definitions and types
- Lines 98-158: Init/deinit and internal setup
- Lines 160-194: Buffer management API
- Lines 196-223: Command execution and keystroke simulation
- Lines 225-260: Assertion helpers
- Lines 262-317: Test case framework
- Lines 335-394: Example tests

---

## Version Compatibility

- **Grim Runtime:** 0.1.0+
- **Zig Version:** 0.16.0-dev or later
- **Dependencies:** core (Rope), plugin_api (PluginAPI), syntax (SyntaxHighlighter)

---

## Contact

For TestHarness issues or API questions:
- File an issue in the Grim repository
- Reference: `/data/projects/grim/runtime/test_harness.zig`

---

**Last Updated:** 2025-10-09
