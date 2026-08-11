# ADR-0005: Neovim stable apt 0.11.6, pas nightly

On installe Neovim **0.11.6** depuis apt (satisfait >= 0.11.2 requis par LazyVim), plutôt que l'AppImage nightly. Raison : la stabilité prime pour un environnement quotidien de production ; les nightly (0.12.x) apportent des features fraîches mais de l'instabilité et des mises à jour fréquentes qui cassent les plugins.