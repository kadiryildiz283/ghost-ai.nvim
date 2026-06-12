# ghost-ai.nvim
<h1 align="center">👻 ghost-ai.nvim</h1>

<p align="center">
  <strong>Zero Dependency • Pure Logic • Asynchronous AI Completion</strong>
</p>

<p align="center">
  Lightweight AI autocomplete for Neovim with ghost-text rendering, smart overlap detection and dual-provider support (Ollama + MiniMax).
</p>

<p align="center">
  <a href="https://github.com/kadiryildiz283/ghost-ai.nvim/stargazers">
    <img src="https://img.shields.io/github/stars/kadiryildiz283/ghost-ai.nvim?style=for-the-badge&logo=starship&color=yellow" />
  </a>
  <a href="https://github.com/kadiryildiz283/ghost-ai.nvim/issues">
    <img src="https://img.shields.io/github/issues/kadiryildiz283/ghost-ai.nvim?style=for-the-badge&logo=gitbook&color=red" />
  </a>
  <a href="https://github.com/kadiryildiz283/ghost-ai.nvim/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/kadiryildiz283/ghost-ai.nvim?style=for-the-badge&logo=opensourceinitiative&color=blue" />
  </a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Neovim-0.9+-57A143?style=for-the-badge&logo=neovim&logoColor=white" />
  <img src="https://img.shields.io/badge/Lua-5.1-blue?style=for-the-badge&logo=lua&logoColor=white" />
  <img src="https://img.shields.io/badge/Ollama-Ready-black?style=for-the-badge" />
  <img src="https://img.shields.io/badge/MiniMax-Cloud-FF6B6B?style=for-the-badge" />
</p>

---

# ghost-ai.nvim

---

## Overview

`ghost-ai.nvim` is a lightweight AI completion engine built specifically for developers who want intelligent code suggestions without sacrificing Neovim's speed.

Unlike many AI plugins that depend on large UI frameworks, external helper libraries, or complex completion stacks, `ghost-ai.nvim` focuses on a single goal:

> Deliver fast, context-aware inline AI completions and smart file templates with minimal overhead.

The plugin uses native Neovim APIs, asynchronous jobs, and ghost-text rendering to provide a smooth coding experience without blocking the editor.

---

## Why ghost-ai.nvim?

| Feature | Typical AI Plugins | ghost-ai.nvim |
| --- | --- | --- |
| Dependencies | Multiple | Zero |
| UI Frameworks | Floating windows, popups | None |
| Async Requests | Mixed | Fully async |
| Local Models | Sometimes | Native Ollama |
| Cloud Models | Limited | MiniMax |
| Auto Templating | Rare / Prompt-based | Background on File Save |
| Prefix Overlap Handling | Basic | Smart slicing |
| Context Awareness | Cursor only | File objective analysis |
| Startup Cost | Higher | Minimal |

### Design Philosophy

The plugin follows three principles:

* **Minimalism** – no unnecessary abstractions.
* **Performance** – non-blocking by default.
* **Transparency** – simple Lua codebase that is easy to audit and extend.

---

## Features

### 📝 Auto File Template Generation

Start a new file, write a comment on the first line explaining what you want to build, and save the file (`:w`). `ghost-ai.nvim` will automatically generate a tailored blueprint for you in the background.

* **Smart Heuristics:** Only triggers on new or nearly empty files (less than 5 lines of code). It knows not to mess with an already established codebase.
* **Loop Prevention:** Checks for the `=== Ghost AI Helper Templates ===` marker. It will not endlessly request generations on repeated saves. If you delete the generated template block and save again, it will regenerate a fresh one.
* **Universal Language Support:** Dynamically reads Neovim's native `vim.bo.commentstring` to automatically use the correct comment syntax (e.g., `--` for Lua, `#` for Python, `//` for C++, `` for HTML). The output is strictly wrapped in comments (max 50 lines) so your file remains perfectly runnable and error-free.

---

### 👻 Ghost Text Rendering

Suggestions appear as inline virtual text directly inside your buffer.

No popups.
No completion windows.
No visual clutter.

---

### 🧩 Smart Overlap Detection

Many local models repeat already typed text.

Example:

Typed:

```cpp
std::co

```

Model returns:

```cpp
std::cout << value;

```

ghost-ai.nvim automatically transforms it into:

```cpp
ut << value;

```

Only the missing portion is inserted.

---

### 📄 File Objective Awareness

The plugin analyzes the beginning of the current file to understand its purpose.

Examples:

* JSON schemas
* Lua module headers
* Python shebangs
* Configuration files
* Documentation blocks

This additional context helps reduce irrelevant completions.

---

### ⚡ Fully Asynchronous

Requests are executed using Neovim job control.

The editor never waits for the AI response.

No UI freezing.
No blocking calls.

---

### 🔌 Dual Provider Support

Switch providers with a single configuration option.

#### Ollama

* Local
* Offline
* Free
* Privacy friendly

#### MiniMax

* Cloud hosted
* Faster reasoning
* Larger models
* Better completion quality

---

### 🔐 Secure Credential Handling

API keys are loaded from environment variables.

No secrets are stored inside configuration files.

---

## Architecture

```text
Buffer
   │
   ├──► [On Save / BufWritePost] ──► Auto Template Generator (Checks Heuristics & Marker)
   │
   ▼
Context Builder
   │
   ▼
Prompt Generator
   │
   ├── Ollama
   │
   └── MiniMax
           │
           ▼
Completion Response
           │
           ▼
Overlap Detector
           │
           ▼
Ghost Text Renderer

```

---

## Installation

### lazy.nvim

```lua
{
    "kadiryildiz283/ghost-ai.nvim",
    config = function()
        require("ghost_ai").setup()
    end,
}

```

---

### LunarVim

Add the plugin to:

```lua
~/.config/lvim/config.lua

```

```lua
lvim.plugins = {
    {
        "kadiryildiz283/ghost-ai.nvim",
        config = function()
            require("ghost_ai").setup()
        end,
    },
}

```

Reload LunarVim:

```vim
:LvimSyncCorePlugins

```

or

```vim
:PackerSync

```

depending on your LunarVim version.

---

## Configuration

Default configuration:

```lua
local ghost = require("ghost_ai")

ghost.config = {
    active_provider = "minimax",

    providers = {
        ollama = {
            url = "http://localhost:11434/api/generate",
            model = "qwen2.5-coder:1.5b",
        },

        minimax = {
            url = "https://api.minimax.io/v1/text/chatcompletion_v2",
            model = "MiniMax-M2.7",
            api_key = os.getenv("MINIMAX_API_KEY"),
        },
    },
}

ghost.setup()

```

---

## MiniMax Setup

Export your API key:

### Bash

```bash
export MINIMAX_API_KEY="your_api_key_here"

```

### Zsh

```bash
echo 'export MINIMAX_API_KEY="your_api_key_here"' >> ~/.zshrc
source ~/.zshrc

```

---

## Ollama Setup

Install and run Ollama:

```bash
ollama pull qwen2.5-coder:1.5b
ollama serve

```

Verify:

```bash
curl http://localhost:11434/api/tags

```

---

## Keymaps & Triggers

| Mode | Action | Description |
| --- | --- | --- |
| Normal | `<M-q>` | Generate inline AI code completion |
| Normal | `<Tab>` | Accept ghost text suggestion |
| Any | Cursor Move | Clear current ghost text |
| Insert | Typing | Refresh completion context |
| Event | `:w` | Trigger auto-template generation (only on files with <5 lines of code) |

---

## Performance Goals

* Zero external runtime dependencies
* Minimal memory footprint
* Non-blocking networking
* Fast suggestion rendering
* Clean Lua implementation

---

## Roadmap

### v1.1

* [ ] Debounce requests
* [ ] Streaming completions
* [ ] Better prompt templates

### v1.2

* [ ] Multi-file context
* [ ] Project-aware prompts
* [ ] Provider abstraction API

### v2.0

* [ ] Custom providers
* [ ] FIM prompt presets
* [ ] Advanced context ranking

---

## Contributing

Contributions, bug reports and feature requests are welcome.

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Open a Pull Request

---

## License

MIT License © 2026 Kadir Yıldız

---
