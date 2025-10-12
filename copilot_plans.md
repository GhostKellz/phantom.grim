# AI Integration Plans for Grim Ecosystem

## 🎯 Vision: Positioning Grim as the AI-First Editor

Grim + Phantom.grim will be positioned as the **modern, AI-native editor** with first-class support for:
- GitHub Copilot integration
- Claude Code workflows
- Multi-model AI assistance (OpenAI, Google, Anthropic)
- Agentic coding capabilities

---

## 📦 Phase 1: copilot.gza Plugin (Short-term)

**Goal:** Native GitHub Copilot integration directly in phantom.grim

### Features
- **Real-time completions** - Inline suggestions as you type
- **Multi-line completions** - Function/block suggestions
- **Context-aware** - Leverage buffer, LSP, and git context
- **Keybindings:**
  - `Tab` - Accept suggestion
  - `Ctrl+]` - Next suggestion
  - `Ctrl+[` - Previous suggestion
  - `Ctrl+\` - Dismiss
- **Statusline indicator** - Show Copilot status (active/disabled/rate limited)
- **Commands:**
  - `:CopilotEnable` / `:CopilotDisable`
  - `:CopilotSignIn` - GitHub OAuth flow
  - `:CopilotStatus` - Check connection

### Technical Implementation
```
plugins/ai/copilot.gza (planned ~500 lines)
├── GitHub Copilot API integration
├── LSP-style completion provider
├── Token management & caching
├── Rate limiting & error handling
└── Auth via GitHub device flow
```

**Dependencies:**
- HTTP client in Grim core (for GitHub API)
- OAuth device flow support
- Completion API integration with grim's LSP system

### Authentication Flow
1. User runs `:CopilotSignIn`
2. Display device code + URL
3. Poll GitHub until authorized
4. Store auth token securely
5. Initialize Copilot connection

---

## 🔥 Phase 2: reaper.grim Repository (Long-term Vision)

**Tagline:** *"Grim Reaper - You reap what you sow!"* 🪦⚡

### What is reaper.grim?

A **standalone AI coding agent** and **completion provider** for Grim that integrates:
- ✅ **GitHub Copilot** (via GitHub sign-in)
- ✅ **Claude Code workflows** (via Google/Anthropic sign-in)
- ✅ **OpenAI API** (GPT-4, GPT-3.5)
- ✅ **Google AI** (PaLM, Gemini via Google sign-in)
- ✅ **Agentic coding** (autonomous multi-step tasks)

**Reaper acts as a unified AI layer** that phantom.grim (and other Grim configs) can consume.

### Architecture

```
┌─────────────────────────────────────────┐
│         phantom.grim (or other)         │
│   ┌─────────────────────────────────┐   │
│   │  plugins/ai/reaper-client.gza   │   │ ← Ghostlang client
│   └────────────┬────────────────────┘   │
└────────────────┼────────────────────────┘
                 │ IPC/RPC
┌────────────────▼────────────────────────┐
│          reaper.grim (Zig daemon)       │
│  ┌──────────────────────────────────┐   │
│  │  Unified AI Provider Interface   │   │
│  ├──────────────────────────────────┤   │
│  │ ┌─────────┐ ┌─────────┐ ┌─────┐ │   │
│  │ │ Copilot │ │  Claude │ │ GPT │ │   │ ← Provider plugins
│  │ │ Provider│ │ Provider│ │ ... │ │   │
│  │ └─────────┘ └─────────┘ └─────┘ │   │
│  ├──────────────────────────────────┤   │
│  │    Auth Manager (multi-provider) │   │
│  │  - GitHub OAuth                  │   │
│  │  - Google Sign-In                │   │
│  │  - API Key Management            │   │
│  └──────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### reaper.grim Repository Structure

```
reaper.grim/
├── src/
│   ├── main.zig              # Daemon entry point
│   ├── rpc/
│   │   ├── server.zig        # RPC server for clients
│   │   └── protocol.zig      # Protocol definition
│   ├── providers/
│   │   ├── copilot.zig       # GitHub Copilot integration
│   │   ├── claude.zig        # Claude/Anthropic integration
│   │   ├── openai.zig        # OpenAI GPT integration
│   │   ├── google.zig        # Google AI integration
│   │   └── provider.zig      # Provider interface
│   ├── auth/
│   │   ├── github.zig        # GitHub OAuth
│   │   ├── google.zig        # Google Sign-In
│   │   └── token_store.zig   # Secure token storage
│   ├── completion/
│   │   ├── engine.zig        # Completion orchestration
│   │   ├── cache.zig         # Response caching
│   │   └── context.zig       # Context gathering
│   └── agent/
│       ├── planner.zig       # Agentic task planning
│       ├── executor.zig      # Multi-step execution
│       └── tools.zig         # Tool calling interface
├── plugins/grim/
│   └── reaper-client.gza     # Phantom.grim integration
├── build.zig
└── README.md
```

### Features

#### 1. Multi-Provider Completions
- **Automatic fallback:** If Copilot rate limits, fall back to GPT-4
- **Model selection:** User chooses preferred provider per-project
- **Cost tracking:** Track API usage and costs
- **Quality ranking:** Learn which provider works best for each language

#### 2. Unified Authentication
- **Single sign-on experience**
  - GitHub → Copilot access
  - Google → Claude, PaLM, Gemini
  - Direct API keys → OpenAI, Anthropic
- **Token refresh** - Automatic re-auth
- **Secure storage** - OS keychain integration

#### 3. Agentic Coding (zeke.grim-style)
- **Multi-step tasks**
  - "Refactor this module to use async/await"
  - "Add comprehensive tests for this file"
  - "Implement the TODO comments in this codebase"
- **Tool calling**
  - File operations (read, write, search)
  - LSP queries (go-to-def, references)
  - Git operations (commit, diff, blame)
- **Plan-execute-verify loop**
  - Generate plan
  - Execute steps
  - Verify with tests/LSP

#### 4. Context-Aware Suggestions
- **LSP integration** - Pull types, symbols, definitions
- **Git awareness** - Recent changes, blame, diffs
- **Project structure** - File tree, dependencies
- **Semantic search** - RAG over codebase for relevant context

---

## 🎨 Positioning: "Grim Reaper - You reap what you sow!"

### Brand Messaging

**Grim** is the **AI-first editor** for developers who want:
- ✅ **Speed** - Zig-native performance, instant startup
- ✅ **Intelligence** - Multi-model AI, agentic coding
- ✅ **Flexibility** - Ghostlang scripting, modular plugins
- ✅ **Modern UX** - LazyVim-inspired (via phantom.grim)

**Reaper** is the **AI brain** that makes Grim intelligent:
- 💀 *"You reap what you sow"* - Better context = better completions
- ⚡ *Multi-provider* - Never get rate-limited again
- 🧠 *Agentic* - It doesn't just suggest code, it writes features
- 🔒 *Privacy-first* - Local daemon, your tokens stay on your machine

### Target Audience

1. **AI-native developers** - Want Copilot+ on steroids
2. **Vim/Neovim refugees** - Want speed + modern AI
3. **Polyglot programmers** - Zig, Rust, Go, Ghostlang users
4. **Open-source enthusiasts** - Want hackable, transparent AI tools

### Differentiation

| Feature | **Grim + Reaper** | VS Code + Copilot | Cursor | Zed |
|---------|-------------------|-------------------|--------|-----|
| **Multi-provider AI** | ✅ Copilot, Claude, GPT, Google | ❌ Copilot only | ✅ GPT-4 only | ❌ |
| **Agentic coding** | ✅ Via reaper | ❌ | ✅ | ❌ |
| **Native performance** | ✅ Zig, <1s startup | ❌ Electron | ❌ Electron | ✅ Rust |
| **Vim motions** | ✅ Native | ⚠️ Extension | ⚠️ Extension | ⚠️ |
| **Scriptable** | ✅ Ghostlang | ⚠️ TypeScript | ❌ | ❌ |
| **Open-source core** | ✅ Grim + Reaper | ❌ | ❌ | ✅ |

---

## 🛣️ Roadmap

### Phase 1: Foundation (Q2 2025)
- ✅ Phantom.grim v1.0 (complete)
- 🚧 copilot.gza plugin (basic GitHub Copilot)
  - Auth flow
  - Inline completions
  - Statusline integration

### Phase 2: Reaper Prototype (Q3 2025)
- 🎯 reaper.grim repository setup
- 🎯 Zig daemon with RPC server
- 🎯 Copilot provider (migrate from copilot.gza)
- 🎯 Basic multi-provider support (Copilot + OpenAI)

### Phase 3: Multi-Provider (Q4 2025)
- 🎯 Claude/Anthropic integration
- 🎯 Google AI (PaLM, Gemini)
- 🎯 Unified auth UI
- 🎯 Model selection & fallback

### Phase 4: Agentic Coding (Q1 2026)
- 🎯 zeke.grim integration (see /data/projects/zeke)
- 🎯 Tool calling framework
- 🎯 Plan-execute-verify loop
- 🎯 Multi-step autonomous tasks

---

## 🔧 Implementation Details

### copilot.gza Technical Notes

**GitHub Copilot API Endpoints:**
```
POST https://api.github.com/copilot_internal/v2/token
POST https://copilot-proxy.githubusercontent.com/v1/engines/copilot-codex/completions
```

**Request Format:**
```json
{
  "prompt": "function fibonacci(n) {\n  ",
  "suffix": "\n}",
  "max_tokens": 500,
  "temperature": 0,
  "top_p": 1
}
```

**Grim Integration Points:**
- Hook into `on_text_changed` event
- Debounce requests (300ms)
- Show suggestions as virtual text
- Accept via Tab key (when at end of line)

### reaper.grim Communication Protocol

**RPC Methods (JSON-RPC 2.0):**
```typescript
// Request completion
completion/request {
  buffer: string,
  cursor: { line, col },
  prefix: string,
  suffix: string,
  language: string,
  provider?: "copilot" | "openai" | "claude" | "auto"
}

// Response
completion/response {
  id: string,
  text: string,
  provider: string,
  cached: boolean
}

// Agentic task
agent/execute {
  task: string,
  context: { files, symbols, git_status }
}
```

**IPC Transport:**
- Unix domain socket: `/tmp/reaper.sock`
- Or named pipe on Windows
- msgpack for serialization (faster than JSON)

---

## 📊 Success Metrics

**For copilot.gza:**
- [ ] <1s latency for completions
- [ ] >80% acceptance rate
- [ ] Works offline (cached suggestions)

**For reaper.grim:**
- [ ] Support 4+ AI providers
- [ ] <500ms provider switching
- [ ] <10MB memory overhead
- [ ] 1000+ concurrent editor connections

**For Grim ecosystem:**
- [ ] 10k+ GitHub stars by EOY 2025
- [ ] "Fastest AI-native editor" benchmarks
- [ ] Featured on HN, r/programming
- [ ] 100+ community plugins

---

## 🏗️ Ghost Ecosystem Integration

### Related Projects

reaper.grim integrates with the **Ghost Ecosystem**:

| Project | Purpose | Integration |
|---------|---------|-------------|
| **glyph** | Rust MCP server | Protocol layer for tool calling |
| **zRPC** | Zig RPC library | Fast local IPC (<1ms) |
| **zeke** | Agentic AI agent | Long-running tasks |
| **zeke.grim** | Zeke Grim plugin | Consumes reaper for completions |
| **omen** | Observability | Monitor reaper metrics |
| **rune** | Runtime layer | Orchestration |

### Provider Support

**reaper.grim is provider-agnostic:**

1. **Local Models (Ollama)**
   ```toml
   [providers.ollama]
   url = "http://localhost:11434"
   models = ["codellama:13b", "deepseek-coder:6.7b"]
   ```

2. **Custom Endpoints (Your GPU Server)**
   ```toml
   [providers.custom]
   endpoints = ["http://192.168.1.100:8080"]
   ```

3. **Cloud APIs**
   - OpenAI (GPT-4, GPT-3.5)
   - Anthropic (Claude 3 Opus/Sonnet)
   - Google (Gemini Pro)
   - GitHub Models (via GitHub sign-in)

4. **Protocol Flexibility**
   - **zRPC** for local (fastest, <1ms)
   - **MCP** via glyph (advanced context)
   - **HTTP** for cloud providers

### Architecture Decision

**Why reaper.grim is separate from zeke:**

```
zeke              = "Write this feature" (minutes, agentic)
reaper.grim       = "Complete this line" (<100ms, reactive)

zeke uses reaper  = For inline completions while planning
reaper uses glyph = For context via MCP
both use zRPC     = For fast local IPC
```

They're **complementary**, not competing.

---

## 💡 Open Questions

1. **Business model for reaper.grim?**
   - Open-source core + paid hosted version?
   - Or fully open-source (similar to coc.nvim)?

2. **Copilot ToS compliance?**
   - Ensure we're not violating GitHub's terms
   - May need to use official Copilot API when available

3. **Context size limits?**
   - How much code do we send to AI providers?
   - RAG/embeddings for large codebases?

4. **Rate limiting strategy?**
   - User-configurable limits per provider
   - Automatic backoff + fallback

5. **Privacy controls?**
   - Opt-out for sensitive repos?
   - On-prem deployment option?

6. **zRPC vs HTTP vs MCP?**
   - When to use each protocol?
   - Performance benchmarks needed

7. **glyph integration depth?**
   - How much context does reaper need from MCP?
   - Tool calling in completions?

---

## 🚀 Next Steps

### Immediate (This Week)
1. ✅ Document reaper.grim vision (this file!)
2. Create `copilot.gza` prototype in phantom.grim
3. Research GitHub Copilot API authentication
4. Spike: Zig HTTP client for Copilot API

### Short-term (Next Month)
1. Implement basic copilot.gza with inline completions
2. Create reaper.grim repository skeleton
3. Prototype RPC server in Zig
4. Design provider interface

### Long-term (Next Quarter)
1. Alpha release of reaper.grim
2. Multi-provider support
3. Integration with zeke.grim for agentic coding
4. Public beta + community feedback

---

**Last Updated:** 2025-10-12
**Status:** Planning Phase
**Owner:** Ghost Ecosystem Team
**Related Projects:** grim, phantom.grim, zeke.grim, ghostlang, reaper.grim
