# Phantom.Grim Development TODO

## Overview

Phantom.Grim is the next evolution of the grim editor, leveraging:
- **PhantomTUI v0.5.0** for high-performance text rendering
- **PhantomBuffer** for native undo/redo, multi-cursor, and diagnostic support
- **grim runtime** for plugin system and test harness
- **ghostls v0.3.0** for comprehensive LSP integration

This document outlines the development roadmap for building phantom.grim on top of the grim foundation.

---

## Phase 1: Dependency Setup & Test Harness Integration

### 1.1 Add grim as a Dependency

**Goal:** Import grim's TestHarness module for comprehensive plugin testing.

**Implementation:**

```bash
cd /data/projects/phantom.grim
zig fetch --save https://github.com/ghostkellz/grim/archive/refs/heads/main.tar.gz
```

This will update `build.zig.zon` with a grim dependency entry.

**Alternative (Local Development):**

For faster iteration during development, add grim as a local path dependency in `build.zig.zon`:

```zig
.dependencies = .{
    .grim = .{
        .path = "../grim",
    },
    // ... other dependencies
},
```

Then in `build.zig`, **enable test harness export** and use the module:

```zig
const grim = b.dependency("grim", .{
    .target = target,
    .optimize = optimize,
    .@"export-test-harness" = true, // ⭐ IMPORTANT: Enable test harness export
});

// Use the test_harness module directly
const test_harness_mod = grim.module("test_harness");

// Add to your test executable or module
const your_tests = b.addTest(.{
    .root_module = b.createModule(.{
        .root_source_file = b.path("tests/your_test.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "test_harness", .module = test_harness_mod },
        },
    }),
});

// Optional: If you also need other grim modules
// exe.root_module.addImport("grim_runtime", grim.module("runtime"));
// exe.root_module.addImport("grim_core", grim.module("core"));
// exe.root_module.addImport("grim_lsp", grim.module("lsp"));
// exe.root_module.addImport("grim_syntax", grim.module("syntax"));
```

**📚 See Also:** `/data/projects/grim/docs/TEST_HARNESS_USAGE.md` for complete integration guide.

### 1.2 Create Test Infrastructure

**File:** `tests/phantom_test_helpers.zig`

```zig
const std = @import("std");
const TestHarness = @import("test_harness").TestHarness; // From grim dependency

pub const TestCase = TestHarness.TestCase;

/// Phantom.Grim-specific test helpers
pub const PhantomTestHelpers = struct {
    harness: *TestHarness,

    pub fn init(allocator: std.mem.Allocator) !PhantomTestHelpers {
        const harness = try TestHarness.init(allocator);
        return .{ .harness = harness };
    }

    pub fn deinit(self: *PhantomTestHelpers) void {
        self.harness.deinit();
    }

    /// Load phantom.grim config
    pub fn loadPhantomConfig(self: *PhantomTestHelpers) !void {
        try self.harness.execCommand(":set phantom_mode true");
        try self.harness.execCommand(":set nerd_fonts true");
    }

    /// Create buffer with PhantomBuffer backend
    pub fn createPhantomBuffer(self: *PhantomTestHelpers, name: []const u8) !u32 {
        const buffer_id = try self.harness.createBuffer(name);
        // Enable PhantomBuffer features
        try self.harness.execCommand(":buffer_type phantom");
        return buffer_id;
    }

    /// Test undo/redo (PhantomBuffer feature)
    pub fn testUndo(self: *PhantomTestHelpers) !void {
        try self.harness.sendKeys("i");
        try self.harness.sendKeys("hello");
        try self.harness.sendKeys("\x1b"); // ESC
        try self.harness.assertBufferContent("hello");

        try self.harness.sendKeys("u"); // Undo
        try self.harness.assertBufferContent("");
    }
};
```

### 1.3 Create Plugin Test Template

**File:** `tests/plugin_test_template.zig`

```zig
const std = @import("std");
const TestHarness = @import("test_harness").TestHarness; // From grim dependency

test "phantom.grim plugin: example" {
    const allocator = std.testing.allocator;

    var harness = try TestHarness.init(allocator);
    defer harness.deinit();

    // Create buffer
    _ = try harness.createBuffer("test.zig");

    // Load plugin
    try harness.execCommand(":PluginLoad phantom_autopair");

    // Test plugin behavior
    try harness.sendKeys("i");
    try harness.sendKeys("(");
    try harness.assertBufferContent("()");

    // Cursor should be between parens
    try harness.assertCursorPosition(0, 1);
}
```

---

## Phase 2: PhantomBuffer Integration

### 2.1 Create PhantomBufferManager

**File:** `src/phantom_buffer_manager.zig`

Based on `/data/projects/grim/PHANTOMBUFFER.md`, implement the PhantomBufferManager:

```zig
const std = @import("std");
const PhantomBuffer = @import("phantom_buffer.zig").PhantomBuffer;

pub const PhantomBufferManager = struct {
    allocator: std.mem.Allocator,
    buffers: std.ArrayList(ManagedBuffer),
    active_buffer_id: u32 = 0,
    next_buffer_id: u32 = 1,

    pub const ManagedBuffer = struct {
        id: u32,
        phantom_buffer: PhantomBuffer,
        display_name: []const u8,
        last_accessed: i64,
    };

    pub fn init(allocator: std.mem.Allocator) !PhantomBufferManager {
        // Create initial phantom buffer
        var buffers = std.ArrayList(ManagedBuffer).init(allocator);
        const initial = try PhantomBuffer.init(allocator, 0, .{});

        try buffers.append(.{
            .id = 0,
            .phantom_buffer = initial,
            .display_name = try std.fmt.allocPrint(allocator, "[No Name]", .{}),
            .last_accessed = std.time.timestamp(),
        });

        return .{
            .allocator = allocator,
            .buffers = buffers,
        };
    }

    // Implement same API as grim's BufferManager
    pub fn getActiveBuffer(self: *PhantomBufferManager) ?*ManagedBuffer { ... }
    pub fn createBuffer(self: *PhantomBufferManager) !u32 { ... }
    pub fn openFile(self: *PhantomBufferManager, path: []const u8) !u32 { ... }
    pub fn saveActiveBuffer(self: *PhantomBufferManager) !void { ... }
    pub fn closeBuffer(self: *PhantomBufferManager, buffer_id: u32) !void { ... }
    pub fn nextBuffer(self: *PhantomBufferManager) void { ... }
    pub fn previousBuffer(self: *PhantomBufferManager) void { ... }

    pub fn deinit(self: *PhantomBufferManager) void { ... }
};
```

### 2.2 Implement PhantomTUI (Wrapper around grim's SimpleTUI)

**File:** `src/phantom_tui.zig`

```zig
const std = @import("std");
const grim_tui = @import("grim_ui_tui");
const PhantomBufferManager = @import("phantom_buffer_manager.zig").PhantomBufferManager;
const FontManager = @import("grim_ui_tui").FontManager;

pub const PhantomTUI = struct {
    allocator: std.mem.Allocator,
    buffer_manager: PhantomBufferManager,
    font_manager: FontManager,
    running: bool,

    pub fn init(allocator: std.mem.Allocator) !*PhantomTUI {
        const self = try allocator.create(PhantomTUI);
        self.* = .{
            .allocator = allocator,
            .buffer_manager = try PhantomBufferManager.init(allocator),
            .font_manager = FontManager.init(allocator, true), // Nerd Fonts on
            .running = true,
        };
        return self;
    }

    pub fn deinit(self: *PhantomTUI) void {
        self.buffer_manager.deinit();
        self.font_manager.deinit();
        self.allocator.destroy(self);
    }

    pub fn run(self: *PhantomTUI) !void {
        // Main render loop using PhantomBuffer
        while (self.running) {
            try self.render();
            try self.handleInput();
        }
    }

    fn render(self: *PhantomTUI) !void {
        const buffer = self.buffer_manager.getActiveBuffer() orelse return;

        // Use PhantomBuffer's native rendering
        if (buffer.phantom_buffer.isUsingPhantom()) {
            // Direct PhantomTUI rendering (GPU-accelerated)
            try self.renderPhantomNative(buffer);
        } else {
            // Fallback to ANSI terminal rendering
            try self.renderFallback(buffer);
        }
    }

    fn handleInput(self: *PhantomTUI) !void {
        // Enhanced input handling with PhantomBuffer features
        const key = try self.readKey();

        switch (key) {
            'u' => try self.performUndo(),
            18 => try self.performRedo(), // Ctrl+R
            // ... other keybindings
            else => {},
        }
    }

    fn performUndo(self: *PhantomTUI) !void {
        const buffer = self.buffer_manager.getActiveBuffer() orelse return;
        try buffer.phantom_buffer.undo();
    }

    fn performRedo(self: *PhantomTUI) !void {
        const buffer = self.buffer_manager.getActiveBuffer() orelse return;
        try buffer.phantom_buffer.redo();
    }
};
```

---

## Phase 3: Plugin System Enhancement

### 3.1 PhantomBuffer Plugin API

**File:** `src/plugin_api.zig`

Extend grim's plugin API with PhantomBuffer-specific capabilities:

```zig
const std = @import("std");
const grim_runtime = @import("grim_runtime");
const PhantomBuffer = @import("phantom_buffer.zig").PhantomBuffer;

pub const PhantomPluginAPI = struct {
    base: grim_runtime.PluginAPI,

    /// Get PhantomBuffer instance for active buffer
    pub fn getPhantomBuffer(self: *PhantomPluginAPI, buffer_id: u32) ?*PhantomBuffer {
        // Implementation
    }

    /// Undo last operation
    pub fn undo(self: *PhantomPluginAPI, buffer_id: u32) !void {
        const buffer = self.getPhantomBuffer(buffer_id) orelse return error.BufferNotFound;
        try buffer.undo();
    }

    /// Redo last undone operation
    pub fn redo(self: *PhantomPluginAPI, buffer_id: u32) !void {
        const buffer = self.getPhantomBuffer(buffer_id) orelse return error.BufferNotFound;
        try buffer.redo();
    }

    /// Add cursor at position (multi-cursor support)
    pub fn addCursor(self: *PhantomPluginAPI, buffer_id: u32, line: usize, col: usize) !void {
        const buffer = self.getPhantomBuffer(buffer_id) orelse return error.BufferNotFound;
        try buffer.addCursor(.{ .line = line, .column = col, .byte_offset = 0 });
    }

    /// Clear all secondary cursors
    pub fn clearCursors(self: *PhantomPluginAPI, buffer_id: u32) !void {
        const buffer = self.getPhantomBuffer(buffer_id) orelse return error.BufferNotFound;
        buffer.clearSecondaryCursors();
    }

    /// Add LSP diagnostic marker
    pub fn addDiagnostic(
        self: *PhantomPluginAPI,
        buffer_id: u32,
        line: usize,
        col: usize,
        severity: PhantomBuffer.DiagnosticSeverity,
        message: []const u8,
    ) !void {
        const buffer = self.getPhantomBuffer(buffer_id) orelse return error.BufferNotFound;
        try buffer.addDiagnostic(line, col, severity, message);
    }
};
```

### 3.2 Migrate Existing Plugins

Port plugins from grim to use PhantomBuffer features:

**Autopair Plugin (Enhanced):**
```zig
// Uses PhantomBuffer's undo/redo for better integration
pub fn onInsert(api: *PhantomPluginAPI, buffer_id: u32, char: u8) !void {
    const pairs = .{
        .{ '(', ')' },
        .{ '[', ']' },
        .{ '{', '}' },
        .{ '"', '"' },
        .{ '\'', '\'' },
    };

    for (pairs) |pair| {
        if (char == pair[0]) {
            // Insert closing bracket
            try api.insertText(buffer_id, &[_]u8{pair[1]});
            try api.moveCursorLeft(buffer_id);
            // PhantomBuffer automatically creates undo point
            break;
        }
    }
}
```

---

## Phase 4: Testing Strategy

### 4.1 Unit Tests

**File:** `tests/phantom_buffer_test.zig`

```zig
const std = @import("std");
const PhantomBuffer = @import("phantom_buffer").PhantomBuffer;

test "PhantomBuffer undo/redo" {
    const allocator = std.testing.allocator;

    var buffer = try PhantomBuffer.init(allocator, 1, .{});
    defer buffer.deinit();

    // Insert text
    try buffer.insertText(0, "hello");
    try std.testing.expectEqualStrings("hello", try buffer.getContent());

    // Undo
    try buffer.undo();
    try std.testing.expectEqualStrings("", try buffer.getContent());

    // Redo
    try buffer.redo();
    try std.testing.expectEqualStrings("hello", try buffer.getContent());
}

test "PhantomBuffer multi-cursor" {
    const allocator = std.testing.allocator;

    var buffer = try PhantomBuffer.init(allocator, 1, .{});
    defer buffer.deinit();

    try buffer.insertText(0, "line1\nline2\nline3");

    // Add cursors on each line
    try buffer.addCursor(.{ .line = 1, .column = 0, .byte_offset = 6 });
    try buffer.addCursor(.{ .line = 2, .column = 0, .byte_offset = 12 });

    // Test simultaneous editing would go here
}
```

### 4.2 Integration Tests using TestHarness

**File:** `tests/integration_test.zig`

```zig
const std = @import("std");
const TestHarness = @import("test_harness").TestHarness; // From grim dependency

test "phantom.grim full workflow" {
    const allocator = std.testing.allocator;

    var harness = try TestHarness.init(allocator);
    defer harness.deinit();

    // Create buffer
    _ = try harness.createBuffer("test.zig");

    // Type some code
    try harness.sendKeys("i");
    try harness.sendKeys("const std = @import(\"std\");");
    try harness.sendKeys("\x1b"); // ESC

    // Verify LSP features
    try harness.assertLSPActive();

    // Test undo
    try harness.sendKeys("u");
    try harness.assertBufferContent("");

    // Test redo
    try harness.sendKeys("\x12"); // Ctrl+R
    try harness.assertBufferContent("const std = @import(\"std\");");

    // Test multi-cursor (Ctrl+Alt+Down)
    try harness.sendKeys("j"); // Move down
    try harness.sendKeys("\x1b[1;7B"); // Ctrl+Alt+Down
    // ... test multi-cursor editing
}
```

### 4.3 Plugin Tests

**File:** `tests/autopair_plugin_test.zig`

Use the TestHarness pattern from `GLANG_TEST_HARNESS.md`:

```zig
const std = @import("std");
const TestHarness = @import("test_harness").TestHarness; // From grim dependency

const autopair_tests = [_]TestHarness.TestCase{
    .{
        .name = "autopair: insert opening paren",
        .initial_content = "",
        .cursor_pos = .{ .line = 0, .col = 0 },
        .commands = &.{
            .{ .send_keys = "i" },
            .{ .send_keys = "(" },
        },
        .expected_content = "()",
        .expected_cursor = .{ .line = 0, .col = 1 },
    },
    .{
        .name = "autopair: skip closing paren",
        .initial_content = "()",
        .cursor_pos = .{ .line = 0, .col = 1 },
        .commands = &.{
            .{ .send_keys = "i" },
            .{ .send_keys = ")" },
        },
        .expected_content = "()",
        .expected_cursor = .{ .line = 0, .col = 2 },
    },
    // ... more test cases
};

test "autopair plugin" {
    const allocator = std.testing.allocator;

    var harness = try TestHarness.init(allocator);
    defer harness.deinit();

    // Load plugin
    try harness.execCommand(":PluginLoad autopair");

    // Run all test cases
    try harness.runTests(&autopair_tests);
}
```

---

## Phase 5: Performance & Optimization

### 5.1 Large File Benchmark

**File:** `tests/performance_test.zig`

```zig
const std = @import("std");
const PhantomBuffer = @import("phantom_buffer").PhantomBuffer;

test "PhantomBuffer performance: 1M lines" {
    const allocator = std.testing.allocator;

    var buffer = try PhantomBuffer.init(allocator, 1, .{});
    defer buffer.deinit();

    // Generate 1M lines
    var content = std.ArrayList(u8).init(allocator);
    defer content.deinit();

    var i: usize = 0;
    while (i < 1_000_000) : (i += 1) {
        try content.writer().print("Line {d}\n", .{i});
    }

    const start = std.time.milliTimestamp();
    try buffer.insertText(0, content.items);
    const insert_time = std.time.milliTimestamp() - start;

    std.debug.print("Inserted 1M lines in {}ms\n", .{insert_time});

    // Test undo performance
    const undo_start = std.time.milliTimestamp();
    try buffer.undo();
    const undo_time = std.time.milliTimestamp() - undo_start;

    std.debug.print("Undo 1M lines in {}ms\n", .{undo_time});

    // Benchmarks should show significant improvement over rope-based Editor
}
```

### 5.2 Rendering Benchmark

Test incremental rendering performance with large files.

---

## Phase 6: Documentation & Polish

### 6.1 Create User Guide

**File:** `docs/USER_GUIDE.md`

- Getting started with phantom.grim
- Configuration options
- PhantomBuffer features (undo/redo, multi-cursor)
- Plugin system
- LSP integration

### 6.2 Create Plugin Development Guide

**File:** `docs/PLUGIN_DEV.md`

- How to write plugins for phantom.grim
- TestHarness usage examples
- PhantomPluginAPI reference
- Best practices

### 6.3 Migration Guide from grim

**File:** `docs/MIGRATION_FROM_GRIM.md`

- Key differences between grim and phantom.grim
- Configuration changes
- Plugin compatibility
- Performance improvements

---

## Implementation Timeline

### Week 1: Foundation
- ✅ Add grim dependency
- ✅ Set up test infrastructure with TestHarness
- ✅ Create basic PhantomBufferManager

### Week 2: Core Features
- ⬜ Implement PhantomTUI
- ⬜ Integrate undo/redo
- ⬜ Implement multi-cursor support
- ⬜ Wire up LSP diagnostics to PhantomBuffer

### Week 3: Plugin System
- ⬜ Create PhantomPluginAPI
- ⬜ Migrate autopair plugin
- ⬜ Migrate comment plugin
- ⬜ Test all plugins with TestHarness

### Week 4: Testing & Performance
- ⬜ Write comprehensive unit tests
- ⬜ Write integration tests
- ⬜ Run performance benchmarks
- ⬜ Optimize based on benchmarks

### Week 5: Documentation & Release
- ⬜ Write user guide
- ⬜ Write plugin development guide
- ⬜ Create migration guide
- ⬜ Prepare v0.1.0 release

---

## Immediate Next Steps

1. **Add grim dependency:**
   ```bash
   cd /data/projects/phantom.grim
   zig fetch --save https://github.com/ghostkellz/grim/archive/refs/heads/main.tar.gz
   ```

2. **Update build.zig with test harness export:**
   ```zig
   const grim = b.dependency("grim", .{
       .target = target,
       .optimize = optimize,
       .@"export-test-harness" = true, // Enable TestHarness export
   });

   // Get test_harness module
   const test_harness_mod = grim.module("test_harness");

   // Add to your test module
   const tests = b.addTest(.{
       .root_module = b.createModule(.{
           .root_source_file = b.path("tests/harness_test.zig"),
           .target = target,
           .optimize = optimize,
           .imports = &.{
               .{ .name = "test_harness", .module = test_harness_mod },
           },
       }),
   });

   const run_tests = b.addRunArtifact(tests);
   const test_step = b.step("test", "Run tests");
   test_step.dependOn(&run_tests.step);
   ```

3. **Create first test:**
   ```bash
   mkdir -p tests
   touch tests/harness_test.zig
   ```

4. **Verify TestHarness import:**
   ```zig
   const std = @import("std");
   const TestHarness = @import("test_harness").TestHarness;

   test "TestHarness basic usage" {
       const allocator = std.testing.allocator;
       var harness = try TestHarness.init(allocator);
       defer harness.deinit();

       _ = try harness.createBuffer("test.txt");
       try harness.sendKeys("i");
       try harness.sendKeys("hello");
       try harness.assertBufferContent("hello");
   }
   ```

5. **Run tests:**
   ```bash
   zig build test
   ```

**📚 Complete guide:** See `/data/projects/grim/docs/TEST_HARNESS_USAGE.md` for detailed integration instructions.

---

## Questions & Decisions

### Q1: Should phantom.grim be a separate binary or a grim mode?

**Decision:** Separate binary that imports grim as a library.

**Rationale:**
- Allows independent versioning
- Cleaner separation of concerns
- Users can choose grim (stable) or phantom.grim (cutting-edge)
- Easier to experiment with new features

### Q2: How to handle grim updates?

**Approach:**
- Pin to specific grim commit hash in build.zig.zon
- Update dependency when needed: `zig fetch --save https://github.com/ghostkellz/grim/archive/[commit-hash].tar.gz`
- Test thoroughly after each grim update

### Q3: Plugin compatibility between grim and phantom.grim?

**Strategy:**
- PhantomPluginAPI extends grim's PluginAPI
- Plugins written for grim should work in phantom.grim
- Phantom.grim-specific features require PhantomPluginAPI

---

## Success Metrics

- ✅ All grim plugins work in phantom.grim
- ✅ Undo/redo working with unlimited history
- ✅ Multi-cursor editing functional
- ✅ 10x+ performance improvement on large files (>100k lines)
- ✅ All LSP features working (completion, hover, diagnostics, etc.)
- ✅ 90%+ test coverage
- ✅ Comprehensive documentation

---

## Resources

- grim repository: https://github.com/ghostkellz/grim
- PhantomTUI v0.5.0 docs: (link when available)
- TestHarness examples: `/data/projects/grim/GLANG_TEST_HARNESS.md`
- PhantomBuffer migration guide: `/data/projects/grim/PHANTOMBUFFER.md`
- LSP integration docs: `/data/projects/grim/NEW_LSP_FEATURES_v0.3.0.md`

---

**Last Updated:** 2025-10-10
**Status:** Ready to begin Phase 1
**Next Action:** Add grim dependency and create first test
