#!/usr/bin/env bash
# =============================================================================
# install.sh — bootstrap complet de la config "dev as life" (ce repo).
# Idempotent : peut être relancé sans risque. Utilise sudo pour apt.
#
# Usage :  ./install.sh            # installe outils + police + stow + nvim
#          ./install.sh --no-tools # saute l'installation des outils (déjà là)
# =============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export PATH="$PATH:$HOME/go/bin:$HOME/.local/bin"

INSTALL_TOOLS=1
[[ "${1:-}" == "--no-tools" ]] && INSTALL_TOOLS=0

log()  { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
ok()   { printf "\033[1;32m   ✓ %s\033[0m\n" "$*"; }
info() { printf "\033[2m   · %s\033[0m\n" "$*"; }

if [[ "$INSTALL_TOOLS" -eq 1 ]]; then
  log "1/5 Installation des paquets système (apt)"
  sudo apt update
  sudo apt install -y \
    neovim tmux lazygit git-delta stow \
    ripgrep fd-find fzf golang-go \
    curl unzip fontconfig git

  log "2/5 Outils Go (gopls, delve, sqls, golangci-lint)"
  go install golang.org/x/tools/gopls@latest
  go install github.com/go-delve/delve/cmd/dlv@latest
  go install github.com/sqls-server/sqls@latest
  go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest
  ok "Go tools installés dans ~/go/bin"
  info "Assure-toi que ~/.zshrc contient : export PATH=\$PATH:\$HOME/go/bin"
fi

log "3/5 Police BlexMono Nerd Font"
if fc-list 2>/dev/null | grep -qi "BlexMono"; then
  ok "BlexMono déjà installée"
else
  mkdir -p ~/.local/share/fonts
  tmp="$(mktemp -d)"
  curl -fLo "$tmp/IBMPlexMono.zip" \
    https://github.com/ryanoasis/nerd-fonts/releases/latest/download/IBMPlexMono.zip
  unzip -oq "$tmp/IBMPlexMono.zip" -d ~/.local/share/fonts
  rm -rf "$tmp"
  fc-cache -f >/dev/null 2>&1
  ok "BlexMono Nerd Font installée (configurer Kitty : Ctrl+Shift+F2 → fonts)"
fi

log "4/5 Déploiement des symlinks (GNU stow)"
cd "$DOTFILES_DIR"
stow -v nvim tmux git
if [[ ! -e ~/.zsh_modern ]]; then
  ln -s "$DOTFILES_DIR/zsh/.zsh_modern" ~/.zsh_modern
fi
grep -q "zsh_modern" ~/.zshrc 2>/dev/null \
  || echo '[ -f ~/.zsh_modern ] && source ~/.zsh_modern' >> ~/.zshrc
ok "Config déployée"

log "5/5 Premier lancement Neovim (installe LazyVim + plugins, 2-5 min)"
info "Ne pas interrompre pendant l'installation des plugins."
nvim

log "Terminé."
ok "Ta config 'dev as life' est prête."
info "Post-install optionnelle dans nvim :"
info "  :Mason          → installer d'éventuels serveurs LSP manquants"
info "  :LazyExtras     → vérifier les extras activés"
info "  :checkhealth    → état global"
info "  :DBUIAddConnection → ta connexion Postgres Docker"
