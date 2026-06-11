<!--
  ghost-ai.nvim – Hyper-minimalist AI autocomplete for Neovim
  @author kadiryildiz
  @version 1.0.0
-->

<p align="center">
  <img src="https://raw.githubusercontent.com/neovim/neovim.github.io/master/logos/neovim-logo-300x87.png" width="120" />
</p>

<h1 align="center">👻 ghost-ai.nvim</h1>

<p align="center">
  <strong>Zero‑dependency · Pure‑logic · Asynchronous</strong><br />
  AI autocomplete (FIM) engine for Neovim – no UI freeze, no bloat.
</p>

<p align="center">
  <a href="https://github.com/kadiryildiz/ghost-ai.nvim/stargazers"><img src="https://img.shields.io/github/stars/kadiryildiz/ghost-ai.nvim?style=for-the-badge&logo=starship&color=yellow" alt="Stars" /></a>
  <a href="https://github.com/kadiryildiz/ghost-ai.nvim/issues"><img src="https://img.shields.io/github/issues/kadiryildiz/ghost-ai.nvim?style=for-the-badge&logo=gitbook&color=red" alt="Issues" /></a>
  <a href="https://github.com/kadiryildiz/ghost-ai.nvim/blob/main/LICENSE"><img src="https://img.shields.io/github/license/kadiryildiz/ghost-ai.nvim?style=for-the-badge&logo=opensourceinitiative&color=blue" alt="MIT License" /></a>
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

