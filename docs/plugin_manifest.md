# Plugin Manifest Reference

_Last updated: 2025-10-08_

Lazy-loading descriptors let Phantom.grim defer plugin work until the user
actually needs it. This document describes the manifest fields supported by the
new `plugins/core/plugin-manager.gza` implementation and how to wire them from
Ghostlang configs.

## Core Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | ✅ | Canonical plugin identifier (e.g. `editor.comment`). Normalized with `/` → `.`. |
| `module` | string | ❌ | Optional explicit module name to `require`. Defaults to `name`. |
| `enabled` | boolean | ❌ | When `false`, the descriptor is ignored. Defaults to `true`. |
| `lazy` | boolean | ❌ | Force eager (`false`) or lazy (`true`) loading. Defaults to `true` when any triggers are declared, otherwise `false`. |
| `priority` | number | ❌ | Higher values load earlier during eager ensure. Default `0`. |
| `dependencies` | string or {string} | ❌ | Plugins to load before this descriptor activates. |
| `init` | fun(descriptor) | ❌ | Runs once before the module is required. Great for globals or settings. |
| `config` | fun(module, meta) | ❌ | Runs after the module is required. Use for setup hooks or command registration. |

## Trigger Tables

A descriptor becomes lazy when any of the trigger tables contain entries. The
first trigger hit loads the plugin, records telemetry, and optionally executes a
follow-up callback.

### `cmd`

Accepts a string (command name) or table entries:

```ghostlang
cmd = {
    "CommentToggle",  -- simple string, rerun manually
    {
        name = "CommentLine",
        desc = "Toggle comment on current line",
        callback = function(ctx)
            require("plugins.editor.comment").toggle_line(ctx)
        end,
        once = false,
    },
}
```

- `name` / positional `[1]`: command to register.
- `desc`: surfaced in `:command` listings.
- `run`: override command name to re-dispatch after load (defaults to `name`).
- `callback`: optional function invoked immediately after loading.
- `once`: when `true`, the trigger is removed after the first activation.

> ℹ️ **Execution model:** The stub command ensures the plugin is available. If no
> callback is provided, the user may need to rerun the command once more; we log a
> friendly reminder when that happens.

### `keys`

Entries can be shorthand strings or richer tables:

```ghostlang
keys = {
    "<leader>cc",  -- defaults to normal mode, will prompt user to repeat
    { "n", "gcc", function() require("plugins.editor.comment").toggle_line() end,
      desc = "Toggle comment", once = true },
    { mode = { "n", "v" }, lhs = "gc", rhs = ":CommentToggle<CR>", desc = "Comment" },
}
```

- `mode` / `[1]`: single mode string (`"n"`, `"v"`, etc.). Defaults to `"n"`.
- `lhs` / `[2]`: the mapping to register. Required.
- `rhs` / `[3]`: optional replacement mapping to set after the plugin loads.
- `callback`: function executed immediately after load.
- `desc`: description forwarded to the runtime.
- `once`: remove trigger after first activation.

### `event`

```ghostlang
event = {
    "BufReadPost",  -- wildcard pattern
    { event = "User", pattern = "VeryLazy", callback = on_ready },
}
```

- `event` / `[1]`: autocmd event name.
- `pattern` / `[2]`: pattern string (`"*"` default).
- `callback`: optional function executed post-load.
- `once`: remove trigger after the first match.

### `ft`

Shorthand for filetype-driven activation (wraps `FileType` autocmds):

```ghostlang
ft = {
    "lua",
    { ft = "rust", callback = function()
        require("plugins.editor.rust-tools").activate()
    end },
}
```

## Ghostlang DSL Helpers

### `phantom.lazy`

The `plugins/editor/phantom.gza` module now exposes a convenience helper that
registers descriptors and records them in the Phantom state summary.

```ghostlang
local phantom = require("plugins.editor.phantom")

phantom.lazy({
    name = "editor.comment",
    cmd = { "CommentToggle" },
    keys = {
        { "n", "gcc", function() require("plugins.editor.comment").toggle_line() end,
          desc = "Toggle comment" },
    },
    config = function()
        require("plugins.editor.comment").setup()
    end,
})
```

Passing a list is also supported: `phantom.lazy({ spec_a, spec_b })`.

Descriptors registered through `phantom.lazy` still respect the global defaults
for eager plugins, so you can mix and match tables and simple string names:

```ghostlang
phantom.setup({
    plugins = {
        "core.statusline",          -- eager load
        { name = "editor.comment", cmd = { "CommentToggle" } },
        { name = "extras.harpoon", event = "VeryLazy" },
    },
})
```

## Telemetry & Observation

Each descriptor tracks:

- `trigger_kind`: what caused the load (`cmd`, `keys`, `event`, `ft`, `ensure`, `manual`).
- `trigger_source`: identifier (command name, keymap, event id).
- `loaded_at`: Unix timestamp at activation.
- `duration`: time spent requiring the plugin (in seconds).

You can inspect the captured data via `plugin_manager.status()` or the
`:PhantomPlugins` command.

## Gotchas & Best Practices

- Provide a `callback` for commands and keymaps when you need the triggering
  action to execute immediately after the plugin loads.
- Rebind `rhs` strings for keymaps if the plugin defines command-style mappings
  (they are automatically re-registered once the descriptor loads).
- Use `dependencies` to guarantee supporting modules are available before the
  lazy plugin spins up.
- Keep descriptors idempotent: `config` and `callback` functions may run at most
  once per descriptor.

Happy hacking! 🪄
