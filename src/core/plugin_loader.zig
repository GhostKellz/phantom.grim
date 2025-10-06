//! core/plugin_loader.zig
//! Handles plugin loading, fetching, and management

const std = @import("std");
const zsync = @import("zsync");
const zlog = @import("zlog");
const zhttp = @import("zhttp");

pub const PluginLoader = struct {
    allocator: std.mem.Allocator,
    registry_url: []const u8,
    plugin_dir: []const u8,

    pub fn init(allocator: std.mem.Allocator, registry_url: []const u8, plugin_dir: []const u8) PluginLoader {
        return PluginLoader{
            .allocator = allocator,
            .registry_url = registry_url,
            .plugin_dir = plugin_dir,
        };
    }

    /// Fetch a plugin from the registry
    pub fn fetchPlugin(self: *PluginLoader, name: []const u8, version: []const u8) !void {
        zlog.info("Fetching plugin: {s}@{s}", .{name, version});

        // Construct download URL
        const url = try std.fmt.allocPrint(
            self.allocator,
            "{s}/{s}/{s}.tar.gz",
            .{self.registry_url, name, version}
        );
        defer self.allocator.free(url);

        // Create plugin directory
        const plugin_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.plugin_dir, name });
        defer self.allocator.free(plugin_path);

        try std.fs.cwd().makePath(plugin_path);

        // Download the plugin archive
        try self.downloadPlugin(url, plugin_path);

        // Extract the plugin
        try self.extractPlugin(plugin_path);

        zlog.info("Plugin {s} fetched successfully", .{name});
    }

    /// Download plugin archive
    fn downloadPlugin(self: *PluginLoader, url: []const u8, dest_dir: []const u8) !void {
        zlog.info("Downloading from: {s}", .{url});

        // Use zhttp for simple HTTP GET
        var response = try zhttp.get(self.allocator, url);
        defer response.deinit();

        if (!response.isSuccess()) {
            zlog.err("HTTP request failed with status: {}", .{response.status_code});
            return error.HttpRequestFailed;
        }

        // Create destination file
        const archive_path = try std.fs.path.join(self.allocator, &[_][]const u8{ dest_dir, "plugin.tar.gz" });
        defer self.allocator.free(archive_path);

        var file = try std.fs.cwd().createFile(archive_path, .{});
        defer file.close();

        // Get response body as bytes
        const body = try response.bytes();
        defer self.allocator.free(body);

        // Write to file
        _ = try file.write(body);

        zlog.info("Downloaded archive to: {s}", .{archive_path});
    }

    /// Extract plugin archive
    fn extractPlugin(self: *PluginLoader, plugin_dir: []const u8) !void {
        const archive_path = try std.fs.path.join(self.allocator, &[_][]const u8{ plugin_dir, "plugin.tar.gz" });
        defer self.allocator.free(archive_path);

        zlog.info("Extracting archive: {s}", .{archive_path});

        // For now, just log - we'll implement tar.gz extraction later
        // TODO: Implement tar.gz extraction
        zlog.info("Archive extraction placeholder - would extract to: {s}", .{plugin_dir});
    }

    /// Load a plugin by name
    pub fn loadPlugin(self: *PluginLoader, name: []const u8) !void {
        _ = self;
        zlog.info("Loading plugin: {s}", .{name});

        // TODO: Check if plugin is installed
        // TODO: Load plugin configuration
        // TODO: Initialize plugin

        zlog.info("Plugin {s} loaded", .{name});
    }
};