# phantom.grim Start Guide

Welcome to **phantom.grim** – a LazyVim-inspired configuration layer that ships with opinionated defaults, a curated plugin stack, and fast theming ergonomics for the Grim editor.

---

## Mission

phantom.grim exists to shorten the distance between a fresh Grim install and a fully tricked-out workflow. The project focuses on four pillars:

1. **Theme-first experience** – ship with the `ghost-hacker-blue` default theme, expose theme switching, and make it trivial to layer custom palettes or overrides.
2. **Plugin curation & lifecycle** – provide a batteries-included set of Ghostlang and native plugins with predictable load order, lazy-loading hooks, and safe teardown.
3. **Ergonomic configuration** – surface a friendly `init.gza` API with conventions for keymaps, commands, and automation so users can extend without editing core Zig code.
4. **Performance awareness** – lean on Grim's optimizer, new allocator patterns, and profiling hints introduced during the Zig 0.16 migration.
5. **Runtime orchestration** *(new)* – bundle health checks, theme ergonomics, and plugin lifecycle helpers so Phantom.grim feels closer to LazyVim out of the box.

---

## Quick Start Checklist

1. **Install Grim**
2. **Clone phantom.grim** into `~/.config/grim/` and symlink `init.gza` if you keep multiple profiles.
3. **Launch Grim** – phantom.grim will boot automatically, apply `ghost-hacker-blue`, and register its plugin bundle.
4. **Explore commands**:
  - `:GrimTheme`, `:GrimThemeReload`, and `:GrimThemeBrowser` for live theme switching.
  - `:GrimThemeRandom` to roll through palettes when you need inspiration.
  - `:PhantomPlugins`, `:PhantomPluginList`, and `:PhantomPluginEnsure` to inspect and reconcile the plugin bundle.
  - `:PhantomHealth` to print the new runtime snapshot report.

> 💡 Keep your personal tweaks in `~/.config/grim/lua/` or `~/.config/grim/plugins/` so upstream updates remain merge-friendly.

## Zap AI Integration (New)

Grim core now ships with the Zap AI bridge and Ollama-aware helpers. Phantom.grim bundles a `zap-ai` plugin that exposes the new Ghostlang FFI:

- `bridge.zap.ensure()` / `bridge.zap.available()` – bootstrap and health-check the Ollama backend.
- `bridge.zap.commit_message(diff)` – draft commit messages from git diffs.
- `bridge.zap.explain_changes(diff)` – produce natural-language change summaries.
- `bridge.zap.review_code(source)`, `generate_docs(source)`, `suggest_names(source)`, `detect_issues(source)` – run the additional AI review flows shipped with Grim.
- Convenience helpers `plugins.core["zap-ai"].commit_message_from_git()` and `explain_head()` wrap the new git diff endpoints.

To get started:

1. Install and run [Ollama](https://ollama.ai) locally.
2. Fetch a compatible model (for example `ollama pull deepseek-coder:33b`).
3. Launch Grim; Phantom.grim will Autoload the `zap-ai` plugin and report availability in the log pane.
4. Call the helpers from Ghostlang (e.g. via a keymap or command) or build higher-level workflow plugins on top of them.

If Ollama is offline the plugin degrades gracefully, returning empty strings so your scripts stay safe.

---

## Configuration Layout

```
~/.config/grim/
├── init.gza              # phantom.grim entry point
├── themes/               # User-managed TOML and (future) GZA themes
│   ├── ghost-hacker-blue.toml (symlink to repo copy)
│   └── custom/
├── plugins/
│   ├── community/        # Git clones managed by :GrimThemeInstall / :Plugin install
│   └── local/            # User-authored plugins
└── state/
    ├── plugin_cache/     # Compiled artifacts & metadata
    └── theme_cache/      # Serialized theme data for fast reloads
```

phantom.grim keeps first-party modules under `phantom/` (Lua/Ghostlang) so users can override behaviour simply by shadowing modules in `~/.config/grim/lua/phantom/`.

---

## Plugin System Overview

Grim exposes a two-tier plugin model that phantom.grim leans on:

| Type            | Format       | Typical Use                                   |
|-----------------|--------------|-----------------------------------------------|
| Ghostlang       | `.gza` script| High-level automation, commands, keymaps       |
| Native          | Zig module   | Performance-sensitive integrations             |

Key pieces introduced or refined during the Zig 0.16 migration:

### 1. Manifest-driven loading
- Plugins declare metadata in `plugin.toml` (see `docs/PLUGIN_MANIFEST.md`).
- Sections cover `plugin`, `config`, `dependencies`, and optional `optimize` hints.
- `enable_on_startup`, `lazy_load`, and `priority` control when phantom.grim asks the runtime to load the plugin.

### 2. Runtime lifecycle
- `runtime/plugin_manager.zig` watches `~/.config/grim/plugins/` for manifests, compiles Ghostlang sources, and loads them through the host bridge.
- Each plugin instance tracks **command bindings**, **keymap bindings**, **event handlers**, and **theme registrations** using allocator-safe `std.ArrayList` APIs.
- Unloading a plugin automatically de-registers commands, clears keymaps, unsubscribes events, and unregisters theme hooks to avoid leaks.

### 3. Plugin API surface
Plugin authors work against `runtime/plugin_api.zig`:
- `PluginAPI.CommandRegistry` registers named commands that show up in Grim's command palette.
- `PluginAPI.EventHandlers` lets plugins react to buffer, cursor, LSP, or lifecycle events.
- `PluginAPI.KeystrokeHandlers` (via keymap helpers) mirror LazyVim-style modal keybindings.
- `PluginAPI.EditorContext` exposes cursor position, buffer handles, selection, and bridging helpers so Ghostlang code can manipulate text safely.

```ghostlang
-- init.gza inside a plugin directory
local api = grim.plugin.api()

api:command({
  name = "hacker-mode",
  description = "Toggles phantom hacks",
  handler = fn(ctx) {
    print("⚡ Hacker mode engaged")
    theme.set("ghost-hacker-blue")
  },
})

api:keymap({
  mode = "normal",
  keys = "<leader>hh",
  handler = "hacker-mode",
})
```

### 4. Theme callbacks
- Plugins can `register_theme("name")` to feed custom palettes into phantom.grim.
- Behind the scenes the runtime stores registrations and relays them through `ThemeCallbacks` so UI components know when to hot reload colors.
- phantom.grim will expose helper APIs (`phantom.theme.register`) to wrap the raw callbacks once the hot-reload loop lands.

### 5. Optimization hints
- The updated manifest parser honours `[optimize]` keys like `auto_optimize`, `hot_functions`, and `compile_on_install`.
- phantom.grim should surface a convenience wrapper to toggle these per plugin and surface profiler output in `:PhantomCheck`.

---

## Theme Integration Highlights

The theme system is a first-class citizen:

- Default theme: **`ghost-hacker-blue`** – Tokyo Night Moon base with cyan/teal/mint hacker accents.
- Users declare themes via TOML in `~/.config/grim/themes/`, or (future) Ghostlang scripts for programmatic palettes.
- phantom.grim provides:
  - `theme({ default, themes, ensure_installed })` DSL for LazyVim-style theme lists.
  - Runtime commands shipped in `plugins/editor/theme-commands.gza`:
    - `:GrimTheme <name>` – switch instantly.
    - `:GrimThemeReload` – hot-reload the active palette from disk.
    - `:GrimThemeBrowser` – fuzzy picker powered by the theme catalog cache.
    - `:GrimThemeRandom` – apply a random catalog entry (with preview support).
  - Catalog caching that scans built-ins and user search paths so listing themes is instant even on large collections.
  - Theme history tracking to let you jump back through recent choices.
  - Override tables for targeted palette/syntax/UI adjustments.
  - `on_before_load` / `on_load` hooks so configs can reset highlights or trigger UI effects when themes change.

> ✅ **Phase 2 focus:** deliver theme management commands, fuzzy picker flow, runtime switching, and validation before moving on to programmable themes.

---

## How phantom.grim Uses Plugins

1. **Bootstrap** – `init.gza` pulls in `phantom.core`, applies defaults, then resolves the plugin graph defined in `phantom/plugins.lua` (or equivalent Ghostlang table).
2. **Resolve dependencies** – the loader groups plugins by priority, respects `load_after`, and ensures required dependencies are present before activation.
3. **Activate** – Ghostlang plugins are compiled and run via the host bridge; native plugins are loaded through `runtime/native_plugin.zig` with safety checks.
4. **Register integrations** – commands, keymaps, events, and theme registrations bubble into the runtime registries.
5. **Teardown** – on reload or disable, phantom.grim calls back into `plugin_manager` to clear bindings, freeing all allocator-backed data and unregistering themes.
6. **State tracking** – phantom.grim writes per-plugin state (enablement, lazy status, cache paths) into `state/plugin_cache/` so restarts are fast.
7. **Plugin manager API *(new)*** – `plugins/core/plugin-manager.gza` keeps a declarative registry of defaults, surfaces `PhantomPlugins()` status snapshots, and mirrors LazyVim's plugin overview UX.
8. **Health reporting *(new)*** – `plugins/extras/health.gza` captures theme/catalog metrics, Zap availability, and git diff stats, wiring them into the `:PhantomHealth` helper.

---

## Recommended Roadmap (Next Sprints)

| Pillar | What to tackle next | Notes |
|--------|--------------------|-------|
| Theme management | Harden catalog validation, add programmable theme inputs | Builds directly on `PHANTOM_GRIM_THEME.md` plan |
| Plugin UX | Extend plugin manifests, surface install/update flows, and wire dependency resolution | Leverage manifest `priority` + `load_after` |
| Observability | Fold in profiler counters and allocator stats alongside the health snapshot | Piggyback on profiling hooks wired during Zig 0.16 migration |
| Docs | Publish cookbook recipes (theme overrides, keymap shadows, plugin templates) | Keep docs under `phantom/docs/` for discoverability |
| Automation | Provide `phantom.bootstrap` script to install common themes/plugins automatically | Use new CLI-friendly `grim-pkg` writer |

---

## Contributing

- Follow the manifest template in `docs/PLUGIN_MANIFEST.md` for new plugins.
- Use allocator-aware patterns showcased in runtime code when touching Zig components.
- Keep theme contributions in sync with the palette reference outlined in `PHANTOM_GRIM_THEME.md`.
- File issues or PRs once you run `zig build` and ensure phantom.grim still boots with `ghost-hacker-blue` as the fallback.

**Happy hacking – phantom.grim is ready for lift-off!**
