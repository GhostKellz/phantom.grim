const std = @import("std");
const ConfigManager = @import("core/config_manager.zig").ConfigManager;
const PluginLoader = @import("core/plugin_loader.zig").PluginLoader;
const zlog = @import("zlog");

pub fn main() !void {
    // Initialize logging
    zlog.info("Starting phantom.grim", .{});

    // Setup allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Get config directory (default to current directory for now)
    const config_dir = ".";

    // Initialize configuration manager
    var config_manager = try ConfigManager.init(allocator, config_dir);
    defer config_manager.deinit();

    // Load all configurations
    try config_manager.loadConfiguration();

    // Initialize plugin loader
    // const registry_url = "https://registry.phantom.grim";
    // const plugin_dir = "./plugins";
    // var plugin_loader = PluginLoader.init(allocator, registry_url, plugin_dir);

    // TODO: Load core plugins
    // try plugin_loader.loadPlugin("file-tree");
    // try plugin_loader.loadPlugin("fuzzy-finder");

    zlog.info("phantom.grim initialized successfully", .{});

    // Keep running (in a real implementation, this would integrate with Grim)
    // For now, just demonstrate config loading
    if (config_manager.getString("editor.theme")) |theme| {
        std.debug.print("Loaded theme: {s}\n", .{theme});
    }
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
