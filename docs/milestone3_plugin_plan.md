# Milestone 3 – Phase 3 Plugin Rollout

_Last updated: 2025-10-09_

This note captures the implementation slices for the Phase 3 bundle so we can
stage the work across multiple PRs without losing context.

## Target Plugins

| Plugin | Purpose | Key Triggers | Dependencies | Acceptance Tests |
|--------|---------|--------------|--------------|------------------|
| `plugins/editor/comment.gza` | Toggle line/block comments; dot-repeat friendly. | `cmd = { "CommentToggle", "CommentLine", "CommentBlock" }`, `keys = { "gc", "gcc", "gbc" }`, `event = "BufReadPost"` for initial operator setup. | Ships with BufferEdit/OperatorRepeat fallbacks via `textops`; upgrade to native API when Grim exposes bindings. | Ghostlang regression specs in `tests/comment_plugin.gza`; integration snapshot via `:CommentToggle`. |
| `plugins/editor/autopairs.gza` | Auto-insert matching pairs with context rules. | `event = { "InsertEnter" }`, `ft = { "lua", "zig", "rust", "markdown" }`. | Buffer text mutations, optional Treesitter queries. | Regression specs in `tests/autopairs_plugin.gza` covering insertion, skipping, and backspace. |
| `plugins/editor/surround.gza` | Add/change/delete surrounding characters. | `cmd = { "SurroundAdd", "SurroundDelete", "SurroundReplace" }`, `keys = { "ys", "cs", "ds" }`. | Depends on autopairs utilities for text mutation. | Tests for wrap/replace/delete across modes. |
| `plugins/editor/indent-guides.gza` | Render indent scope indicators. | `event = { "BufWinEnter", "TabEnter" }`, `cmd = { "IndentGuidesToggle" }`. | Theme palette + highlight groups. | Visual smoke via snapshot (JSON), ensure toggle state persists. |
| `plugins/editor/colorizer.gza` | Highlight color codes in buffers. | `ft = { "css", "scss", "lua", "ghostlang" }`, `cmd = { "ColorizerToggle" }`. | Requires theme hooks and Treesitter/regex fallback. | Tests: highlight detection for hex/rgb/hsl; ensure toggle clears highlights. |
| `plugins/editor/lsp.gza` | LSP orchestrator bridging GhostLS/ZLS/RA. | `cmd = { "LspAttach" }`, `event = { "BufReadPost" }`, `ft = language list`. | Zig runtime LSP client, plugin-manager dependencies for tool installers. | Integration harness: attach/detach events, ensures diagnostics pipeline works. |

## Delivery Strategy

1. **Comment plugin first** – reuses existing bridge APIs (`map`, buffer edits) and
   unblocks surround/autopairs validation. Ship with small default config + lazy
   triggers using the new descriptor system.
2. **Autopairs + surround** – share utility module for text objects. Ensure both
   expose toggles for users who want only one feature.
3. **Indent guides** – leverage theme palette; keep rendering minimal while we
   wait for Phantom TUI components.
4. **Colorizer** – simple regex-based highlighter initially, upgrade to
   Treesitter queries when available.
5. **LSP orchestrator** – largest chunk; reuse ghostls integration and expose
   lazy descriptors per language (ft triggers). Provide health checks referencing
   new telemetry so users can spot slow attaches.

## Telemetry & Health Hooks

- Record lazy trigger timings for each plugin using the new manager metrics.
- Surface plugin-specific stats in `extras.health` once each lands (total
  activations, average attach time for LSP).

## Testing Approach

- Use Ghostlang unit harness (`tests/` modules) to simulate command/key calls.
- When Zig glue is required (e.g., LSP attach), provide mocked bridge functions
  in tests to avoid flaky integrations.
- Add regression fixtures under `validation_reports/` for colour/indent output.

## Documentation Checklist

- Update `docs/lazyvim_parity_roadmap.md` after each plugin lands.
- Provide quickstart snippets in `docs/cookbook/` (to be added during Milestone 6).
- Add `README` sections in each plugin directory describing commands, keymaps,
  and configuration hooks.
