//! core/config_manager.zig
//! Central configuration management using Flare + Ghostlang integration

const std = @import("std");
const flare = @import("flare");
const zlog = @import("zlog");
const GhostlangRuntime = @import("ghostlang_runtime.zig").GhostlangRuntime;

pub const ConfigManager = struct {
    allocator: std.mem.Allocator,
    flare_config: flare.Config,
    ghostlang_runtime: GhostlangRuntime,
    config_dir: []const u8,

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

        return ConfigManager{
            .allocator = allocator,
            .flare_config = flare_config,
            .ghostlang_runtime = ghostlang_runtime,
            .config_dir = config_dir,
        };
    }

    pub fn deinit(self: *ConfigManager) void {
        self.ghostlang_runtime.deinit();
        self.flare_config.deinit();
    }

    /// Load all configuration files in order
    pub fn loadConfiguration(self: *ConfigManager) !void {
        zlog.info("Loading phantom.grim configuration", .{});

        // Load in order of precedence (lowest to highest):
        // 1. Defaults
        try self.loadDefaults();

        // 2. User configuration
        try self.loadUserConfig();

        // 3. Plugin configurations
        try self.loadPluginConfigs();

        zlog.info("Configuration loaded successfully", .{});
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
        const plugins_dir = try std.fs.path.join(self.allocator, &[_][]const u8{ self.config_dir, "plugins" });
        defer self.allocator.free(plugins_dir);

        // TODO: Scan plugins directory and load plugin configs
        zlog.info("Plugin config loading placeholder", .{});
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