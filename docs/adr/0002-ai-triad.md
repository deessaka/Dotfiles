# ADR-0002: Duo IA = copilot.lua + opencode.nvim (avante.nvim retiré)

Deux intégrations IA distinctes, sans chevauchement, couvrant deux besoins :
- **copilot.lua** : complétion inline non intrusive pendant la frappe.
- **opencode.nvim** : agent d'exécution (modifie fichiers, lance commandes) avec injection de contexte éditeur (curseur, sélection, buffer), connecté à opencode.

Retiré le 2026-09-18 : **avante.nvim** (assistant conversationnel en UI dédiée).
Motif : redondant avec l'agent opencode, source d'erreurs au démarrage en cascade
via Mason, et 68M de plugin pour un usage marginal.

Rejeté : intégrer l'IA uniquement dans un terminal flottant (perte du contexte buffer), ou un seul outil IA (le complet est demandé).