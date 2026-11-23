#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE="$DOTFILES_DIR/team"
CODEX_HOME="${CODEX_HOME:-$HOME/.codex}"
CODEX_AGENTS="$CODEX_HOME/AGENTS.md"
CLAUDE_HOME="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
OPENCODE_HOME="${XDG_CONFIG_HOME:-$HOME/.config}/opencode"
COPILOT_HOME="${COPILOT_HOME:-$HOME/.copilot}"
CLAUDE_AGENTS="$CLAUDE_HOME/CLAUDE.md"
OPENCODE_AGENTS="$OPENCODE_HOME/AGENTS.md"
COPILOT_AGENTS="$COPILOT_HOME/copilot-instructions.md"
DRY_RUN=0
[[ "${1:-}" == "--check" ]] && DRY_RUN=1

targets=()
sources=()
while IFS= read -r source_path; do
  relative="${source_path#"$PACKAGE"/}"
  case "$relative" in
    .claude/*) target="$CLAUDE_HOME/${relative#.claude/}" ;;
    .config/opencode/*) target="$OPENCODE_HOME/${relative#.config/opencode/}" ;;
    .copilot/*) target="$COPILOT_HOME/${relative#.copilot/}" ;;
    *) target="$HOME/$relative" ;;
  esac
  targets+=("$target")
  sources+=("$source_path")
done < <(find "$PACKAGE" \( -type f -o -type l \) -print | LC_ALL=C sort)
skill_source="$PACKAGE/.local/share/team/SKILL.md"
for target in "$HOME/.agents/skills/team/SKILL.md" "$CLAUDE_HOME/skills/team/SKILL.md" "$COPILOT_HOME/skills/team/SKILL.md"; do
  targets+=("$target")
  sources+=("$skill_source")
done
python3 "$PACKAGE/.local/share/team/update_instructions.py" --check "$CODEX_AGENTS" "$PACKAGE/.local/share/team/codex-AGENTS.md" >/dev/null
python3 "$PACKAGE/.local/share/team/update_instructions.py" --check "$CLAUDE_AGENTS" "$PACKAGE/.local/share/team/claude-instructions.md" >/dev/null
python3 "$PACKAGE/.local/share/team/update_instructions.py" --check "$OPENCODE_AGENTS" "$PACKAGE/.local/share/team/opencode-instructions.md" >/dev/null
python3 "$PACKAGE/.local/share/team/update_instructions.py" --check "$COPILOT_AGENTS" "$PACKAGE/.local/share/team/copilot-instructions.md" >/dev/null
created=()
rollback() {
  for index in "${created[@]}"; do
    target="${targets[$index]}"
    source="${sources[$index]}"
    if [[ -L "$target" && "$target" -ef "$source" ]]; then
      rm -f "$target"
    fi
  done
}
trap rollback ERR

for index in "${!targets[@]}"; do
  source="${sources[$index]}"
  target="${targets[$index]}"
  [[ -e "$source" ]] || { printf 'Source absent: %s\n' "$source" >&2; exit 1; }
  if [[ -e "$target" || -L "$target" ]]; then
    if [[ "$target" -ef "$source" ]]; then
      continue
    fi
    printf 'Collision, rien installé : %s existe déjà\n' "$target" >&2
    exit 1
  fi
  parent="$(dirname "$target")"
  if [[ -e "$parent" && ! -d "$parent" ]]; then
    printf 'Collision, rien installé : le parent n’est pas un dossier : %s\n' "$parent" >&2
    exit 1
  fi
done

if [[ "$DRY_RUN" -eq 1 ]]; then
  printf 'Installable sans collision : %d fichiers Team\n' "${#targets[@]}"
  exit 0
fi

for index in "${!targets[@]}"; do
  source="${sources[$index]}"
  target="${targets[$index]}"
  [[ -e "$target" || -L "$target" ]] && continue
  mkdir -p "$(dirname "$target")"
  ln -s "$source" "$target"
  created+=("$index")
done
python3 "$HOME/.local/share/team/update_instructions.py" "$CODEX_AGENTS" "$HOME/.local/share/team/codex-AGENTS.md"
python3 "$HOME/.local/share/team/update_instructions.py" "$CLAUDE_AGENTS" "$HOME/.local/share/team/claude-instructions.md"
python3 "$HOME/.local/share/team/update_instructions.py" "$OPENCODE_AGENTS" "$HOME/.local/share/team/opencode-instructions.md"
python3 "$HOME/.local/share/team/update_instructions.py" "$COPILOT_AGENTS" "$HOME/.local/share/team/copilot-instructions.md"
trap - ERR
printf 'Team installé. Lance `team --help`, puis demande au CLI d’utiliser la skill `team`.\n'
