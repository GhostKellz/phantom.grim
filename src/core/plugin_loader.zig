//! core/plugin_loader.zig
//! Handles plugin loading, fetching, and management

const std = @import("std");
const Io = std.Io;
const zsync = @import("zsync");
const zlog = @import("zlog");
const zhttp = @import("zhttp");
const tar = std.tar;
const grim = @import("grim");
const Runtime = grim.runtime;

comptime {
    @compileLog(@hasDecl(Runtime, "init"));
    @compileLog(@hasDecl(Runtime, "Runtime"));
    @compileLog(@hasDecl(Runtime, "plugin_api"));
    for (std.meta.declarations(Runtime)) |decl| {
        @compileLog(decl.name);
    }
    const runtime_plugin_loader = Runtime.plugin_loader;
    @compileLog(@typeName(@TypeOf(runtime_plugin_loader)));
    @compileLog(@hasDecl(runtime_plugin_loader, "PluginLoader"));
    for (std.meta.declarations(runtime_plugin_loader)) |decl| {
        @compileLog("runtime.plugin_loader", decl.name);
    }
    @compileLog(@typeName(@TypeOf(Runtime.plugin_loader.PluginLoader)));
}

fn appendJsonString(buffer: *std.ArrayList(u8), allocator: std.mem.Allocator, value: []const u8) !void {
    const hex_digits = "0123456789abcdef";
    try buffer.append(allocator, '"');
    for (value) |ch| {
        switch (ch) {
            '"' => try buffer.appendSlice(allocator, "\\\""),
            '\\' => try buffer.appendSlice(allocator, "\\\\"),
            '\n' => try buffer.appendSlice(allocator, "\\n"),
            '\r' => try buffer.appendSlice(allocator, "\\r"),
            '\t' => try buffer.appendSlice(allocator, "\\t"),
            else => {
                if (ch < 0x20) {
                    var buf = [_]u8{ '\\', 'u', '0', '0', 0, 0 };
                    buf[4] = hex_digits[@as(usize, ch >> 4)];
                    buf[5] = hex_digits[@as(usize, ch & 0xF)];
                    try buffer.appendSlice(allocator, buf[0..]);
                } else {
                    try buffer.append(allocator, ch);
                }
            },
        }
    }
    try buffer.append(allocator, '"');
}

fn appendUnsigned(buffer: *std.ArrayList(u8), allocator: std.mem.Allocator, value: u64) !void {
    var buf: [20]u8 = undefined;
    const str = std.fmt.bufPrint(&buf, "{d}", .{value}) catch unreachable;
    try buffer.appendSlice(allocator, str);
}

pub const PluginLoader = struct {
    allocator: std.mem.Allocator,
    registry_url: []const u8,
    plugin_dir: []const u8,
    runtime: *Runtime,

    pub fn init(allocator: std.mem.Allocator, registry_url: []const u8, plugin_dir: []const u8) !*PluginLoader {
        var runtime_instance = try Runtime.init(allocator);
        errdefer runtime_instance.deinit();

        const runtime_ptr = try allocator.create(Runtime);
        runtime_ptr.* = runtime_instance;

        const loader = try allocator.create(PluginLoader);
        loader.* = .{
            .allocator = allocator,
            .registry_url = registry_url,
            .plugin_dir = plugin_dir,
            .runtime = runtime_ptr,
        };
        return loader;
    }

    pub fn deinit(self: *PluginLoader) void {
        self.runtime.deinit();
        self.allocator.destroy(self.runtime);
        self.allocator.destroy(self);
    }

    /// Fetch a plugin from the registry
    pub fn fetchPlugin(self: *PluginLoader, name: []const u8, version: []const u8) !void {
        zlog.info("Fetching plugin: {s}@{s}", .{ name, version });

        // Construct download URL
        const url = try std.fmt.allocPrint(self.allocator, "{s}/{s}/{s}.tar.gz", .{ self.registry_url, name, version });
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
            zlog.err("HTTP request failed with status: {}", .{response.status});
            return error.HttpRequestFailed;
        }

        // Create destination file
        const archive_path = try std.fs.path.join(self.allocator, &[_][]const u8{ dest_dir, "plugin.tar.gz" });
        defer self.allocator.free(archive_path);

        var file = try std.fs.cwd().createFile(archive_path, .{ .truncate = true });
        defer file.close();

        // Read response body into memory
        const body = try response.readAll(max_archive_size);
        defer self.allocator.free(body);

        // Write to file
        try file.writeAll(body);

        zlog.info("Downloaded archive to: {s}", .{archive_path});
    }

    /// Extract plugin archive into the destination directory.
    fn extractPlugin(self: *PluginLoader, plugin_dir: []const u8) !void {
        const archive_path = try std.fs.path.join(self.allocator, &[_][]const u8{ plugin_dir, "plugin.tar.gz" });
        defer self.allocator.free(archive_path);

        zlog.info("Extracting archive: {s}", .{archive_path});

        var file = try std.fs.cwd().openFile(archive_path, .{});
        defer file.close();

        var file_reader_buffer: [8 * 1024]u8 = undefined;
        var file_reader = file.reader(&file_reader_buffer);

        var gzip_buffer: [std.compress.flate.max_window_len]u8 = undefined;
        var gzip_stream = std.compress.flate.Decompress.init(&file_reader.interface, .gzip, &gzip_buffer);

        var file_name_buffer: [std.fs.max_path_bytes]u8 = undefined;
        var link_name_buffer: [std.fs.max_path_bytes]u8 = undefined;
        var tar_iter: tar.Iterator = .init(&gzip_stream.reader, .{
            .file_name_buffer = &file_name_buffer,
            .link_name_buffer = &link_name_buffer,
            .diagnostics = null,
        });

        var out_dir = try std.fs.cwd().openDir(plugin_dir, .{ .iterate = true, .access_sub_paths = true });
        defer out_dir.close();

        var discard_buffer: [256]u8 = undefined;

        while (try tar_iter.next()) |entry| {
            const original_name = entry.name;
            const name = trimTrailingSeparators(original_name);

            var discarding = Io.Writer.Discarding.init(&discard_buffer);

            if (!isSafeRelativePath(name)) {
                zlog.warn("Skipping unsafe archive path: {s}", .{original_name});
                try tar_iter.streamRemaining(entry, &discarding.writer);
                continue;
            }

            switch (entry.kind) {
                .directory => {
                    if (name.len != 0) {
                        try out_dir.makePath(name);
                    }
                    try tar_iter.streamRemaining(entry, &discarding.writer);
                },
                .sym_link => {
                    zlog.warn("Skipping link entry in plugin archive: {s}", .{name});
                    try tar_iter.streamRemaining(entry, &discarding.writer);
                },
                .file => {
                    if (std.fs.path.dirname(name)) |parent| {
                        if (parent.len != 0) {
                            try out_dir.makePath(parent);
                        }
                    }

                    var out_file = try out_dir.createFile(name, .{ .truncate = true });
                    defer out_file.close();

                    var file_buffer: [4 * 1024]u8 = undefined;
                    var file_writer = out_file.writer(&file_buffer);
                    try tar_iter.streamRemaining(entry, &file_writer.interface);
                    try file_writer.interface.flush();
                },
            }
        }

        std.fs.cwd().deleteFile(archive_path) catch |err| {
            zlog.warn("Failed to remove plugin archive {s}: {any}", .{ archive_path, err });
        };
    }

    fn isPluginUpToDate(self: *PluginLoader, plugin_path: []const u8, name: []const u8, version: []const u8) !bool {
        const manifest_path = try std.fs.path.join(self.allocator, &[_][]const u8{ plugin_path, manifest_file });
        defer self.allocator.free(manifest_path);

        const limit = Io.Limit.limited(max_manifest_size);
        const data = std.fs.cwd().readFileAlloc(manifest_path, self.allocator, limit) catch |err| {
            if (err == error.FileNotFound) {
                return false;
            }
            return err;
        };
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

        const now = std.time.timestamp();

        const manifest = Manifest{
            .name = name,
            .version = version,
            .registry_url = self.registry_url,
            .installed_at = std.math.cast(u64, now) orelse 0,
        };

        var json_buffer = std.ArrayList(u8).empty;
        defer json_buffer.deinit(self.allocator);

        try json_buffer.append(self.allocator, '{');
        try json_buffer.appendSlice(self.allocator, "\"name\":");
        try appendJsonString(&json_buffer, self.allocator, manifest.name);
        try json_buffer.appendSlice(self.allocator, ",\"version\":");
        try appendJsonString(&json_buffer, self.allocator, manifest.version);
        try json_buffer.appendSlice(self.allocator, ",\"registry_url\":");
        try appendJsonString(&json_buffer, self.allocator, manifest.registry_url);
        try json_buffer.appendSlice(self.allocator, ",\"installed_at\":");
        try appendUnsigned(&json_buffer, self.allocator, manifest.installed_at);
        try json_buffer.append(self.allocator, '}');

        const json_text = try json_buffer.toOwnedSlice(self.allocator);
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
    const max_archive_size: usize = 20 * 1024 * 1024;

    const Manifest = struct {
        name: []const u8,
        version: []const u8,
        registry_url: []const u8,
        installed_at: u64,
    };
    /// Load all installed plugin modules into the Ghostlang runtime.
    pub fn loadInstalled(self: *PluginLoader) !void {
        var dir = std.fs.cwd().openDir(self.plugin_dir, .{ .iterate = true }) catch |err| {
            if (err == error.FileNotFound) {
                zlog.info("Plugin directory not found: {s}", .{self.plugin_dir});
                return;
            }
            return err;
        };
        defer dir.close();

        var walker = try dir.walk(self.allocator);
        defer walker.deinit();

        var loaded_count: usize = 0;

        while (try walker.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.endsWith(u8, entry.path, ".gza")) continue;

            const module_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.plugin_dir, entry.path });
            defer self.allocator.free(module_path);

            self.runtime.loadModule(module_path) catch |err| {
                zlog.err("Failed to load plugin module {s}: {any}", .{ module_path, err });
                continue;
            };

            loaded_count += 1;
        }

        zlog.info("Loaded {d} plugins from {s}", .{ loaded_count, self.plugin_dir });
    }

    /// Load a single plugin module by path (absolute or relative to plugin directory).
    pub fn loadPlugin(self: *PluginLoader, module_path: []const u8) !void {
        if (std.fs.path.isAbsolute(module_path)) {
            try self.runtime.loadModule(module_path);
            zlog.info("Plugin loaded: {s}", .{module_path});
            return;
        }

        const full_path = try std.fs.path.join(self.allocator, &[_][]const u8{ self.plugin_dir, module_path });
        defer self.allocator.free(full_path);

        try self.runtime.loadModule(full_path);
        zlog.info("Plugin loaded: {s}", .{full_path});
    }

    fn relativePathToModuleName(self: *PluginLoader, relative_path: []const u8) ![]u8 {
        if (!std.mem.endsWith(u8, relative_path, ".gza")) {
            return error.InvalidPluginPath;
        }

        const stem_len = relative_path.len - ".gza".len;
        const prefix = "plugins.";
        const total_len = prefix.len + stem_len;
        var buffer = try self.allocator.alloc(u8, total_len);

        std.mem.copyForwards(u8, buffer[0..prefix.len], prefix);

        var i: usize = 0;
        while (i < stem_len) : (i += 1) {
            const ch = relative_path[i];
            buffer[prefix.len + i] = switch (ch) {
                '/', '\\' => '.',
                else => ch,
            };
        }

        return buffer;
    }
};
