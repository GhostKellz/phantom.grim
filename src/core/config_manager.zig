//! core/config_manager.zig
//! Central configuration management using Flare + Ghostlang integration

const std = @import("std");
const flare = @import("flare");
const zlog = @import("zlog");
const PluginLoader = @import("plugin_loader.zig").PluginLoader;
const GhostlangRuntime = @import("ghostlang_runtime.zig").GhostlangRuntime;

pub const ConfigManager = struct {
    allocator: std.mem.Allocator,
    flare_config: flare.Config,
    ghostlang_runtime: GhostlangRuntime,
    config_dir: []const u8,
    plugin_loader: PluginLoader,
    plugin_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator, config_dir: []const u8) !ConfigManager {
        // Initialize Flare config
        var flare_config = try flare.Config.init(allocator);
        errdefer flare_config.deinit();

        // Create a pointer to flare_config for GhostlangRuntime
        const flare_ptr = try allocator.create(flare.Config);
        errdefer allocator.destroy(flare_ptr);
        flare_ptr.* = flare_config;

        // Initialize Ghostlang runtime
        var ghostlang_runtime = try GhostlangRuntime.init(allocator, flare_ptr, config_dir);
        errdefer ghostlang_runtime.deinit();

        const plugin_dir = try std.fs.path.join(allocator, &[_][]const u8{ config_dir, "plugins" });
        errdefer allocator.free(plugin_dir);
        std.fs.cwd().makePath(plugin_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        const default_registry = "https://registry.phantom.grim";
    const plugin_loader = PluginLoader.init(allocator, default_registry, plugin_dir);

        return ConfigManager{
            .allocator = allocator,
            .flare_config = flare_config,
            .ghostlang_runtime = ghostlang_runtime,
            .config_dir = config_dir,
            .plugin_loader = plugin_loader,
            .plugin_dir = plugin_dir,
        };
    }

    pub fn deinit(self: *ConfigManager) void {
        self.ghostlang_runtime.deinit();
        self.flare_config.deinit();
        self.allocator.free(self.plugin_dir);
    }

    /// Load all configuration files in order
    pub fn loadConfiguration(self: *ConfigManager) !void {
        zlog.info("Loading phantom.grim configuration", .{});

        // Load in order of precedence (lowest to highest):
        // 1. Defaults
        try self.loadDefaults();

        // 2. Bootstrap init script (may load plugins)
        try self.loadInitScript();

        // 3. User configuration
        try self.loadUserConfig();

        // 4. Plugin configurations
        try self.loadPluginConfigs();

        zlog.info("Configuration loaded successfully", .{});
    }

    fn loadInitScript(self: *ConfigManager) !void {
        const init_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.config_dir, "init.gza" });
        defer self.allocator.free(init_path);

        if (std.fs.cwd().access(init_path, .{})) {
            try self.ghostlang_runtime.loadConfigFile(init_path);
        } else |_| {
            zlog.info("No init.gza found at: {s}", .{init_path});
        }
    }

    /// Load default configuration files
    fn loadDefaults(self: *ConfigManager) !void {
        const defaults = [_][]const u8{
            "runtime/defaults/options.gza",
            "runtime/defaults/keymaps.gza",
            "runtime/defaults/autocmds.gza",
        };

        for (defaults) |config_file| {
            const full_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.config_dir, config_file });
            defer self.allocator.free(full_path);

            if (std.fs.cwd().access(full_path, .{})) {
                try self.ghostlang_runtime.loadConfigFile(full_path);
            } else |_| {
                zlog.warn("Default config file not found: {s}", .{full_path});
            }
        }
    }

    /// Load user configuration
    fn loadUserConfig(self: *ConfigManager) !void {
        const user_config_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.config_dir, "lua/user/config.gza" });
        defer self.allocator.free(user_config_path);

        if (std.fs.cwd().access(user_config_path, .{})) {
            try self.ghostlang_runtime.loadConfigFile(user_config_path);
        } else |_| {
            zlog.info("No user config found at: {s}", .{user_config_path});
        }
    }

    /// Load plugin configurations
    fn loadPluginConfigs(self: *ConfigManager) !void {
        try self.plugin_loader.loadInstalled(&self.ghostlang_runtime);
    }

    fn pluginPathToModuleName(allocator: std.mem.Allocator, relative_path: []const u8) ![]u8 {
        if (!std.mem.endsWith(u8, relative_path, ".gza")) {
            return error.InvalidPluginPath;
        }

        const stem_len = relative_path.len - ".gza".len;
        const prefix = "plugins.";
        const total_len = prefix.len + stem_len;
        var buffer = try allocator.alloc(u8, total_len);

        std.mem.copyForwards(u8, buffer[0..prefix.len], prefix);

        var i: usize = 0;
        while (i < stem_len) : (i += 1) {
            const ch = relative_path[i];
            buffer[prefix.len + i] = if (ch == '/' or ch == '\\') '.' else ch;
        }

        return buffer;
    }

    /// Get a configuration value
    pub fn get(self: *ConfigManager, key: []const u8) ?flare.Value {
        return self.flare_config.get(key);
    }

    /// Get a string configuration value
    pub fn getString(self: *ConfigManager, key: []const u8) ?[]const u8 {
        return self.flare_config.getString(key, null) catch null;
    }

    /// Get a boolean configuration value
    pub fn getBool(self: *ConfigManager, key: []const u8) ?bool {
        return self.flare_config.getBool(key);
    }

    /// Get an integer configuration value
    pub fn getInt(self: *ConfigManager, key: []const u8) ?i64 {
        return self.flare_config.getInt(key);
    }

    /// Set a configuration value
    pub fn set(self: *ConfigManager, key: []const u8, value: flare.Value) !void {
        try self.flare_config.set(key, value);
    }

    /// Execute a Ghostlang code snippet
    pub fn executeCode(self: *ConfigManager, code: []const u8) !void {
        _ = try self.ghostlang_runtime.executeCode(code);
    }
};

test "pluginPathToModuleName converts plugin paths" {
    const allocator = std.testing.allocator;

    const module1 = try ConfigManager.pluginPathToModuleName(allocator, "core/file-tree.gza");
    defer allocator.free(module1);
    try std.testing.expectEqualStrings("plugins.core.file-tree", module1);

    const module2 = try ConfigManager.pluginPathToModuleName(allocator, "statusline.gza");
    defer allocator.free(module2);
    try std.testing.expectEqualStrings("plugins.statusline", module2);
}
