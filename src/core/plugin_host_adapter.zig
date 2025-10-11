//! core/plugin_host_adapter.zig
//! Bridges grim runtime host callbacks into phantom.grim systems.

const std = @import("std");
const zlog = @import("zlog");
const grim = @import("grim");

const Host = grim.host.Host;

/// Optional integration point for command registration.
pub const CommandRegistrar = struct {
    ctx: *anyopaque,
    registerFn: *const fn (ctx: *anyopaque, action: *const Host.CommandAction) anyerror!void,
};

/// Optional integration point for keymap registration.
pub const KeymapRegistrar = struct {
    ctx: *anyopaque,
    registerFn: *const fn (ctx: *anyopaque, action: *const Host.KeymapAction) anyerror!void,
};

/// Optional integration point for event handler registration.
pub const EventRegistrar = struct {
    ctx: *anyopaque,
    registerFn: *const fn (ctx: *anyopaque, action: *const Host.EventAction) anyerror!void,
};

/// Optional integration point for theme/highlight registration.
pub const ThemeRegistrar = struct {
    ctx: *anyopaque,
    registerFn: *const fn (ctx: *anyopaque, action: *const Host.ThemeAction) anyerror!void,
};

/// Optional sink for plugin-generated messages.
pub const MessageSink = struct {
    ctx: *anyopaque,
    handlerFn: *const fn (ctx: *anyopaque, message: []const u8) anyerror!void,
};

/// Adapter passed to grim's Host.ActionCallbacks.
pub const PhantomPluginHost = struct {
    allocator: std.mem.Allocator,
    command_registrar: ?CommandRegistrar = null,
    keymap_registrar: ?KeymapRegistrar = null,
    event_registrar: ?EventRegistrar = null,
    theme_registrar: ?ThemeRegistrar = null,
    message_sink: ?MessageSink = null,

    pub fn init(allocator: std.mem.Allocator) PhantomPluginHost {
        return .{ .allocator = allocator };
    }

    pub fn deinit(self: *PhantomPluginHost) void {
        self.command_registrar = null;
        self.keymap_registrar = null;
        self.event_registrar = null;
        self.theme_registrar = null;
        self.message_sink = null;
        self.allocator = undefined;
    }

    pub fn setCommandRegistrar(self: *PhantomPluginHost, registrar: CommandRegistrar) void {
        self.command_registrar = registrar;
    }

    pub fn clearCommandRegistrar(self: *PhantomPluginHost) void {
        self.command_registrar = null;
    }

    pub fn setKeymapRegistrar(self: *PhantomPluginHost, registrar: KeymapRegistrar) void {
        self.keymap_registrar = registrar;
    }

    pub fn clearKeymapRegistrar(self: *PhantomPluginHost) void {
        self.keymap_registrar = null;
    }

    pub fn setEventRegistrar(self: *PhantomPluginHost, registrar: EventRegistrar) void {
        self.event_registrar = registrar;
    }

    pub fn clearEventRegistrar(self: *PhantomPluginHost) void {
        self.event_registrar = null;
    }

    pub fn setThemeRegistrar(self: *PhantomPluginHost, registrar: ThemeRegistrar) void {
        self.theme_registrar = registrar;
    }

    pub fn clearThemeRegistrar(self: *PhantomPluginHost) void {
        self.theme_registrar = null;
    }

    pub fn setMessageSink(self: *PhantomPluginHost, sink: MessageSink) void {
        self.message_sink = sink;
    }

    pub fn clearMessageSink(self: *PhantomPluginHost) void {
        self.message_sink = null;
    }

    /// Build the callback table that grim runtime expects.
    pub fn callbacks(self: *PhantomPluginHost) Host.ActionCallbacks {
        return .{
            .ctx = @as(*anyopaque, @ptrCast(self)),
            .show_message = adapterShowMessage,
            .register_command = if (self.command_registrar != null) adapterRegisterCommand else null,
            .register_keymap = if (self.keymap_registrar != null) adapterRegisterKeymap else null,
            .register_event_handler = if (self.event_registrar != null) adapterRegisterEvent else null,
            .register_theme = if (self.theme_registrar != null) adapterRegisterTheme else null,
        };
    }

    fn adapterShowMessage(ctx: *anyopaque, message: []const u8) anyerror!void {
        const self = selfFromCtx(ctx);
        if (self.message_sink) |sink| {
            try sink.handlerFn(sink.ctx, message);
            return;
        }
        zlog.info("[plugin] {s}", .{message});
    }

    fn adapterRegisterCommand(ctx: *anyopaque, action: *const Host.CommandAction) anyerror!void {
        const self = selfFromCtx(ctx);
        if (self.command_registrar) |registrar| {
            try registrar.registerFn(registrar.ctx, action);
            return;
        }
        zlog.warn("Plugin attempted to register command without registrar: {s}", .{action.name});
    }

    fn adapterRegisterKeymap(ctx: *anyopaque, action: *const Host.KeymapAction) anyerror!void {
        const self = selfFromCtx(ctx);
        if (self.keymap_registrar) |registrar| {
            try registrar.registerFn(registrar.ctx, action);
            return;
        }
        zlog.warn("Plugin attempted to register keymap without registrar: {s}", .{action.keys});
    }

    fn adapterRegisterEvent(ctx: *anyopaque, action: *const Host.EventAction) anyerror!void {
        const self = selfFromCtx(ctx);
        if (self.event_registrar) |registrar| {
            try registrar.registerFn(registrar.ctx, action);
            return;
        }
        zlog.warn("Plugin attempted to register event handler without registrar: {s}", .{action.event});
    }

    fn adapterRegisterTheme(ctx: *anyopaque, action: *const Host.ThemeAction) anyerror!void {
        const self = selfFromCtx(ctx);
        if (self.theme_registrar) |registrar| {
            try registrar.registerFn(registrar.ctx, action);
            return;
        }
        zlog.warn("Plugin attempted to register theme entry without registrar: {s}", .{action.name});
    }

    fn selfFromCtx(ctx: *anyopaque) *PhantomPluginHost {
        const raw: *PhantomPluginHost = @ptrFromInt(@intFromPtr(ctx));
        return @alignCast(raw);
    }
};
