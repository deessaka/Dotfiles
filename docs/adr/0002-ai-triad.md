# ADR-0002: Triade IA = copilot.lua + opencode.nvim + avante.nvim

Trois intégrations IA distinctes, sans chevauchement, couvrant trois besoins :
- **copilot.lua** : complétion inline non intrusive pendant la frappe.
- **opencode.nvim** : agent d'exécution (modifie fichiers, lance commandes) avec injection de contexte éditeur (curseur, sélection, buffer), connecté à opencode.
- **avante.nvim** : assistant conversationnel en UI dédiée, provider **Gemini via OAuth (ACP gemini-cli)** — pas de clé API à générer, réutilise le login Gemini existant.

Rejeté : intégrer l'IA uniquement dans un terminal flottant (perte du contexte buffer), ou un seul outil IA (le complet est demandé).