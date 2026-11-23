# dotfiles — config "dev as life"

Environnement de dev complet façon Takuya Matsuyama (craftzdog), pour un développeur
full-stack polyvalent : web (React/Vue/Svelte/Next/Nest/Adonis), backend (Go), mobile
(React Native/Flutter), PostgreSQL en Docker, Docker/Compose.

## Contenu

| Dossier   | Rôle                                                        |
| --------- | ----------------------------------------------------------- |
| `nvim/`   | Config Neovim (LazyVim + IA + DAP + dadbod + tests)         |
| `tmux/`   | `.tmux.conf` true color + undercurl + vi keys               |
| `git/`    | `.gitconfig` (delta, alias) + identités pro/perso           |
| `zsh/`    | Aliases modernes (eza, zoxide, ghq, docker, git…)           |
| `docs/`   | ADRs (décisions d'architecture de la config)                |

## Installation

```bash
git clone <ce-repo> ~/dotfiles
cd ~/dotfiles
./install.sh          # outils apt + Go tools + police + stow + nvim
```

Reinstaller seulement la config (outils déjà présents) :

```bash
cd ~/dotfiles
./install.sh --no-tools
```

## Raccourcis IA (duo)

| Touche        | Outil          | Rôle                              |
| ------------- | -------------- | --------------------------------- |
| `<leader>ai`  | opencode.nvim  | Agent (menu) — contexte éditeur   |
| `<leader>aq`  | opencode.nvim  | Agent (ask) sur la sélection      |
| `go` / `goo`  | opencode.nvim  | Agent (opérateur) sur une motion  |
| `<M-l>`       | copilot.lua    | Accepter suggestion inline        |

## Identités Git

- **Perso** (défaut) : `ekodev <ekoledev@gmail.com>` + clé `github-personal`
- **Pro** (`~/workspace/ejara/**`) : `ekodev <deessaka.samuel@ejara.africa>` + clé `github-work`

## Docs

- `AGENTS.md` — vocabulaire partagé (Ubiquitous Language)
- `docs/adr/` — ADRs : LazyVim, duo IA, Postgres Docker, dotfiles, nvim stable, Go, identité git
