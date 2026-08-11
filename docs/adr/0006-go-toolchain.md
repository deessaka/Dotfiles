# ADR-0006: Go installé dans le toolchain local

Go était listé dans la stack mais absent de la machine. On installe le toolchain Go (gopls, golangci-lint, dlv) pour activer la pleine expérience Go dans Neovim : LSP, formatage, lint, debugging via delve. Devient ainsi un stack complet dès le départ, sans activation tardive d'extras.