# idea2prod: reglas para desarrollar este repo

Este repo es el harness: archivos que otros agentes leen en otros proyectos. Aquí no hay aplicación que compilar.

## Estructura

- `templates/`: se copia a cada proyecto. `AGENTS.project.md` y `CLAUDE.project.md` son las reglas que ese proyecto hereda.
- `skills/<nombre>/SKILL.md`: una skill por fase. Frontmatter con `name` y `description` (cuándo usarla).
- `roles/<rol>.md`: prompt de rol con frontmatter de subagente de Claude.
- `scripts/`: bash portable, `set -euo pipefail`, idempotente.

## Convenciones

- Las skills son cortas: pasos numerados, entradas, salidas y qué NO hacer. Si pasa de ~100 líneas, se parte.
- Una skill nunca depende del chat: lee y escribe archivos (`plans/<slug>/plan.md`, `status.md`, `reviews/`).
- Nada específico de un proyecto en este repo. Lo que cambia por proyecto va en `harness.config.yml`.
- Los nombres de modelos y proveedores solo viven en `model-mapping.yml`.
- Todo lo que se escribe para un humano va en español; los nombres de archivos, comandos y claves, en inglés.

## Verificar un cambio

- `scripts/install.sh` se prueba en un proyecto temporal con `HOME` apuntando a un directorio temporal. Debe ser idempotente: correrlo dos veces no cambia nada.
- Después de editar una skill, revisar que el frontmatter sea válido y que las rutas que menciona existan en `templates/`.
