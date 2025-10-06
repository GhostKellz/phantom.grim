//! core/plugin_loader.zig
//! Handles plugin loading, fetching, and management

const std = @import("std");
const zsync = @import("zsync");
const zlog = @import("zlog");
const zhttp = @import("zhttp");
const tar = std.tar;

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

    const plugin_relative = try normalizedPluginPath(self.allocator, name);
    defer self.allocator.free(plugin_relative);

    // Create plugin directory
    const plugin_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.plugin_dir, plugin_relative });
        defer self.allocator.free(plugin_path);

        if (try self.isPluginUpToDate(plugin_path, name, version)) {
            zlog.info("Plugin {s}@{s} already installed", .{ name, version });
            return;
        }

        errdefer std.fs.cwd().deleteTree(plugin_path) catch {};

        std.fs.cwd().deleteTree(plugin_path) catch |err| {
            if (err != error.FileNotFound) {
                return err;
            }
        };

        try std.fs.cwd().makePath(plugin_path);

        // Download the plugin archive
        try self.downloadPlugin(url, plugin_path);

        // Extract the plugin
        try self.extractPlugin(plugin_path);

        try self.writeManifest(plugin_path, name, version);

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

    /// Extract plugin archive into the destination directory.
    fn extractPlugin(self: *PluginLoader, plugin_dir: []const u8) !void {
        const archive_path = try std.fs.path.join(self.allocator, &[_][]const u8{ plugin_dir, "plugin.tar.gz" });
        defer self.allocator.free(archive_path);

        zlog.info("Extracting archive: {s}", .{archive_path});

        var file = try std.fs.cwd().openFile(archive_path, .{});
        defer file.close();

        var buffered_reader = std.io.bufferedReader(file.reader());
        var gzip_reader = try std.compress.gzip.reader(self.allocator, buffered_reader.reader());
        defer gzip_reader.deinit();

        var tar_reader = try tar.Reader.init(self.allocator, gzip_reader.reader());
        defer tar_reader.deinit();

        var out_dir = try std.fs.cwd().openDir(plugin_dir, .{ .iterate = true, .access_sub_paths = true });
        defer out_dir.close();

        while (try tar_reader.next()) |entry| {
            const original_name = entry.header.name;
            const name = trimTrailingSeparators(original_name);

            if (!isSafeRelativePath(name)) {
                zlog.warn("Skipping unsafe archive path: {s}", .{original_name});
                _ = try std.io.copyAll(entry.stream, std.io.null_writer);
                continue;
            }

            const flag = entry.header.typeflag;
            if (flag == tar.TypeFlag.directory) {
                if (name.len == 0) continue;
                try out_dir.makePath(name);
                continue;
            }

            if (flag == tar.TypeFlag.symlink or flag == tar.TypeFlag.hardlink) {
                zlog.warn("Skipping link entry in plugin archive: {s}", .{name});
                _ = try std.io.copyAll(entry.stream, std.io.null_writer);
                continue;
            }

            if (std.fs.path.dirname(name)) |parent| {
                if (parent.len != 0) {
                    try out_dir.makePath(parent);
                }
            }

            var out_file = try out_dir.createFile(name, .{ .truncate = true });
            defer out_file.close();

            const written = try std.io.copyAll(entry.stream, out_file.writer());
            const expected = entry.header.size;
            if (written != expected) {
                zlog.warn("Wrote {d} bytes but expected {d} for {s}", .{ written, expected, name });
            }
        }

        std.fs.cwd().deleteFile(archive_path) catch |err| {
            zlog.warn("Failed to remove plugin archive {s}: {any}", .{ archive_path, err });
        };
    }

    fn isPluginUpToDate(self: *PluginLoader, plugin_path: []const u8, name: []const u8, version: []const u8) !bool {
        const manifest_path = try std.fs.path.join(self.allocator, &[_][]const u8{ plugin_path, manifest_file });
        defer self.allocator.free(manifest_path);

        var file = std.fs.cwd().openFile(manifest_path, .{}) catch |err| {
            if (err == error.FileNotFound) {
                return false;
            }
            return err;
        };
        defer file.close();

        const data = try file.readToEndAlloc(self.allocator, max_manifest_size);
        defer self.allocator.free(data);

        const parsed = try std.json.parseFromSlice(Manifest, self.allocator, data, .{ .ignore_unknown_fields = true });
        defer parsed.deinit();

        const manifest = parsed.value;
        return std.mem.eql(u8, manifest.name, name) and
            std.mem.eql(u8, manifest.version, version) and
            std.mem.eql(u8, manifest.registry_url, self.registry_url);
    }

    fn writeManifest(self: *PluginLoader, plugin_path: []const u8, name: []const u8, version: []const u8) !void {
        const manifest_path = try std.fs.path.join(self.allocator, &[_][]const u8{ plugin_path, manifest_file });
        defer self.allocator.free(manifest_path);

        const manifest = Manifest{
            .name = name,
            .version = version,
            .registry_url = self.registry_url,
            .installed_at = std.time.timestamp(),
        };

        const json_text = try std.json.stringifyAlloc(self.allocator, manifest, .{ .whitespace = .indent_2 });
        defer self.allocator.free(json_text);

        var file = try std.fs.cwd().createFile(manifest_path, .{ .truncate = true });
        defer file.close();

        try file.writeAll(json_text);
    }


fn isSafeRelativePath(path: []const u8) bool {
    if (path.len == 0) return false;
    if (std.fs.path.isAbsolute(path)) return false;
    if (std.mem.indexOf(u8, path, ":")) |_| return false;

    var i: usize = 0;
    while (i < path.len) : (i += 1) {
        if (path[i] == '.' and i + 1 < path.len and path[i + 1] == '.') {
            const before = if (i == 0) null else path[i - 1];
            const after = if (i + 2 < path.len) path[i + 2] else null;
            const before_sep = before == null or before == '/' or before == '\\';
            const after_sep = after == null or after == '/' or after == '\\';
            if (before_sep and after_sep) return false;
        }
    }

    return true;
}

fn trimTrailingSeparators(path: []const u8) []const u8 {
    var end = path.len;
    while (end > 0) : (end -= 1) {
        const ch = path[end - 1];
        if (ch != '/' and ch != '\\') break;
    }
    return path[0..end];
}

fn normalizedPluginPath(allocator: std.mem.Allocator, name: []const u8) ![]u8 {
    var buffer = try allocator.alloc(u8, name.len);
    for (name, 0..) |ch, idx| {
        buffer[idx] = switch (ch) {
            '.' => '/',
            '\\' => '/',
            else => ch,
        };
    }
    return buffer;
}

const manifest_file = "manifest.json";
const max_manifest_size: usize = 64 * 1024;

const Manifest = struct {
    name: []const u8,
    version: []const u8,
    registry_url: []const u8,
    installed_at: u64,
};
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