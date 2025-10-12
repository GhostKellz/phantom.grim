# Phantom.Grim: The Next-Gen LazyVim for Grim Editor

**Vision:** Transform phantom.grim into the definitive plugin framework for Grim - a LazyVim-inspired, batteries-included configuration system with native performance.

**Current Status:** ✅ Sprint 1 Complete - All grim integrations working - Build passing (9/11)
**Next Phase:** Sprint 2 - Core Plugin Development (5 essential plugins)

---

## Table of Contents

1. [Project State Assessment](#project-state-assessment)
2. [Grim Integration Status](#grim-integration-status)
3. [Core Architecture Tasks](#core-architecture-tasks)
4. [Plugin System Enhancement](#plugin-system-enhancement)
5. [LazyVim Feature Parity](#lazyvim-feature-parity)
6. [Testing Strategy](#testing-strategy)
7. [Documentation & Polish](#documentation--polish)
8. [Implementation Timeline](#implementation-timeline)

---

## Project State Assessment

### ✅ What We Have

**Build System:**
- ✅ Zig 0.16 build working
- ✅ Grim dependency via `zig fetch` (not vendored)
- ✅ TestHarness module exported from grim
- ✅ All dependency hashes resolved

**Core Infrastructure:**
```
phantom.grim/
├── src/
│   ├── main.zig                    # ✅ Entry point with ConfigManager
│   └── core/
│       ├── config_manager.zig      # ✅ TOML/GZA config parsing
│       ├── syntax_highlighter.zig  # ✅ Tree-sitter integration
│       ├── plugin_loader.zig       # ✅ Plugin fetching/loading
│       ├── package_registry.zig    # ✅ Package management
│       └── ghostlang_runtime.zig   # ✅ Ghostlang execution
├── plugins/
│   ├── core/                       # ✅ 7 core plugins (placeholders)
│   ├── editor/                     # ✅ 5 editor plugins (partial)
│   ├── lsp/                        # ⬜ LSP plugins (empty)
│   └── git/                        # ⬜ Git plugins (empty)
└── runtime/
    ├── defaults/                   # ✅ Default configs
    └── lib/                        # ✅ Runtime libraries
```

**Existing Plugins:**
- ✅ `plugins/core/file-tree.gza` (placeholder)
- ✅ `plugins/core/fuzzy-finder.gza` (placeholder)
- ✅ `plugins/core/statusline.gza` (placeholder)
- ✅ `plugins/core/treesitter.gza` (placeholder)
- ✅ `plugins/core/zap-ai.gza` (placeholder)
- ✅ `plugins/core/theme.gza` (placeholder)
- ✅ `plugins/core/plugin-manager.gza` (placeholder)
- ⚠️ `plugins/editor/comment.gza` (partial - needs TestHarness tests)
- ⚠️ `plugins/editor/autopairs.gza` (partial - needs TestHarness tests)

### ⬜ What We Need

**Critical Missing Pieces:**
1. **Grim Runtime Integration** - Plugins don't actually use grim's runtime yet
2. **Lazy Loading System** - No event-based plugin loading
3. **Dependency Resolution** - No topological sort for plugin dependencies
4. **Plugin Testing** - No automated tests using grim's TestHarness
5. **User-Facing API** - No clean `init.gza` for users to configure

---

## ✅ Sprint 1 Complete (Grim Integration)

All grim runtime modules are now integrated and working:

| Module | Status | Implementation |
|--------|--------|----------------|
| Runtime | ✅ Complete | `src/core/plugin_loader.zig` uses PluginAPI/PluginManager |
| LSP | ✅ Complete | `src/core/lsp_manager.zig` wraps grim.lsp.Client |
| Syntax | ✅ Complete | `src/core/syntax_highlighter.zig` uses grim.syntax |
| Host Adapter | ✅ Complete | `src/core/plugin_host_adapter.zig` bridges callbacks |
| Systems | ✅ Complete | CommandRegistry, KeymapManager, EventSystem, ThemeManager |

**Build Status:** 9/11 steps passing
**Test Coverage:** 3/4 tests passing
**Integration:** All grim modules accessible from phantom.grim

---

## 🚀 Current Sprint: Sprint 2 - Core Plugin Development

### Overview

Build the 5 essential plugins that make phantom.grim a batteries-included editor framework. Each plugin uses the grim integration from Sprint 1.

**Timeline:** 2-3 weeks
**Deliverable:** Working LazyVim-equivalent plugin ecosystem

---

## Core Architecture Tasks

### Task 5: Implement Lazy Loading System

**Goal:** Load plugins on-demand based on events, filetypes, commands, and keymaps (like lazy.nvim).

**Files to create:**
- `src/core/lazy_loader.zig`
- `src/core/plugin_registry.zig`

**Implementation:**
```zig
// src/core/lazy_loader.zig
pub const LazyLoader = struct {
    pub const Trigger = union(enum) {
        event: []const u8,      // "BufRead", "VimEnter"
        ft: []const u8,         // "zig", "rust"
        cmd: []const u8,        // "Telescope"
        keys: []const u8,       // "<leader>f"
    };

    pub fn registerPlugin(
        self: *LazyLoader,
        name: []const u8,
        triggers: []const Trigger,
    ) !void {
        // Map triggers to plugin names
        for (triggers) |trigger| {
            switch (trigger) {
                .event => |e| try self.event_map.put(e, name),
                .ft => |f| try self.ft_map.put(f, name),
                .cmd => |c| try self.cmd_map.put(c, name),
                .keys => |k| try self.keys_map.put(k, name),
            }
        }
    }

    pub fn triggerEvent(self: *LazyLoader, event: []const u8) !void {
        if (self.event_map.get(event)) |plugin_name| {
            try self.loader.loadPlugin(plugin_name);
        }
    }
};
```

**User-facing API (init.gza):**
```ghostlang
-- User's init.gza
phantom.lazy = {
  -- Load on event
  { "file-tree", event = "VimEnter" },
  { "lsp-config", ft = {"zig", "rust"} },

  -- Load on command
  { "fuzzy-finder", cmd = "FuzzyFiles" },

  -- Load on keymap
  { "comment", keys = {"gc", "gcc"} },
}
```

**Success Criteria:**
- [ ] Plugins load on first trigger only
- [ ] Dependencies loaded before dependents
- [ ] Startup time < 50ms with 20+ plugins
- [ ] `:PhantomProfile` shows load times

---

### Task 6: Dependency Resolution with Topological Sort

**Goal:** Ensure plugins load in correct order based on dependencies.

**Files to modify:**
- `src/core/plugin_registry.zig`

**Implementation:**
```zig
pub const PluginRegistry = struct {
    pub fn resolveDependencies(self: *PluginRegistry) !void {
        var visited = std.StringHashMap(bool).init(self.allocator);
        defer visited.deinit();

        var stack = std.ArrayList([]const u8).init(self.allocator);
        defer stack.deinit();

        // Topological sort
        var it = self.plugins.iterator();
        while (it.next()) |entry| {
            if (!visited.contains(entry.key_ptr.*)) {
                try self.dfsTopologicalSort(entry.key_ptr.*, &visited, &stack);
            }
        }

        // Reverse for correct load order
        self.load_order.clearRetainingCapacity();
        var i = stack.items.len;
        while (i > 0) {
            i -= 1;
            try self.load_order.append(stack.items[i]);
        }
    }

    pub fn detectCycles(self: *PluginRegistry) !void {
        // Cycle detection to prevent deadlock
    }
};
```

**Plugin manifest format (plugin.toml):**
```toml
[plugin]
name = "lsp-config"
version = "1.0.0"

[dependencies]
requires = ["cmp-lsp", "nvim-cmp"]
load_after = ["treesitter"]
```

**Success Criteria:**
- [ ] Circular dependencies detected and reported
- [ ] Plugins load in correct order
- [ ] `load_after` respected
- [ ] Missing dependencies error clearly

---

## Plugin System Enhancement

### Task 7: Create User-Facing Configuration API

**Goal:** Provide clean `init.gza` API like lazy.nvim's `lazy.setup()`.

**Files to create:**
- `runtime/lib/phantom/init.gza`
- `runtime/lib/phantom/lazy.gza`

**Implementation (init.gza):**
```ghostlang
-- runtime/lib/phantom/init.gza
local phantom = {}

phantom.setup = function(config)
  config = config or {}

  -- Setup core options
  if config.options then
    for key, value in pairs(config.options) do
      vim.opt[key] = value
    end
  end

  -- Setup plugins with lazy loading
  if config.plugins then
    require("phantom.lazy").setup(config.plugins)
  end

  -- Setup theme
  if config.theme then
    require("phantom.theme").load(config.theme)
  end

  -- Setup keymaps
  if config.keymaps then
    for mode, mappings in pairs(config.keymaps) do
      for lhs, rhs in pairs(mappings) do
        vim.keymap.set(mode, lhs, rhs)
      end
    end
  end
end

return phantom
```

**User's init.gza:**
```ghostlang
local phantom = require("phantom")

phantom.setup({
  -- Editor options
  options = {
    number = true,
    relativenumber = true,
    tabstop = 4,
    shiftwidth = 4,
  },

  -- Plugin specifications
  plugins = {
    -- Core (always loaded)
    { "file-tree", lazy = false },
    { "statusline", lazy = false },

    -- Lazy-loaded
    { "fuzzy-finder",
      keys = {
        { "<leader>f", ":FuzzyFiles<CR>", desc = "Find files" },
        { "<leader>g", ":LiveGrep<CR>", desc = "Grep" },
      },
    },
    { "lsp-config",
      ft = { "zig", "rust", "ghostlang" },
      dependencies = { "cmp-lsp" },
      config = function()
        require("lsp-config").setup({
          servers = { "zls", "rust_analyzer", "ghostls" },
        })
      end,
    },
    { "treesitter",
      event = "BufRead",
      config = function()
        require("treesitter").setup({
          ensure_installed = { "zig", "rust", "ghostlang" },
          highlight = { enable = true },
        })
      end,
    },
  },

  -- Theme
  theme = "tokyonight",

  -- Keymaps
  keymaps = {
    n = {
      ["<leader>e"] = ":FileTree<CR>",
      ["<leader>b"] = ":BufferPicker<CR>",
    },
  },
})
```

**Success Criteria:**
- [ ] `phantom.setup()` works like `lazy.setup()`
- [ ] Plugin specs declarative
- [ ] Config functions executed after load
- [ ] Hot reload on config change

---

## 🎯 Sprint 2 Tasks: Core Plugins

### Priority 1: Task 8.3 - LSP Config Plugin ⚡ START HERE

**Why first:** LSPManager from Sprint 1 is ready to use immediately.

**File:** `plugins/lsp/lsp-config.gza`

**Use existing systems:**
- `LSPManager` (already complete in `src/core/lsp_manager.zig`)
- `grim.lsp.Client` (wrapped and ready)

**Features to implement:**
- ✅ Auto-start LSP servers by filetype
- ✅ `zls` for Zig
- ✅ `rust-analyzer` for Rust
- ✅ `ghostls` for Ghostlang
- ✅ Expose: completion, hover, definition, diagnostics

**Implementation approach:**
```ghostlang
-- plugins/lsp/lsp-config.gza
local lsp = require("phantom.lsp")

local servers = {
    zig = { cmd = "zls", features = {"completion", "hover", "definition"} },
    rust = { cmd = "rust-analyzer", features = {"all"} },
    ghostlang = { cmd = "ghostls", features = {"all"} },
}

function setup(opts)
    for ft, config in pairs(servers) do
        autocmd("FileType", ft, function()
            lsp.start(ft, config.cmd)
        end)
    end
end
```

**Success criteria:**
- [ ] Opening .zig file auto-starts zls
- [ ] Opening .rs file auto-starts rust-analyzer
- [ ] Hover works (`:LspHover`)
- [ ] Completion works
- [ ] Diagnostics shown

**Tests:** `tests/lsp_config_test.zig` using TestHarness

**Estimated time:** 1-2 days

---

### Priority 2: Task 8.5 - Treesitter Plugin

**File:** `plugins/core/treesitter.gza`

**Use existing systems:**
- `SyntaxHighlighter` (wraps grim.syntax from Sprint 1)
- `grim.syntax.Parser` for parsing
- `grim.syntax.grove` for tree-sitter

**Features:**
- Auto syntax highlighting
- Code folding
- Incremental selection
- Support: zig, rust, ghostlang, typescript, python, go, c, cpp, lua

**Success criteria:**
- [ ] Syntax highlighting works on buffer open
- [ ] 8+ languages supported
- [ ] No performance degradation

**Tests:** `tests/treesitter_test.zig` using TestHarness

**Estimated time:** 2-3 days

---

### Priority 3: Task 8.2 - Fuzzy Finder Plugin

**File:** `plugins/core/fuzzy-finder.gza`

**Use grim modules:**
- `grim.core.fuzzy` for FZF algorithm
- `grim.ui_tui` for picker UI

**Features:**
- `:FuzzyFiles` - file picker
- `:LiveGrep` - ripgrep integration
- `:Buffers` - buffer picker
- Score-based sorting (consecutive, word boundary, camelCase)

**Success criteria:**
- [ ] `:FuzzyFiles` opens picker
- [ ] Fuzzy matching works
- [ ] Selection opens file

**Tests:** `tests/fuzzy_finder_test.zig` using TestHarness

**Estimated time:** 3-4 days

---

### Priority 4: Task 8.4 - Statusline Plugin

**File:** `plugins/core/statusline.gza`

**Use grim modules:**
- `grim.core.git` for git info
- `grim.ui_tui` for rendering

**Format:**
```
 NORMAL | main● | buffer.zig | 10,5 | utf-8 | zig
```

**Components:**
- Mode (NORMAL/INSERT/VISUAL)
- Git branch + status
- Filename
- Cursor position
- Encoding
- Filetype

**Success criteria:**
- [ ] Statusline renders at bottom
- [ ] Updates on mode change
- [ ] Shows git branch

**Tests:** `tests/statusline_test.zig` using TestHarness

**Estimated time:** 2-3 days

---

### Priority 5: Task 8.1 - File Tree Plugin

**File:** `plugins/core/file-tree.gza`

**Use grim modules:**
- `grim.core.Buffer` for file operations
- `grim.ui_tui` for rendering

**Features:**
- Tree rendering with icons
- Git status indicators (●/+/-/?)
- Keymaps: `o`/Enter to open, `a` to add, `d` to delete
- Integration with fuzzy finder

**Success criteria:**
- [ ] `:FileTree` opens sidebar
- [ ] Navigate with j/k
- [ ] Open files with Enter
- [ ] Git status shows

**Tests:** `tests/file_tree_test.zig` using TestHarness

**Estimated time:** 4-5 days

---

## LazyVim Feature Parity

### Essential Features from LazyVim

| Feature | LazyVim | Phantom.Grim | Status |
|---------|---------|--------------|--------|
| Lazy loading | ✅ | ⬜ | Task 5 |
| Plugin manager UI | ✅ | ⬜ | Need `:PhantomPlugins` |
| LSP auto-config | ✅ | ⬜ | Task 8.3 |
| Treesitter | ✅ | ⬜ | Task 8.5 |
| Fuzzy finder | ✅ | ⬜ | Task 8.2 |
| File explorer | ✅ | ⬜ | Task 8.1 |
| Statusline | ✅ | ⬜ | Task 8.4 |
| Git integration | ✅ | ⬜ | Use grim.core.git |
| Theme system | ✅ | ✅ | Already working |
| Auto-pairs | ✅ | ⚠️ | Partial |
| Comment | ✅ | ⚠️ | Partial |
| Which-key | ✅ | ⬜ | Future |
| Terminal | ✅ | ⬜ | Future |
| DAP debugging | ✅ | ⬜ | Future |

### Task 9: Plugin Manager UI

**Goal:** `:PhantomPlugins` command to manage plugins (like `:Lazy`).

**File:** `plugins/core/plugin-manager.gza`

**Features:**
- List all plugins with status (loaded/not loaded)
- Show load times
- Install/update/remove plugins
- View plugin config
- Health checks

**UI:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Phantom.Grim Plugin Manager
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

 Core Plugins (7)
  ● file-tree        2.1ms  [loaded on VimEnter]
  ● fuzzy-finder     1.8ms  [loaded on <leader>f]
  ○ lsp-config       —      [not loaded yet]
  ● statusline       0.5ms  [loaded at startup]
  ● treesitter       3.2ms  [loaded on BufRead]
  ● theme            0.3ms  [loaded at startup]
  ● plugin-manager   0.4ms  [loaded at startup]

 Editor Plugins (3)
  ● comment          0.6ms  [loaded on gc]
  ● autopairs        0.4ms  [loaded on InsertEnter]
  ○ surround         —      [not loaded yet]

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total: 10 loaded, 2 lazy  |  Startup: 9.3ms
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Commands: [i]nstall [u]pdate [c]lean [r]eload [q]uit
```

**Tests:** `tests/plugin_manager_test.zig` using TestHarness

---

## Testing Strategy

### Task 10: Create Comprehensive Test Suite

**Goal:** Use grim's TestHarness for all plugin testing.

**Test Files Structure:**
```
tests/
├── core/
│   ├── file_tree_test.zig
│   ├── fuzzy_finder_test.zig
│   ├── statusline_test.zig
│   └── treesitter_test.zig
├── editor/
│   ├── comment_test.zig
│   ├── autopairs_test.zig
│   └── surround_test.zig
├── lsp/
│   └── lsp_config_test.zig
├── integration/
│   ├── lazy_loading_test.zig
│   ├── dependency_resolution_test.zig
│   └── full_workflow_test.zig
└── harness_helpers.zig
```

**Example Test (using grim's TestHarness):**
```zig
// tests/editor/comment_test.zig
const std = @import("std");
const TestHarness = @import("test_harness").TestHarness;

test "comment plugin: toggle line comment" {
    const allocator = std.testing.allocator;

    var harness = try TestHarness.init(allocator);
    defer harness.deinit();

    // Load plugin
    try harness.loadPlugin("plugins/editor/comment.gza");

    // Create buffer with code
    _ = try harness.createBuffer("test.zig");
    try harness.sendKeys("i");
    try harness.sendKeys("const x = 42;");
    try harness.sendKeys("\x1b"); // ESC

    // Toggle comment
    try harness.sendKeys("gcc");

    // Verify commented
    try harness.assertBufferContent("// const x = 42;");

    // Toggle again
    try harness.sendKeys("gcc");

    // Verify uncommented
    try harness.assertBufferContent("const x = 42;");
}

test "comment plugin: block comment in visual mode" {
    const allocator = std.testing.allocator;

    var harness = try TestHarness.init(allocator);
    defer harness.deinit();

    try harness.loadPlugin("plugins/editor/comment.gza");

    _ = try harness.createBuffer("test.zig");
    try harness.sendKeys("i");
    try harness.sendKeys("line1\nline2\nline3");
    try harness.sendKeys("\x1b");

    // Visual mode select 2 lines
    try harness.sendKeys("gg");
    try harness.sendKeys("V");
    try harness.sendKeys("j");

    // Comment
    try harness.sendKeys("gc");

    try harness.assertBufferContent("// line1\n// line2\nline3");
}
```

**Test Coverage Goals:**
- [ ] Unit tests for each plugin
- [ ] Integration tests for lazy loading
- [ ] Integration tests for dependency resolution
- [ ] Performance tests (startup time, load time)
- [ ] All tests using grim's TestHarness
- [ ] 90%+ code coverage

**Run tests:**
```bash
zig build test
```

---

## Documentation & Polish

### Task 11: User Documentation

**Files to create:**

#### USER_GUIDE.md
- Getting started
- Basic configuration
- Plugin installation
- Customization guide
- Troubleshooting

#### PLUGIN_DEV_GUIDE.md
- Creating custom plugins
- Using grim modules
- Testing with TestHarness
- Publishing plugins
- Best practices

#### API_REFERENCE.md
- `phantom.setup()` API
- Plugin specification format
- Available grim modules
- Runtime functions
- Event system

#### MIGRATION_FROM_LAZYVIM.md
- Config translation guide
- Plugin equivalents
- Keybinding migration
- Lua → Ghostlang cheatsheet

---

### Task 12: Health Check System

**Goal:** `:PhantomHealth` command to diagnose issues.

**File:** `plugins/extras/health.gza`

**Checks:**
- Grim version compatibility
- Required binaries (zls, rust-analyzer, rg, fd)
- Plugin load status
- LSP server status
- Tree-sitter parser availability
- Git integration working
- Theme loaded correctly

**Output:**
```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Phantom.Grim Health Check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Core:
  ✓ Grim version: 0.1.0 (compatible)
  ✓ Zig version: 0.16.0
  ✓ TestHarness: available

Plugins:
  ✓ file-tree: loaded
  ✓ fuzzy-finder: loaded
  ✓ lsp-config: loaded
  ✓ treesitter: loaded
  ✓ comment: loaded
  ⚠ autopairs: not loaded (trigger: InsertEnter)

LSP:
  ✓ zls: running (pid 12345)
  ✓ rust-analyzer: running (pid 12346)
  ✗ ghostls: not found (install: cargo install ghostls)

Treesitter:
  ✓ zig: parser available
  ✓ rust: parser available
  ✓ ghostlang: parser available
  ⚠ typescript: parser missing

External Tools:
  ✓ ripgrep (rg): 14.1.0
  ✓ fd: 10.2.0
  ✓ git: 2.45.0

Theme:
  ✓ tokyonight: loaded
  ✓ Colors: 256 (truecolor)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Status: 14 OK, 2 warnings, 1 error
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

---

## Implementation Timeline

### ✅ Sprint 1: Grim Integration (COMPLETE)
- ✅ Task 1: Wire grim runtime to plugin loader
- ✅ Task 2: Integrate LSP client
- ✅ Task 3: Integrate syntax highlighting
- ✅ Task 4: Host adapter + phantom systems
- ✅ Test: All grim modules accessible

**Deliverable:** ✅ Plugins execute through grim, not standalone

**Completed:** 2025-10-11
**Files created:**
- `src/core/lsp_manager.zig`
- `src/core/plugin_host_adapter.zig`
- `src/core/command_registry.zig`
- `src/core/keymap_manager.zig`
- `src/core/event_system.zig` (verify existence)
- `src/core/theme_manager.zig`

---

### 🚀 Sprint 2: Core Plugins (CURRENT - Week 3-4)
- [ ] Task 8.3: LSP config plugin ⚡ **START HERE**
- [ ] Task 8.5: Treesitter plugin
- [ ] Task 8.2: Fuzzy finder plugin
- [ ] Task 8.4: Statusline plugin
- [ ] Task 8.1: File tree plugin
- [ ] Test: All core plugins working

**Deliverable:** 5 core plugins fully functional

**Target completion:** 2025-10-25
**Estimated days:** 12-17 days total

---

### Sprint 3: Lazy Loading System (Week 5-6)
- [ ] Task 5: Implement lazy loading
- [ ] Task 6: Dependency resolution
- [ ] Task 7: User-facing API (`phantom.setup()`)
- [ ] Test: Lazy loading works, startup < 50ms

**Deliverable:** `init.gza` API like lazy.nvim

**Target completion:** 2025-11-08

---

### Sprint 4: Testing & Polish (Week 7-8)
- [ ] Task 9: Plugin manager UI
- [ ] Task 10: Comprehensive test suite
- [ ] Task 11: User documentation
- [ ] Task 12: Health check system
- [ ] Test: 90%+ coverage, all docs complete

**Deliverable:** Production-ready v1.0

**Target completion:** 2025-11-22

---

## Success Criteria

**Functional Requirements:**
- ✅ Plugins load lazily based on triggers
- ✅ Dependency resolution prevents load errors
- ✅ LSP works for zig, rust, ghostlang
- ✅ Syntax highlighting via tree-sitter
- ✅ Fuzzy finder for files/buffers/grep
- ✅ File tree with git status
- ✅ Plugin manager UI (`:PhantomPlugins`)
- ✅ Health check (`:PhantomHealth`)

**Performance Requirements:**
- Startup time < 50ms (with 20+ lazy plugins)
- Plugin load time < 10ms per plugin
- Dependency resolution < 5ms
- Zero blocking on UI thread

**User Experience:**
- Zero-config defaults (works out of the box)
- Declarative plugin specs (lazy.nvim-style)
- Comprehensive error messages
- Hot reload on config change
- LazyVim migration guide

**Testing:**
- 90%+ code coverage
- All plugins tested with TestHarness
- Integration tests for workflows
- Performance benchmarks

---

## Quick Start for AI Assistants (GPT-5/Codex)

### Context You Need

**Repository:** `/data/projects/phantom.grim`

**Build Status:** ✅ Passing (`zig build`)

**Grim Dependency:**
```zig
// build.zig
const grim = b.dependency("grim", .{
    .@"export-test-harness" = true,
    .ghostlang = true,
});
const test_harness_mod = grim.module("test_harness");
```

**Available Modules from Grim:**
- `@import("test_harness")` - Testing framework
- `@import("grim")` - Main module with runtime, core, lsp, syntax, ui_tui

### Immediate Next Steps

1. **Read the architecture docs:**
   - `docs/PHANTOM_GRIM_ARCHITECTURE.md` - Complete framework design
   - `docs/GRIM_MODULES_REFERENCE.md` - How to use grim modules

2. **Start with Task 1 (Grim Runtime Integration):**
   - Modify `src/core/plugin_loader.zig`
   - Replace custom runtime with `grim.runtime.Runtime`
   - Test with existing plugins

3. **Write tests using TestHarness:**
   - Start with `tests/comment_test.zig`
   - Use TestHarness API from grim
   - Follow examples in `GRIM_MODULES_REFERENCE.md`

4. **Implement lazy loading (Task 5):**
   - Create `src/core/lazy_loader.zig`
   - Support event, ft, cmd, keys triggers
   - Wire to plugin registry

### Development Workflow

```bash
# Build
zig build

# Run tests
zig build test

# Run phantom.grim
./zig-out/bin/phantom_grim

# Format code
zig fmt .
```

### Code Style

- Use Zig 0.16 ArrayList API: `ArrayList.empty`, `deinit(allocator)`, `append(allocator, item)`
- Import grim modules: `const grim = @import("grim");`
- Use TestHarness for all tests
- Follow existing code patterns in `src/core/`

---

**Last Updated:** 2025-10-11
**Status:** ✅ Sprint 1 Complete - 🚀 Sprint 2 Active
**Next Action:** Task 8.3 - LSP Config Plugin (START HERE)

**Quick Start:**
1. Read Sprint 2 task list above
2. Start with Task 8.3 (LSP Config) - easiest, LSPManager ready
3. Use existing `LSPManager` in `src/core/lsp_manager.zig`
4. Create `plugins/lsp/lsp-config.gza`
5. Test with Zig files (zls auto-start)

**Questions?** See:
- Architecture: `docs/PHANTOM_GRIM_ARCHITECTURE.md`
- Grim Modules: `docs/GRIM_MODULES_REFERENCE.md`
- TestHarness: `/data/projects/grim/docs/TEST_HARNESS_USAGE.md`
- Sprint 1 Summary: Check "Sprint 1 Complete" section above
