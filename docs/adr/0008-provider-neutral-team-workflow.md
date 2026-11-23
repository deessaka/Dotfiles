# ADR-0008: Team indépendant des CLIs d’agents

- Statut : accepté
- Date : 2026-11-23

## Contexte

Le workflow de mission existant est conservé sous `~/.codex/team-workflow` et
ses consignes décrivent le pilotage d’une session Codex. En parallèle, le
tableau Neovim lit déjà l’état `.team/board.json`. Claude Code, OpenCode et
GitHub Copilot CLI offrent chacun leurs propres formats d’instructions,
compétences, agents, délégation et permissions. Il n’existe pas de mécanisme
officiel commun qui orchestre ces quatre outils de façon interchangeable.

## Décision

Team est le collectif et le protocole de travail ; les CLI sont des runtimes.
Le modèle de mission, les rôles, les critères, les états, les preuves et les
règles de sécurité sont définis indépendamment du fournisseur.

- `.team/` est l’état canonique de chaque mission et reste lisible par les
  outils et le tableau Neovim.
- Le CLI local `team` valide les changements d’état et sérialise les écritures.
- Le contrat d’orchestration est versionné dans `team/` du dépôt Dotfiles.
- Une compétence Team est exposée aux chemins officiels de skills de chaque CLI.
- Chaque runtime conserve sa syntaxe, ses agents natifs, ses permissions et sa
  manière de déléguer. Aucun profil d’un fournisseur n’est présenté comme une
  isolation système.
- Un seul orchestrateur possède le board d’une mission. Les spécialistes
  reçoivent un ticket et un périmètre de fichiers, remettent un rapport, et ne
  modifient pas le board. Les éditions concurrentes passent par `team`.
- La délégation parallèle n’est annoncée que si le runtime l’a effectivement
  lancée. Sinon, l’orchestrateur signale le mode séquentiel ou le blocage.
- Publication, fusion, déploiement et extension de permissions nécessitent une
  autorisation explicite distincte.

## Adaptation aux runtimes

La compétence versionnée est disponible dans les emplacements globaux officiels
des skills : Codex et OpenCode via `~/.agents/skills`, Claude Code via
`~/.claude/skills`, et Copilot CLI via `~/.copilot/skills`.
Le script d’installation actualise uniquement les blocs Team encadrés dans les
fichiers d’instructions utilisateur des quatre CLI ; il préserve le reste de
chaque fichier et refuse les marqueurs incohérents. Il ne modifie ni
permissions ni authentification. Il ajoute la compétence, le CLI `team` et les
profils de spécialistes, et refuse les collisions.

Les adaptations d’agents spécialisés restent natives et facultatives. La
compétence commune donne le même cycle de travail ; les agents spécifiques à
un runtime sont des profils de capacité, pas une seconde définition du
processus.

## Conséquences

- Même tableau, cycle et critères avec les quatre outils ; le mode de
  délégation et les surfaces de permissions demeurent propres à chaque outil.
- Un seul processus d’installation ajoute le bloc Team aux instructions
  utilisateur et laisse les autres réglages actifs des fournisseurs intacts.
- `.team/` est local au checkout : pour des worktrees distincts, seul
  l’orchestrateur du checkout de mission met à jour le board ; les workers
  isolés rendent leurs rapports à cet orchestrateur.
- Le workflow ne survit pas à la fermeture des sessions CLI et n’est pas un
  service de fond. L’état persistant permet la reprise.

## Sources officielles vérifiées

- Codex : `AGENTS.md` et les compétences sont des mécanismes d’instructions
  réutilisables ; délégation gérée par le runtime.
- Claude Code : `CLAUDE.md`, skills sous `~/.claude/skills`, agents et équipes.
- OpenCode : `AGENTS.md`, skills sous `~/.config/opencode/skills`, agents et
  permissions configurables.
- Copilot CLI : skills sous `~/.copilot/skills`, instructions personnalisées,
  profils `.agent.md` et sous-agents.

Voir `docs/team/provider-compatibility.md` pour les liens précis et les limites.

## Options écartées

- Faire de Codex le service central : le workflow dépendrait encore d’un
  fournisseur et de sa session.
- Forcer tous les outils à employer les mêmes fichiers d’agents ou hooks : leurs
  formats, règles de permission et mécanismes de délégation diffèrent.
- Lancer toutes les CLI depuis un superviseur maison : cela contournerait les
  interfaces de permission et de session natives, tout en ajoutant un runtime
  autonome à sécuriser et maintenir.
