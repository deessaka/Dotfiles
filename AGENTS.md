# AGENTS.md

## Ubiquitous Language

Dev Environment & Tooling context — the set of developer tools, configs and workflows this repo manages.

- **Dev as life** — _Avoid_: "config", "setup", "dotfiles-only". The philosophy (from Takuya Matsuyama / craftzdog) that the developer environment must be battle-tested, production-validated and tuned for shipping real software; config time is minimized so coding time is maximized.
- **LazyVim** — _Avoid_: "a plugin", "a distribution". The opinionated Neovim distribution this repo extends as its base; it provides sane defaults, lazy-loading (crucial on a 4-core/11GB machine) and per-language extras.
- **Extras LazyVim** — _Avoid_: "plugins pour langage". Named feature bundles in LazyVim (e.g. `lang.go`, `lang.docker`, `dap.core`, `test.core`) that activate tooling for a language or capability on demand.
- **Fondation vs Personnalisation** — _Avoid_: "config from scratch". The split between what LazyVim provides by default (foundation) and what this repo adds/overrides (custom `lua/plugins/*`).
- **Stack polyvalente** — _Avoid_: "full-stack uniquement". The user's breadth: web (React/Vue/Svelte/Next.js/NestJS/AdonisJS), backend (Go), mobile (React Native/Flutter), DB (PostgreSQL in Docker), infrastructure (Docker/Compose). The config must not be opinionated toward one framework.
- **Écosystème terminal** — _Avoid_: "outils". The surrounding CLI layer that makes nvim productive: tmux, lazygit, git-delta, eza, zoxide, ghq, fzf — configured cohesively, not just installed.
- **IA - Complétion** — _Avoid_: "autocomplete". Inline code suggestion as you type (copilot.lua).
- **IA - Agent** — _Avoid_: "chatbot", "AI tool". Task-executing AI that edits files and runs commands (opencode via opencode.nvim) — injected with editor context (cursor, selection, buffer).
- **IA - Assistant** — _Avoid_: "chat GPT". Conversational AI with code editing capabilities in a dedicated nvim UI (avante.nvim), using Gemini via OAuth ACP.
- **Triade IA** — _Avoid_: "l'IA". The deliberate three-integration AI layout: Copilot (completion) + opencode.nvim (agent) + avante (assistant), each on a different keymap namespace, no overlap.
- **Débogage via adaptateurs** — _Avoid_: "debug". nvim-dap wired for Node/TS, Go (delve), Flutter and Browser/Chrome, each with its own adapter config.
- **Datasource conteneurisée** — _Avoid_: "la base de données", "psql". PostgreSQL always runs in a Docker container; local `psql` is intentionally not installed. DB access happens via vim-dadbod pointing at the container, and SQL files get LSP-based completion.
- **Gestion de projet (ghq)** — _Avoid_: "voir mes projets". Repository management under a single root (`~/ghq`) with `ghq list | fzf` for quick jumps, Takuya-style.
- **Config universelle portable** — _Avoid_: "mon PC". A versioned dotfiles repo (`~/dotfiles`, GNU stow symlinks) that can recreate the whole environment on any machine.
- **Identité git scindée** — _Avoid_: "une seule email git", "git global". Git identity is conditional by directory: personal by default (`ekoledev@gmail.com` + `github-personal` SSH key), work only under `~/workspace/ejara/**` (`deessaka.samuel@ejara.africa` + `github-work` key). The work email is NEVER the global default; the switch happens via `[includeIf "gitdir:~/workspace/ejara/"]` in `.gitconfig` → `.gitconfig-work`, and remote URLs are rewritten to the correct SSH host per context.