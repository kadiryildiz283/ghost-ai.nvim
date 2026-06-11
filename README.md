Kadir. Kimlik düzeltmesi rasyonel bir detaydır. Kurulum (Installation) aşamasındaki bağlantıların veya GitHub rozetlerinin (shields) yanlış bir kullanıcı adına gitmesi projenin itibarını zedeler ve ölü bağlantılar (404) yaratır.

Yarım kalan README.md dosyasını tamamlayarak, sisteminde kullandığın LunarVim entegrasyon detaylarını da içeren nihai, "Production-Ready" metni aşağıda sunuyorum.

Bunu doğrudan projenin ana dizinindeki `README.md` dosyasına yapıştır.

```markdown
<p align="center">
  <img src="https://raw.githubusercontent.com/neovim/neovim.github.io/master/logos/neovim-logo-300x87.png" width="120" />
</p>

<h1 align="center">👻 ghost-ai.nvim</h1>

<p align="center">
  <strong>Zero‑dependency · Pure‑logic · Asynchronous</strong><br />
  AI autocomplete (FIM) engine for Neovim – no UI freeze, no bloat.
</p>

<p align="center">
  <a href="https://github.com/kadiryildiz283/ghost-ai.nvim/stargazers"><img src="https://img.shields.io/github/stars/kadiryildiz283/ghost-ai.nvim?style=for-the-badge&logo=starship&color=yellow" alt="Stars" /></a>
  <a href="https://github.com/kadiryildiz283/ghost-ai.nvim/issues"><img src="https://img.shields.io/github/issues/kadiryildiz283/ghost-ai.nvim?style=for-the-badge&logo=gitbook&color=red" alt="Issues" /></a>
  <a href="https://github.com/kadiryildiz283/ghost-ai.nvim/blob/main/LICENSE"><img src="https://img.shields.io/github/license/kadiryildiz283/ghost-ai.nvim?style=for-the-badge&logo=opensourceinitiative&color=blue" alt="MIT License" /></a>
  <br />
  <a href="https://neovim.io/"><img src="https://img.shields.io/badge/Neovim-0.9%2B-57A143?style=for-the-badge&logo=neovim&logoColor=white" alt="Neovim 0.9+" /></a>
  <a href="#"><img src="https://img.shields.io/badge/Lua-5.1-blue?style=for-the-badge&logo=lua&logoColor=white" alt="Lua" /></a>
  <a href="https://ollama.com/"><img src="https://img.shields.io/badge/Ollama-Ready-000000?style=for-the-badge&logo=ollama&logoColor=white" alt="Ollama" /></a>
  <a href="https://www.minimaxi.com/"><img src="https://img.shields.io/badge/MiniMax-Cloud-FF6B6B?style=for-the-badge&logo=ai&logoColor=white" alt="MiniMax" /></a>
</p>

---

## 🧠 Why ghost-ai.nvim?

Most Neovim AI plugins suffer from **over‑engineering**. `ghost-ai.nvim` is built on **Pragmatic Perfectionism**:

| Feature | Typical plugins | `ghost-ai.nvim` |
|---------|----------------|------------------|
| Dependencies | plenary.nvim, UI libs, parsers | **Zero** – only `vim.api` + `curl` |
| UI complexity | Floating windows, signatures, spinners | **Zero** – just ghost text |
| Overlap handling | None → model repeats your prefix | **Smart overlap detector** – slices duplicates cleanly |
| Context awareness | Only cursor line | **File Objective** – reads top 15 lines (JSON schemas, rules) |
| Provider flexibility | Locked to one backend | **Dual‑provider** – Ollama (local) / MiniMax (cloud) |

> 🎯 **Result:** Lightning‑fast, non‑blocking suggestions that feel native to Neovim.

---

## ✨ Core Features

- 👻 **Ghost text rendering** – Inline virtual text, disappears on cursor move or Insert mode entry.
- 🧩 **Smart overlap slicing** – When a local LLM repeats `std::co` → only appends `ut` instead of `std::cout`.
- 📄 **File Objective Awareness** – Reads header/shebang/schema from the top of the file to reduce hallucinations.
- ⚡ **Asynchronous & non‑blocking** – Uses Neovim's job control, zero UI freezing.
- 🔌 **Dual provider** – Switch between Ollama (offline, free) and MiniMax (high‑performance cloud) with one line.
- 🔐 **Secure** – API keys read from `os.getenv()` – never hardcoded.
- 🧹 **Auto‑clear** – Ghost text vanishes when you move or start typing.

---

## 📦 Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim) (recommended)

```lua
{
    "kadiryildiz283/ghost-ai.nvim",
    config = function()
        require("ghost_ai").setup()
    end,
}

```

### [LunarVim](https://www.lunarvim.org/)

Add this to your `~/.config/lvim/config.lua`:

```lua
lvim.plugins = {
    {
        "kadiryildiz283/ghost-ai.nvim",
        config = function()
            require("ghost_ai").setup()
        end,
    }
}

```

---

## ⚙️ Configuration

The plugin works out of the box with MiniMax (default) or Ollama. You can override the default settings by modifying the `config` table before calling `setup()`.

```lua
local ghost = require("ghost_ai")

ghost.config = {
    active_provider = "minimax", -- Choose "minimax" or "ollama"
    
    providers = {
        ollama = {
            url = "http://localhost:11434/api/generate",
            model = "qwen2.5-coder:1.5b"
        },
        minimax = {
            url = "[https://api.minimax.io/v1/text/chatcompletion_v2](https://api.minimax.io/v1/text/chatcompletion_v2)",
            model = "MiniMax-M2.7",
            -- Reads from environment to avoid hardcoding credentials
            api_key = os.getenv("MINIMAX_API_KEY") 
        }
    }
}

ghost.setup()

```

### 🔒 Security Note for MiniMax

Never hardcode your API key. Export it in your shell configuration (`.bashrc` or `.zshrc`):

```bash
export MINIMAX_API_KEY="your_api_key_here"

```

---

## 🚀 Keymaps

| Mode | Key | Action |
| --- | --- | --- |
| Normal | `<M-q>` (Alt + Q) | Request AI Autocomplete |
| Normal | `<Tab>` | Accept the Ghost Text Suggestion |

*(Ghost text is automatically cleared when you move the cursor or switch to Insert mode, keeping your workspace clean.)*

---

## 📜 License

MIT License © 2026 Kadir Yıldız

```

```
