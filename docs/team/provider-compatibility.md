# Compatibilité Team par CLI

Team standardise les missions et leur contrôle. Il ne prétend pas rendre
identiques les sous-agents, permissions ou contextes de session des fournisseurs.
Les chemins ci-dessous sont les chemins globaux utilisateur documentés ; les
chemins par projet existent aussi, mais ne sont pas déployés ici.

| CLI | Instructions et skills | Délégation et limites |
| --- | --- | --- |
| Codex | Bloc Team dans `${CODEX_HOME:-~/.codex}/AGENTS.md`; skill personnelle dans `~/.agents/skills` | Sous-agents gérés par la session Codex. Les profils TOML existants restent Codex natifs. |
| Claude Code | `~/.claude/CLAUDE.md`; `~/.claude/skills/<nom>/SKILL.md` | Sous-agents et agent teams natifs ; les agent teams sont une fonction distincte et peuvent être désactivés. Les permissions viennent des réglages Claude et du runtime. |
| OpenCode | `~/.config/opencode/AGENTS.md`; compatibilité skill globale via `~/.agents/skills` | Agents `primary`/`subagent`, commandes et permissions OpenCode. Les permissions des sous-agents doivent être configurées séparément ; l’instruction de rôle seule ne les restreint pas. |
| GitHub Copilot CLI | `~/.copilot/copilot-instructions.md`; `~/.copilot/skills/<nom>/SKILL.md` | Profils Markdown `.agent.md`, sous-agents et hooks CLI. Les sous-agents ne reçoivent pas toujours les instructions de dépôt par défaut : leur profil doit inclure le contrat ou demander explicitement la compétence. |

Le paquet `team` expose le même skill dans les quatre répertoires natifs et des
profils de spécialiste Claude Code, OpenCode et Copilot CLI. Codex conserve ses
profils TOML déjà configurés. Les profils et la skill renvoient au même contrat
installé dans `~/.local/share/team/WORKFLOW.md`; ils n’imposent pas le même
mécanisme de délégation. Les agents utilisent `team` pour le ledger. Le skill
peut être invoqué explicitement comme `team` (syntaxe de sélection propre au CLI).

## Sources officielles

- [Codex : compétences personnelles et installation](https://developers.openai.com/api/reference/cli)
- [Codex : instructions persistantes et AGENTS.md](https://developers.openai.com/cookbook/examples/codex/iterating-development-workflows-with-codex)
- [Codex : délégation multi-agent](https://developers.openai.com/api/docs/guides/agents-api/multi-agent)
- [Claude Code : mémoire et CLAUDE.md](https://code.claude.com/docs/en/memory)
- [Claude Code : skills](https://code.claude.com/docs/en/skills)
- [Claude Code : sous-agents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code : agent teams](https://code.claude.com/docs/en/agent-teams)
- [OpenCode : instructions](https://opencode.ai/docs/instructions)
- [OpenCode : skills](https://opencode.ai/docs/skills)
- [OpenCode : agents](https://opencode.ai/docs/agents/)
- [OpenCode : permissions](https://opencode.ai/docs/permissions)
- [Copilot CLI : personnaliser le CLI](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/overview)
- [Copilot CLI : répertoire de configuration](https://docs.github.com/en/copilot/reference/copilot-cli-reference/cli-config-dir-reference)
- [Copilot CLI : agents personnalisés](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/create-custom-agents-for-cli)
- [Copilot CLI : instructions](https://docs.github.com/en/copilot/how-tos/copilot-cli/customize-copilot/add-custom-instructions)

Les capacités et chemins sont vérifiés au 23 novembre 2026. Vérifier les pages
officielles avant toute extension de l’installateur ou changement de format.
