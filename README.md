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
| `team/`   | Workflow de mission indépendant des CLI d'agents           |

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

## Team — missions multi-CLI

Team est le protocole de travail commun à Codex, Claude Code, OpenCode et
GitHub Copilot CLI. Les missions restent dans `.team/` à la racine du checkout ;
le panneau Neovim et les CLI lisent le même état. Les sous-agents, permissions
et intégrations restent natifs à chaque outil.

Après le contrôle sans écriture, installe le CLI, la skill partagée et les profils :

```bash
./scripts/install-team.sh --check
./scripts/install-team.sh
```

L'installateur ajoute `team`, la skill partagée et des profils spécialistes
natifs aux emplacements utilisateur documentés. Il refuse toute collision et ne
modifie ni permissions ni authentification. Il ajoute ou actualise uniquement
les blocs Team marqués dans les fichiers d'instructions globaux des quatre CLI,
en conservant le reste du contenu et le mode des fichiers. Si les marqueurs
sont incohérents ou un emplacement existe déjà avec un contenu différent, le
script s'arrête sans l'écraser. Les variables `CODEX_HOME`,
`CLAUDE_CONFIG_DIR`, `XDG_CONFIG_HOME` et `COPILOT_HOME` sont respectées.

Dans le CLI choisi, demande l’utilisation de la skill `team` pour une mission substantielle. Le
contrat complet est installé dans `~/.local/share/team/WORKFLOW.md`. Consulte
`docs/team/provider-compatibility.md` et ADR-0008 pour les différences natives,
les limites et les sources officielles.

## Identités Git

- **Perso** (défaut) : `ekodev <ekoledev@gmail.com>` + clé `github-personal`
- **Pro** (`~/workspace/ejara/**`) : `ekodev <deessaka.samuel@ejara.africa>` + clé `github-work`

## Docs

- `AGENTS.md` — vocabulaire partagé (Ubiquitous Language)
- `docs/adr/` — ADRs : LazyVim, duo IA, Postgres Docker, dotfiles, nvim stable, Go, identité git
