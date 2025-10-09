//! core/syntax_highlighter.zig
//! Caches tree-sitter highlights to avoid repeated parsing during rendering.

const std = @import("std");
const config = @import("config_manager.zig");

pub const SyntaxHighlighter = struct {
    allocator: std.mem.Allocator,
    config_manager: *config.ConfigManager,
    cache: CacheMap,
    generation: u64 = 0,

    const CacheMap = std.AutoHashMap(CacheKey, CachedValue);

    pub const CacheKey = struct {
        buffer_id: u64,
        language_hash: u64,
        content_hash: u64,
    };

    const CachedValue = struct {
        highlight_set: config.HighlightSet,
        generation: u64,
    };

    pub const Request = struct {
        /// Stable identifier for the buffer/window pair.
        buffer_id: u64,
        /// Name of the language/grammar (e.g. "zig", "lua").
        language: []const u8,
        /// Canonical path used for tree-sitter language inference.
        path: []const u8,
        /// Current buffer contents.
        content: []const u8,
    };

    /// Result view returned to renderers.
    pub const Result = struct {
        highlights: *const config.HighlightSet,
        cache_generation: u64,
        cache_hit: bool,
    };

    pub fn init(allocator: std.mem.Allocator, config_manager: *config.ConfigManager) SyntaxHighlighter {
        return SyntaxHighlighter{
            .allocator = allocator,
            .config_manager = config_manager,
            .cache = CacheMap.init(allocator),
            .generation = 0,
        };
    }

    pub fn deinit(self: *SyntaxHighlighter) void {
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.highlight_set.deinit(self.allocator);
        }
        self.cache.deinit();
    }

    fn hashBytes(bytes: []const u8) u64 {
        var hasher = std.hash.Wyhash.init(0);
        hasher.update(bytes);
        return hasher.final();
    }

    fn makeKey(request: Request) CacheKey {
        return CacheKey{
            .buffer_id = request.buffer_id,
            .language_hash = hashBytes(request.language),
            .content_hash = hashBytes(request.content),
        };
    }

    /// Fetch highlights for the given request, returning a cached entry when available.
    pub fn getHighlights(self: *SyntaxHighlighter, request: Request) !Result {
        const key = makeKey(request);
        if (self.cache.getPtr(key)) |value_ptr| {
            return Result{
                .highlights = &value_ptr.highlight_set,
                .cache_generation = value_ptr.generation,
                .cache_hit = true,
            };
        }

        var highlight_set = try self.config_manager.getHighlights(request.path, request.content);
        errdefer highlight_set.deinit(self.allocator);

        self.generation += 1;

        const gop = try self.cache.getOrPut(key);
        if (gop.found_existing) {
            // Another thread may have populated the cache between get and insert.
            // Prefer existing entry to avoid double-free risk.
            highlight_set.deinit(self.allocator);
            return Result{
                .highlights = &gop.value_ptr.highlight_set,
                .cache_generation = gop.value_ptr.generation,
                .cache_hit = true,
            };
        }

        gop.value_ptr.* = CachedValue{
            .highlight_set = highlight_set,
            .generation = self.generation,
        };

        return Result{
            .highlights = &gop.value_ptr.highlight_set,
            .cache_generation = self.generation,
            .cache_hit = false,
        };
    }

    /// Invalidate any cached highlights for the specified buffer id.
    pub fn invalidateBuffer(self: *SyntaxHighlighter, buffer_id: u64) !void {
        var keys_to_remove = std.ArrayList(CacheKey).empty;
        defer keys_to_remove.deinit(self.allocator);

        var it = self.cache.iterator();
        while (it.next()) |entry| {
            if (entry.key_ptr.buffer_id == buffer_id) {
                try keys_to_remove.append(self.allocator, entry.key_ptr.*);
            }
        }

        for (keys_to_remove.items) |key| {
            if (self.cache.fetchRemove(key)) |kv| {
                kv.value.highlight_set.deinit(self.allocator);
            }
        }
    }

    /// Reset the cache entirely, freeing all stored highlights.
    pub fn reset(self: *SyntaxHighlighter) void {
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.highlight_set.deinit(self.allocator);
        }
        self.cache.clearRetainingCapacity();
        self.generation += 1;
    }
};
