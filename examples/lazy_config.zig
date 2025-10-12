//! examples/lazy_config.zig
//! Example phantom.grim configuration with lazy loading
//! This is the recommended configuration for fast startup

const phantom = @import("phantom");

pub fn main() !void {
    const config = phantom.PhantomConfig{
        .debug = false, // Set true to see load timings

        .plugins = &.{
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // CORE PLUGINS - Load immediately (critical UI)
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

            .{
                .name = "theme",
                .lazy = false, // Always load - prevents visual glitches
                .priority = 1000,
            },

            .{
                .name = "statusline",
                .lazy = false, // Always load - core UI
                .priority = 900,
            },

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // LSP PLUGINS - Load on FileType
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

            .{
                .name = "lsp-config",
                .ft = &.{ "zig", "rust", "ghostlang", "c", "cpp" },
                .priority = 800,
            },

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // SYNTAX - Load on FileType
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

            .{
                .name = "treesitter",
                .ft = &.{ "zig", "rust", "ghostlang", "typescript", "javascript", "python" },
                .priority = 750,
            },

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // EDITOR FEATURES - Load on command/keymap
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

            .{
                .name = "fuzzy-finder",
                .cmd = &.{ "FuzzyFind", "FuzzyGrep", "FuzzyBuffers" },
                .keys = &.{
                    .{ .mode = "n", .lhs = "<leader>ff" },
                    .{ .mode = "n", .lhs = "<leader>fg" },
                    .{ .mode = "n", .lhs = "<leader>fb" },
                },
            },

            .{
                .name = "file-tree",
                .cmd = &.{"FileTree"},
                .keys = &.{
                    .{ .mode = "n", .lhs = "<leader>e" },
                },
            },

            .{
                .name = "comment",
                .keys = &.{
                    .{ .mode = "n", .lhs = "gcc" },
                    .{ .mode = "v", .lhs = "gc" },
                },
                .ft = &.{ "zig", "rust", "ghostlang", "lua" },
            },

            .{
                .name = "autopairs",
                .events = &.{.InsertEnter},
                .priority = 100,
            },

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // UTILITIES - Load on demand
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

            .{
                .name = "plugin-manager",
                .cmd = &.{ "PluginInstall", "PluginUpdate", "PluginClean" },
            },

            .{
                .name = "zap-ai",
                .cmd = &.{ "ZapAI", "ZapChat" },
                .keys = &.{
                    .{ .mode = "n", .lhs = "<leader>ai" },
                },
            },

            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
            // SUPPORT PLUGINS - Always available
            // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

            .{
                .name = "phantom",
                .lazy = false, // Core editor functions
                .priority = 950,
            },

            .{
                .name = "textops",
                .lazy = false, // Used by other plugins
                .priority = 900,
            },
        },
    };

    const ph = try phantom.setup(config);
    defer ph.deinit();

    // Phantom is now ready!
    // Plugins will load as you use them:
    // - Open a .zig file → LSP + Treesitter load
    // - Press <leader>ff → Fuzzy finder loads
    // - Press gcc → Comment plugin loads

    const stats = ph.stats();
    std.debug.print("✓ Ready with {d}/{d} plugins loaded\n", .{
        stats.loaded_plugins,
        stats.total_plugins,
    });
}
