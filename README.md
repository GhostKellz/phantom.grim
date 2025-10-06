# Phantom.grim

<div align="center">
  <img src="assets/icons/grim-phantom.png" alt="Phantom.grim logo" width="200" height="200">

**The Ultimate Grim Configuration Framework**
*LazyVim-inspired distro built from the ground up in Zig and Ghostlang for Grim editor*

![Built with Zig](https://img.shields.io/badge/Built%20with-Zig-yellow?logo=zig&style=for-the-badge)
![Ghostlang](https://img.shields.io/badge/Config-Ghostlang-7FFFD4?style=for-the-badge)
![Grim](https://img.shields.io/badge/Editor-Grim-gray?style=for-the-badge)
![Tree-sitter](https://img.shields.io/badge/Parser-TreeSitter-green?style=for-the-badge)
![LSP](https://img.shields.io/badge/Protocol-LSP-blue?style=for-the-badge)

[![License](https://img.shields.io/github/license/ghostkellz/phantom.grim?style=for-the-badge&color=ee999f)](LICENSE)
[![Stars](https://img.shields.io/github/stars/ghostkellz/phantom.grim?style=for-the-badge&color=c69ff5)](https://github.com/ghostkellz/phantom.grim/stargazers)
[![Issues](https://img.shields.io/github/issues/ghostkellz/phantom.grim?style=for-the-badge&color=F5E0DC)](https://github.com/ghostkellz/phantom.grim/issues)

</div>

---

## 🌟 Overview

**Phantom.grim** is to **Grim** what **LazyVim** is to **Neovim** — a fully-featured, batteries-included configuration framework that transforms Grim into a modern, powerful IDE experience.

Built entirely in **Zig** (core performance) and **Ghostlang** (configuration), Phantom.grim provides:

- 🚀 **Instant Productivity** - Works out-of-the-box, tweak as you learn
- ⚡ **Blazing Fast** - Native Zig performance, zero overhead
- 🔌 **Modular Plugin System** - Enable/disable features à la carte
- 🎨 **Beautiful UI** - Modern aesthetics with Phantom TUI framework
- 🧠 **LSP Intelligence** - Full LSP support via Ghostls, ZLS, rust-analyzer
- 🌲 **Tree-sitter Powered** - Syntax highlighting for 14+ languages via Grove
- 📦 **Pre-configured Plugins** - File explorer, fuzzy finder, git integration, and more
- 🛠️ **Extensible** - Write your own plugins in Ghostlang

---

## ✨ Features

### 🎯 **Core Functionality**

| Feature | Status | Description |
|---------|--------|-------------|
| 📝 Modal Editing | ✅ | Full Vim motions + modern keybindings |
| 🌳 File Tree | ✅ | Neo-tree inspired sidebar navigation |
| 🔍 Fuzzy Finder | ✅ | Telescope-like file/buffer/grep search |
| 🧩 LSP Integration | ✅ | Auto-completion, hover, go-to-definition |
| 🎨 Syntax Highlighting | ✅ | Tree-sitter powered (14 languages) |
| 🔧 Git Integration | ✅ | Git signs, blame, diff view |
| 📊 Status Line | ✅ | Informative status bar with LSP/Git status |
| 🎯 Diagnostics | ✅ | Real-time error/warning display |
| 🔖 Buffer Management | ✅ | Tab-like buffer navigation |
| 🧪 DAP Support | 🚧 | Debug Adapter Protocol (coming soon) |

### 🎨 **UI Components**

- **Dashboard** - Custom greeter with recent files, projects
- **Which-Key** - Keybinding popup hints
- **Notifications** - Toast-style non-intrusive messages
- **Command Palette** - VSCode-like command search
- **Quickfix List** - Search results, diagnostics, TODOs

### 📦 **Included Plugins**

All plugins written in **Ghostlang** (.gza):

```
phantom.grim/
├── plugins/
│   ├── file-tree.gza        # File explorer sidebar
│   ├── fuzzy-finder.gza     # Telescope-style fuzzy search
│   ├── git-signs.gza        # Git change indicators
│   ├── autopairs.gza        # Auto-close brackets/quotes
│   ├── comment.gza          # Smart commenting (gcc, gbc)
│   ├── surround.gza         # Surround text objects
│   ├── which-key.gza        # Keybinding hints
│   ├── dashboard.gza        # Startup greeter
│   ├── lsp-config.gza       # LSP auto-configuration
│   ├── treesitter.gza       # Tree-sitter setup
│   ├── statusline.gza       # Custom status line
│   ├── tabline.gza          # Buffer tabs
│   └── theme.gza            # Theme manager
```

---

## 🚀 Installation

### Prerequisites

- **Grim** >= 0.1.0 ([Install Guide](https://github.com/ghostkellz/grim))
- **Zig** >= 0.16.0-dev
- **Git** >= 2.19.0
- **Nerd Font** (optional, for icons)

### Quick Install

```bash
# 1. Backup existing Grim config (if any)
mv ~/.config/grim ~/.config/grim.backup

# 2. Clone Phantom.grim
git clone https://github.com/ghostkellz/phantom.grim.git ~/.config/grim

# 3. Launch Grim
grim

# Phantom will auto-install on first launch!
```

### From Scratch

```bash
# Clone to custom location
git clone https://github.com/ghostkellz/phantom.grim.git ~/phantom-grim

# Symlink to Grim config
ln -s ~/phantom-grim ~/.config/grim

# Launch
grim
```

---

## ⚙️ Configuration

### File Structure

```
~/.config/grim/
├── init.gza                 # Main entry point
├── config/
│   ├── options.gza          # Editor options
│   ├── keymaps.gza          # Keybindings
│   ├── autocmds.gza         # Auto-commands
│   └── lsp.gza              # LSP server configs
├── plugins/
│   ├── core/                # Essential plugins (always loaded)
│   ├── editor/              # Editor enhancements
│   ├── ui/                  # UI plugins
│   ├── coding/              # Coding tools (LSP, completion)
│   └── extras/              # Optional plugins
├── themes/
│   ├── gruvbox.gza
│   ├── tokyonight.gza
│   └── catppuccin.gza
└── lua/                     # User customizations
    └── user/
        ├── plugins.gza      # Add your own plugins here
        └── config.gza       # Override defaults
```

### Basic Customization

Edit `~/.config/grim/lua/user/config.gza`:

```ghostlang
-- User Configuration for Phantom.grim

-- Override theme
phantom.theme = "tokyonight"

-- Disable plugins you don't want
phantom.plugins.disable({
    "dashboard",     -- No startup screen
    "which-key",     -- No keybinding hints
})

-- Add custom keybindings
register_keymap("n", "<leader>xx", ":TodoList<CR>", { desc = "Show TODOs" })

-- LSP servers to auto-install
phantom.lsp.servers = {
    "ghostls",       -- Ghostlang
    "zls",           -- Zig
    "rust_analyzer", -- Rust
    "ts_ls",         -- TypeScript
    "pyright",       -- Python
}

-- Custom options
set_option("relative_line_numbers", true)
set_option("tab_width", 2)
```

---

## 🎮 Default Keybindings

### Leader Key: `<Space>`

#### File Operations
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>w` | `:write` | Save file |
| `<leader>q` | `:quit` | Quit |
| `<leader>e` | Toggle file tree | Open/close sidebar |

#### Fuzzy Finder
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>ff` | Find files | Search project files |
| `<leader>fg` | Live grep | Search in files |
| `<leader>fb` | Find buffers | Switch buffers |
| `<leader>fh` | Help tags | Search help docs |

#### LSP
| Key | Action | Description |
|-----|--------|-------------|
| `gd` | Go to definition | Jump to definition |
| `gD` | Go to declaration | Jump to declaration |
| `gr` | References | Find references |
| `K` | Hover | Show documentation |
| `<leader>ca` | Code action | Quick fixes |
| `<leader>rn` | Rename | Rename symbol |
| `[d` | Previous diagnostic | Jump to prev error |
| `]d` | Next diagnostic | Jump to next error |

#### Git
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>gs` | Git status | Show git status |
| `<leader>gc` | Git commit | Commit changes |
| `<leader>gp` | Git push | Push to remote |
| `<leader>gb` | Git blame | Show blame |

#### Buffers/Tabs
| Key | Action | Description |
|-----|--------|-------------|
| `<leader>bn` | Next buffer | Switch to next |
| `<leader>bp` | Previous buffer | Switch to previous |
| `<leader>bd` | Delete buffer | Close current |
| `<S-h>` | Previous tab | Move left |
| `<S-l>` | Next tab | Move right |

---

## 🎨 Themes

Phantom.grim comes with these themes:

- **Gruvbox** (default) - Retro groove colors
- **Tokyo Night** - Modern dark theme
- **Catppuccin** - Pastel colors
- **Dracula** - Classic Dracula theme
- **Nord** - Arctic-inspired palette
- **One Dark** - Atom-inspired

**Switch themes:**

```ghostlang
-- In ~/.config/grim/lua/user/config.gza
phantom.theme = "tokyonight"
```

---

## 🔌 Plugin Management

### Enable/Disable Plugins

```ghostlang
-- Disable specific plugins
phantom.plugins.disable({ "dashboard", "autopairs" })

-- Enable experimental plugins
phantom.plugins.enable({ "dap", "multicursor" })
```

### Add Your Own Plugins

Create `~/.config/grim/lua/user/plugins.gza`:

```ghostlang
-- Custom plugin example
return {
    {
        name = "my-plugin",
        file = "~/.config/grim/plugins/custom/my-plugin.gza",
        config = function()
            -- Plugin setup
        end
    }
}
```

---

## 🧰 LSP Configuration

Phantom.grim auto-configures LSP servers. Supported out-of-the-box:

### Included LSP Servers

| Language | Server | Auto-configured |
|----------|--------|----------------|
| Ghostlang | ghostls | ✅ |
| Zig | zls | ✅ |
| Rust | rust-analyzer | ✅ |
| TypeScript | ts_ls | ✅ |
| Python | pyright | ✅ |
| Go | gopls | ✅ |
| C/C++ | clangd | ✅ |
| Lua | lua_ls | ✅ |

### Custom LSP Setup

```ghostlang
-- In config/lsp.gza
local lsp = require("phantom.lsp")

lsp.setup("my_language_server", {
    cmd = { "my-ls", "--stdio" },
    filetypes = { "mylang" },
    root_patterns = { ".git", "mylang.toml" },
    settings = {
        mylang = {
            diagnostics = true
        }
    }
})
```

---

## 🌲 Tree-sitter Support

Powered by **Grove** (Zig tree-sitter bindings), Phantom.grim supports:

- Zig, Rust, Go
- JavaScript, TypeScript, TSX
- Python, Bash, C, C++
- JSON, TOML, YAML, Markdown
- HTML, CSS, CMake
- **Ghostlang** (full semantic support)

---

## 📚 Documentation

- **[Getting Started](docs/getting-started.md)** - First steps with Phantom.grim
- **[Configuration Guide](docs/configuration.md)** - Customize everything
- **[Plugin Development](docs/plugins.md)** - Write your own plugins
- **[Keybindings](docs/keybindings.md)** - Full keymap reference
- **[LSP Setup](docs/lsp.md)** - Language server configuration
- **[Theming](docs/themes.md)** - Create custom themes

---

## 🤝 Contributing

Contributions welcome! Phantom.grim is built for the community.

### Ways to Contribute

- 🐛 Report bugs
- 💡 Suggest features
- 🔌 Create plugins
- 🎨 Design themes
- 📝 Improve documentation
- ⭐ Star the repo!

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

---

## 🛣️ Roadmap

- [ ] **v0.1.0** - Initial release (core plugins)
- [ ] **v0.2.0** - DAP debugging support
- [ ] **v0.3.0** - Multi-cursor editing
- [ ] **v0.4.0** - Remote development (SSH/containers)
- [ ] **v0.5.0** - AI integration (Zeke.grim)
- [ ] **v1.0.0** - Production ready

---

## 🎓 Philosophy

### Why Phantom.grim?

**Kickstart.grim** is great for learning, but most users want:
- ✅ Plugins that "just work"
- ✅ Sensible defaults
- ✅ Modern IDE features
- ✅ Less configuration, more coding

**Phantom.grim** delivers all this while staying:
- 🪶 **Lightweight** - Native Zig performance
- 🔧 **Configurable** - Tweak anything in Ghostlang
- 📖 **Transparent** - Read and understand the code
- 🚀 **Fast** - No plugin manager overhead

### LazyVim vs Phantom.grim

| Feature | LazyVim (Neovim) | Phantom.grim |
|---------|------------------|--------------|
| Language | Lua | **Ghostlang** (.gza) |
| Editor | Neovim | **Grim** |
| Performance | Fast | **Blazing** (Zig) |
| Plugin Manager | lazy.nvim | **Native** (Zig) |
| LSP | nvim-lspconfig | **ghostls/ZLS** |
| Tree-sitter | nvim-treesitter | **Grove** |
| Config Style | Modular Lua | **Modular Ghostlang** |

---

## 🙏 Credits

Phantom.grim is inspired by:
- **[LazyVim](https://github.com/LazyVim/LazyVim)** - The best Neovim distro
- **[Kickstart.nvim](https://github.com/nvim-lua/kickstart.nvim)** - Educational config
- **[AstroNvim](https://github.com/AstroNvim/AstroNvim)** - Beautiful UI
- **[LunarVim](https://github.com/LunarVim/LunarVim)** - IDE-like experience

Built with:
- **[Grim](https://github.com/ghostkellz/grim)** - The editor
- **[Ghostlang](https://github.com/ghostkellz/ghostlang)** - Config language
- **[Grove](https://github.com/ghostkellz/grove)** - Tree-sitter integration
- **[Ghostls](https://github.com/ghostkellz/ghostls)** - LSP server
- **[Phantom](https://github.com/ghostkellz/phantom)** - TUI framework

---

## 📄 License

MIT License - See [LICENSE](LICENSE) for details.

---

<div align="center">

**Made with 👻 by the Ghost Ecosystem**

[Grim](https://github.com/ghostkellz/grim) •
[Ghostlang](https://github.com/ghostkellz/ghostlang) •
[Grove](https://github.com/ghostkellz/grove) •
[Ghostls](https://github.com/ghostkellz/ghostls)

⭐ **Star us on GitHub!** ⭐

</div>
