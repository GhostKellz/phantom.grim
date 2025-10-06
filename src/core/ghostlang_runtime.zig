//! core/ghostlang_runtime.zig
//! Integration layer for Ghostlang scripting engine

const std = @import("std");
const ghostlang = @import("ghostlang");
const zlog = @import("zlog");
const flare = @import("flare");

pub const GhostlangRuntime = struct {
    allocator: std.mem.Allocator,
    engine: ghostlang.ScriptEngine,
    config_manager: *flare.Config,
    config_dir: []const u8,
    loaded_modules: std.StringHashMap(void),
    next_keymap_id: usize = 0,
    next_autocmd_id: usize = 0,

    pub fn init(allocator: std.mem.Allocator, config_manager: *flare.Config, config_dir: []const u8) !GhostlangRuntime {
        const engine_config = ghostlang.EngineConfig{
            .allocator = allocator,
            // TODO: Configure sandboxing options
            .allow_io = true, // Allow for plugin loading
            .allow_syscalls = false, // Keep sandboxed
            .deterministic = false, // Allow timing-dependent operations
            .memory_limit = 10 * 1024 * 1024, // 10MB limit
            .execution_timeout_ms = 5000, // 5 second timeout
        };

        var engine = try ghostlang.ScriptEngine.create(engine_config);

        // Register built-in functions
        try engine.registerFunction("print", printFunc);
        try engine.registerFunction("set", setOptionFunc);
        try engine.registerFunction("map", mapKeyFunc);
        try engine.registerFunction("autocmd", autocmdFunc);
        try engine.registerFunction("require", requireFunc);

        return GhostlangRuntime{
            .allocator = allocator,
            .engine = engine,
            .config_manager = config_manager,
            .config_dir = config_dir,
            .loaded_modules = std.StringHashMap(void).init(allocator),
        };
    }

    pub fn deinit(self: *GhostlangRuntime) void {
        var it = self.loaded_modules.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.loaded_modules.deinit();
        self.engine.deinit();
    }

    /// Load and execute a .gza configuration file
    pub fn loadConfigFile(self: *GhostlangRuntime, file_path: []const u8) !void {
        zlog.info("Loading config file: {s}", .{file_path});

        // Read the file
        const source = try std.fs.cwd().readFileAlloc(file_path, self.allocator, std.Io.Limit.unlimited);
        defer self.allocator.free(source);

        // Load and execute the script
    var script = try self.engine.loadScript(source);
    defer script.deinit();

            const previous = active_runtime;
            active_runtime = self;
            defer active_runtime = previous;

    const result = try script.run();
        _ = result; // TODO: Handle return values

        zlog.info("Config file loaded successfully: {s}", .{file_path});
    }

    /// Execute a Ghostlang code snippet
    pub fn executeCode(self: *GhostlangRuntime, code: []const u8) !ghostlang.ScriptValue {
        var script = try self.engine.loadScript(code);
        defer script.deinit();

            const previous = active_runtime;
            active_runtime = self;
            defer active_runtime = previous;

        return try script.run();
    }

    /// Call a function defined in loaded scripts
    pub fn callFunction(self: *GhostlangRuntime, name: []const u8, args: anytype) !ghostlang.ScriptValue {
           const previous = active_runtime;
           active_runtime = self;
           defer active_runtime = previous;

        return try self.engine.call(name, args);
    }
};

var active_runtime: ?*GhostlangRuntime = null;

fn getActiveRuntimeFor(name: []const u8) ?*GhostlangRuntime {
    if (active_runtime) |runtime| {
        return runtime;
    }
    zlog.err("{s} called without active runtime context", .{name});
    return null;
}

fn scriptValueToString(value: ghostlang.ScriptValue) ?[]const u8 {
    return switch (value) {
        .string => |s| s,
        else => null,
    };
}

fn scriptValueToFlareValue(value: ghostlang.ScriptValue) ?flare.Value {
    const max_safe_int: f64 = 9007199254740991.0; // 2^53 - 1

    return switch (value) {
        .nil => flare.Value{ .null_value = {} },
        .boolean => |b| flare.Value{ .bool_value = b },
        .number => |n| blk: {
            const floored = std.math.floor(n);
            if (floored == n and n >= -max_safe_int and n <= max_safe_int) {
                const as_int: i64 = @intFromFloat(n);
                break :blk flare.Value{ .int_value = as_int };
            }
            break :blk flare.Value{ .float_value = n };
        },
        .string => |s| flare.Value{ .string_value = s },
        else => null,
    };
}

fn storeConfigValue(runtime: *GhostlangRuntime, key: []const u8, value: flare.Value) void {
    runtime.config_manager.setValue(key, value) catch |err| {
        zlog.err("Failed to set config key {s}: {any}", .{ key, err });
    };
}

fn storeIndexedField(runtime: *GhostlangRuntime, prefix: []const u8, index: usize, field: []const u8, value: flare.Value) void {
    const key = std.fmt.allocPrint(runtime.allocator, "{s}.{d}.{s}", .{ prefix, index, field }) catch {
        zlog.err("Failed to allocate config key for {s}.{d}.{s}", .{ prefix, index, field });
        return;
    };
    defer runtime.allocator.free(key);
    storeConfigValue(runtime, key, value);
}

fn setCounter(runtime: *GhostlangRuntime, prefix: []const u8, count: usize) void {
    const key = std.fmt.allocPrint(runtime.allocator, "{s}.count", .{prefix}) catch {
        zlog.err("Failed to allocate config counter key for {s}", .{prefix});
        return;
    };
    defer runtime.allocator.free(key);
    const count_i64: i64 = @intCast(count);
    storeConfigValue(runtime, key, flare.Value{ .int_value = count_i64 });
}

fn moduleNameToRelativePath(allocator: std.mem.Allocator, module_name: []const u8) ![]u8 {
    const suffix = ".gza";
    var buffer = try allocator.alloc(u8, module_name.len + suffix.len);
    var i: usize = 0;
    while (i < module_name.len) : (i += 1) {
        buffer[i] = if (module_name[i] == '.') '/' else module_name[i];
    }
    std.mem.copyForwards(u8, buffer[module_name.len .. module_name.len + suffix.len], suffix);
    return buffer;
}

// Built-in functions available to Ghostlang scripts

fn printFunc(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    for (args) |arg| {
        switch (arg) {
            .string => |s| std.debug.print("{s}", .{s}),
            .number => |n| std.debug.print("{}", .{n}),
            .boolean => |b| std.debug.print("{}", .{b}),
            else => std.debug.print("{any}", .{arg}),
        }
        std.debug.print(" ", .{});
    }
    std.debug.print("\n", .{});
    return ghostlang.ScriptValue{ .nil = {} };
}

fn setOptionFunc(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    const runtime = getActiveRuntimeFor("set") orelse return ghostlang.ScriptValue{ .nil = {} };

    if (args.len < 2) {
        zlog.warn("set() requires at least 2 arguments", .{});
        return ghostlang.ScriptValue{ .nil = {} };
    }

    const key = scriptValueToString(args[0]) orelse {
        zlog.warn("set() key must be a string", .{});
        return ghostlang.ScriptValue{ .nil = {} };
    };

    if (scriptValueToFlareValue(args[1])) |value| {
        storeConfigValue(runtime, key, value);
    } else {
        zlog.warn("set() unsupported value type for key {s}", .{key});
    }

    return ghostlang.ScriptValue{ .nil = {} };
}

fn mapKeyFunc(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    const runtime = getActiveRuntimeFor("map") orelse return ghostlang.ScriptValue{ .nil = {} };

    if (args.len < 3) {
        zlog.warn("map() requires 3 arguments: mode, key, command", .{});
        return ghostlang.ScriptValue{ .nil = {} };
    }

    const mode = scriptValueToString(args[0]) orelse {
        zlog.warn("map() mode must be a string", .{});
        return ghostlang.ScriptValue{ .nil = {} };
    };
    const lhs = scriptValueToString(args[1]) orelse {
        zlog.warn("map() key must be a string", .{});
        return ghostlang.ScriptValue{ .nil = {} };
    };
    const rhs = scriptValueToString(args[2]) orelse {
        zlog.warn("map() command must be a string", .{});
        return ghostlang.ScriptValue{ .nil = {} };
    };

    const index = runtime.next_keymap_id;
    runtime.next_keymap_id += 1;

    storeIndexedField(runtime, "keymaps", index, "mode", flare.Value{ .string_value = mode });
    storeIndexedField(runtime, "keymaps", index, "lhs", flare.Value{ .string_value = lhs });
    storeIndexedField(runtime, "keymaps", index, "rhs", flare.Value{ .string_value = rhs });

    if (args.len >= 4) {
        if (scriptValueToString(args[3])) |desc| {
            storeIndexedField(runtime, "keymaps", index, "desc", flare.Value{ .string_value = desc });
        } else if (args[3] != .nil) {
            zlog.warn("map() optional description must be a string", .{});
        }
    }

    setCounter(runtime, "keymaps", runtime.next_keymap_id);
    return ghostlang.ScriptValue{ .nil = {} };
}

fn autocmdFunc(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    const runtime = getActiveRuntimeFor("autocmd") orelse return ghostlang.ScriptValue{ .nil = {} };

    if (args.len < 3) {
        zlog.warn("autocmd() requires at least 3 arguments: event, pattern, command", .{});
        return ghostlang.ScriptValue{ .nil = {} };
    }

    const event = scriptValueToString(args[0]) orelse {
        zlog.warn("autocmd() event must be a string", .{});
        return ghostlang.ScriptValue{ .nil = {} };
    };
    const pattern = scriptValueToString(args[1]) orelse {
        zlog.warn("autocmd() pattern must be a string", .{});
        return ghostlang.ScriptValue{ .nil = {} };
    };
    const command = scriptValueToString(args[2]) orelse {
        zlog.warn("autocmd() command must be a string", .{});
        return ghostlang.ScriptValue{ .nil = {} };
    };

    const index = runtime.next_autocmd_id;
    runtime.next_autocmd_id += 1;

    storeIndexedField(runtime, "autocmds", index, "event", flare.Value{ .string_value = event });
    storeIndexedField(runtime, "autocmds", index, "pattern", flare.Value{ .string_value = pattern });
    storeIndexedField(runtime, "autocmds", index, "command", flare.Value{ .string_value = command });

    setCounter(runtime, "autocmds", runtime.next_autocmd_id);
    return ghostlang.ScriptValue{ .nil = {} };
}

fn requireFunc(args: []const ghostlang.ScriptValue) ghostlang.ScriptValue {
    const runtime = getActiveRuntimeFor("require") orelse return ghostlang.ScriptValue{ .nil = {} };

    if (args.len < 1) {
        zlog.warn("require() requires 1 argument: module name", .{});
        return ghostlang.ScriptValue{ .nil = {} };
    }

    const module_name = scriptValueToString(args[0]) orelse {
        zlog.warn("require() module name must be a string", .{});
        return ghostlang.ScriptValue{ .nil = {} };
    };

    if (runtime.loaded_modules.contains(module_name)) {
        return ghostlang.ScriptValue{ .nil = {} };
    }

    const relative = moduleNameToRelativePath(runtime.allocator, module_name) catch {
        zlog.err("require(): failed to build path for module {s}", .{module_name});
        return ghostlang.ScriptValue{ .nil = {} };
    };
    defer runtime.allocator.free(relative);

    const full_path = std.fs.path.join(runtime.allocator, &[_][]const u8{ runtime.config_dir, relative }) catch {
        zlog.err("require(): failed to join path for module {s}", .{module_name});
        return ghostlang.ScriptValue{ .nil = {} };
    };
    defer runtime.allocator.free(full_path);

    if (std.fs.cwd().access(full_path, .{})) |_| {} else |err| {
        zlog.err("require(): module {s} not found ({any})", .{ module_name, err });
        return ghostlang.ScriptValue{ .nil = {} };
    }

    runtime.loadConfigFile(full_path) catch |err| {
        zlog.err("require(): failed to load module {s}: {any}", .{ module_name, err });
        return ghostlang.ScriptValue{ .nil = {} };
    };

    const module_key = runtime.allocator.dupe(u8, module_name) catch {
        zlog.err("require(): failed to cache module name {s}", .{module_name});
        return ghostlang.ScriptValue{ .nil = {} };
    };
    errdefer runtime.allocator.free(module_key);

    const gop = runtime.loaded_modules.getOrPut(module_key) catch {
        zlog.err("require(): failed to record module {s}", .{module_name});
        return ghostlang.ScriptValue{ .nil = {} };
    };
    if (gop.found_existing) {
        runtime.allocator.free(module_key);
    } else {
        gop.value_ptr.* = {};
    }

    return ghostlang.ScriptValue{ .nil = {} };
}