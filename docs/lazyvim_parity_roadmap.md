# LazyVim Parity Focus Roadmap

_Last updated: 2025-10-09_

This document translates the current "recommended focus areas" into concrete, staged workstreams so Phantom.grim can close the gap with LazyVim. Each section captures:

- **Current status** — what already exists in the repo today.
- **What's missing** — the capabilities required for parity.
- **Next actions** — bite-sized milestones and suggested ownership.
- **Dependencies/risks** — cross-cutting work or open questions.

### Execution plan

We will execute roadmap items **1 → 5** sequentially, treating each as a milestone that unlocks the next. Runtime dependencies that block items are tracked in `docs/GRIM_WISHLIST.md`.

1. ✅ **Finish the four core plugins** *(Oct 2025)* – pane UX, pickers, statusline, and Treesitter management are live.
2. ✅ **Implement lazy-loading descriptors** *(Oct 2025)* – descriptor registry, triggers, Phantom DSL, automatic command/key replay, telemetry exports, and regression scaffolding are all live.
3. **Bring up the Phase 3 plugin set** – deliver the IDE-ready bundle.
4. **Advance theme UX** – polish daily ergonomics and theme authoring.
5. **Surface observability tooling** – provide the instrumentation needed for confident rollout.

Item 6 (docs & onboarding) stays in parallel discovery but will be scheduled once the above milestones are underway. Each milestone will spin out concrete issues/PRs as we enter implementation.

---

## 1. Finish the Four Core Plugins

| Plugin | Current status | Still on the horizon | Next actions |
|--------|----------------|---------------------|--------------|
| `core/file-tree.gza` | Git-aware pane with expansion state, file actions (create/delete/rename), command suite, default keymaps, layout metadata for Phantom UI. | Deep UI sync once Phantom TUI lands (icons, inline rename), async refresh, watchers. | 1. Wire to upcoming Phantom pane manager.<br>2. Add async fs events + debounced refresh.<br>3. Ship UI affordances (icons, diagnostics badges). |
| `core/fuzzy-finder.gza` | Picker abstraction with file/buffer/grep modes, ripgrep integration, preview API, commands `:PhantomFiles/:PhantomGrep/:PhantomBuffers`. | Graphical picker widget, multi-select/send-to-window actions, MRU weighting. | 1. Connect to Phantom list UI.<br>2. Add send-to-pane + quickfix exports.<br>3. Integrate MRU history & weights from Zig runtime. |
| `core/statusline.gza` | Modular segment registry (mode/file/git/diagnostics/LSP/clock), theme palette hooks, customizable layout and providers. | Rich color groups once Phantom exposes highlight API, per-window contexts, async diagnostics streaming. | 1. Bind to Phantom highlight groups.<br>2. Surface per-pane status contexts.<br>3. Add async diagnostics/LSP providers. |
| `core/treesitter.gza` | Grammar registry with ensure/install commands, auto-probing, feature toggles, highlight cache, default 14-language profile. | Native grove installer hook, per-language feature overrides, background updates. | 1. Bridge to grove installer when ready.<br>2. Add language-specific feature maps.<br>3. Schedule periodic grammar audits. |

**Delivered commands & UX wiring**

- File tree: `:PhantomTreeToggle`, `:PhantomTreeFocus`, `:PhantomTreeEnter`, plus default `<leader>e` mappings.
- Fuzzy finder: `:PhantomFiles`, `:PhantomGrep`, `:PhantomBuffers` with preview metadata.
- Statusline: configurable segments exposed via `require("plugins.core.statusline").set_layout()` and palette hooks.
- Treesitter: `:PhantomTSInstall`, `:PhantomTSUpdate`, `:PhantomTSInfo` now manage the grammar registry.


**Dependencies & risks**
- Phantom TUI abstractions must stabilize to host file tree & picker views.
- Need reliable Ghostlang ↔ Zig bridges for git, fuzzy finder, and grove.
- Consider incremental roll-out with feature flags to avoid regressions.

---

## 2. Implement Lazy-Loading Descriptors

**Current status:** `plugin-manager.gza` now stores full descriptors with `cmd`/`keys`/`event`/`ft` triggers, telemetry, and dependency chaining. Stub commands (`:PhantomPluginTrigger`, `:PhantomPluginLoad`) and the `phantom.lazy` helper ship with docs in `docs/plugin_manifest.md`.

**Shipped polish:** automatic replay via the Grim `CommandReplayAPI`, real-time key re-run through `phantom.feedkeys()`, per-plugin load/trigger metrics in `extras.health`, and a regression harness (`tests/plugin_manager_replay.gza`).

**Next actions:** validate the telemetry once more Phase 3 plugins land and fold the data into the upcoming `:PhantomPlugins` UI.

---

## 3. Bring Up Phase 3 Plugin Set

**Current status:** Milestone plan documented in `docs/milestone3_plugin_plan.md`. `editor.comment` is live with lazy descriptors, default keymaps (`gcc`, `gc`), and fallback buffer handling while we wait for editor-side APIs.

**Dependencies:** P0 runtime asks (buffer edit API, command replay hooks) are captured in `docs/GRIM_WISHLIST.md`. We should land them before widening coverage so autopairs/surround can avoid brittle scratch adapters.

Target parity plugins (per `FUTURE_GRIM_PHANTOM_GUIDE.md`, §3.1–3.3):

- **Editor ergonomics:** `comment`, `autopairs`, `surround`, `indent-guides`, `colorizer`.
- **Language tooling:** `lsp.gza` orchestrator tying together Ghostls, ZLS, Rust Analyzer, etc.
- **Git & utils:** confirm `git-signs`/diagnostics exist or create equivalents.

**Next actions:**
1. Implement `editor.autopairs` and `editor.surround` using the same descriptor infrastructure; share common text mutation helpers once the buffer edit APIs from the wishlist land.
2. Wire indent guide and colorizer plugins, emitting telemetry to the health report and adding load counters per plugin.
3. Stand up `plugins/editor/lsp.gza` as the orchestrator for Ghostls/ZLS/RA with language-specific descriptors.
4. Add Ghostlang regression tests for comment/autopairs/surround toggles as soon as the headless buffer harness is available (see wishlist) or via interim mock adapters.
5. Extend `extras.health` to surface per-plugin load counts and timings once two or more Phase 3 modules ship.

**Risks:** Need ergonomic API surface from Zig runtime; ensure plugin manager can express load ordering and dependencies.

---

## 4. Advance Theme UX

**Current status:** Theme manager handles catalogs, history, randomizer, and set/reload commands (`plugins/core/theme.gza`, `plugins/editor/theme-commands.gza`).

**Missing:**
- Interactive picker UI (Telescope-style).
- Programmable theme hooks (Ghostlang DSL for overrides).
- Validation pipeline described in `THEMING.md` (schema checks, previews, ensure-installed behaviour).

**Next actions:**
1. Implement `:GrimThemeBrowser` picker using the same list/panel components needed for fuzzy finder.
2. Add hook registration API (`theme.register_hooks({ on_load = fn ... })`).
3. Build validator that scans TOML/GZA themes and reports issues in `:PhantomHealth`.
4. Document theme authoring guide (samples + troubleshooting).

---

## 5. Surface Observability Tooling

**Current status:** `plugins/extras/health.gza` reports high-level stats; no plugin-specific metrics.

**Missing:**
- Load-time telemetry per plugin (install, lazy-load, runtime errors).
- `:PhantomPlugins` UX aligned with Lazy’s overview (state badges, timings, health info).
- Profiling hooks for Zig allocator, theme ops, and Ghostlang eval.

**Next actions:**
1. Instrument loader to emit timing + status events (store in state cache).
2. Enhance `plugin-manager.gza` to show timings, load triggers, and error summaries.
3. Expose profiling toggles (CLI flag/env) and document usage.
4. Feed metrics into health snapshot + log to dedicated pane.

**Dependencies:** Might rely on Zig tracing APIs introduced during 0.16 migration; ensure minimal overhead in release builds.

---

## 6. Tighten Docs & Onboarding

**Current status:** Extensive guides (`README.md`, `PGRIM_START.md`, `LAZY_GUIDE.md`) but missing quick-start cookbook and automation scripts.

**Missing:**
- “Clone & go” bootstrap script with dependency checks.
- Cookbook covering common edits (keymaps, themes, plugin overrides).
- Sample `init.gza` configurations for typical roles (webdev, systems, writer).

**Next actions:**
1. Add `scripts/bootstrap.sh` to install prerequisites, clone themes, run health checks.
2. Create `docs/cookbook/` with short recipes and copy/paste snippets.
3. Provide template configs under `examples/` with commentary.
4. Integrate docs into CI (lint/validate) to keep examples in sync.

---

## Cross-Cutting Recommendations

- **Prioritization:** tackle sections 1 & 2 first; they unblock theme picker, observability metrics, and future plugins.
- **Milestone tracking:** create GitHub project board with columns matching these six focus areas.
- **CI coverage:** add targeted tests (Ghostlang + Zig) as features land to prevent regressions.
- **Community feedback:** ship alpha builds for each milestone and solicit feedback via `:PhantomHealth` reports.

---

_This roadmap should be updated after each milestone to keep alignment with LazyVim feature goals._
