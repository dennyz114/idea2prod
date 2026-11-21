# idea2prod

Harness para llevar un proyecto de la idea a producción con varios agentes (Claude Code, Codex) corriendo en threads separados, por ejemplo desde T3 Code.

No es una aplicación: son archivos que los agentes leen. Las reglas viven en `AGENTS.md`, cada fase es una skill y el traspaso entre agentes se hace por archivos, no por chat.

## Flujo

1. **Planear**: idea + mocks → plan (`writing-plans`)
2. **Ticket y check**: ticket en GitHub y prueba con un lector sin contexto
3. **Tú apruebas**: mocks y plan
4. **Construir**: fases, código y tests, con una DB efímera por ticket
5. **Review cruzada**: otro proveedor revisa, solo lee (`independent-review`)
6. **Docs**
7. **Review del PR**
8. **E2E**

## Instalar en un proyecto

```bash
git clone https://github.com/dennyz114/idea2prod ~/idea2prod
cd /ruta/a/tu/proyecto
~/idea2prod/scripts/install.sh            # instala
~/idea2prod/scripts/install.sh --check    # qué cambiaría un --update (no escribe nada)
~/idea2prod/scripts/install.sh --update   # refresca skills y roles del harness
```

Todo queda **dentro del proyecto**: el script no escribe nada en `~/.claude`, `~/.agents` ni en otro lugar del usuario, así que no interfiere con las skills de nadie. Después de instalar, haz commit de lo creado: así cada clon y cada git worktree (T3 Code usa uno por thread) ya trae las skills.

## Cómo queda en el proyecto

```
.harness/skills/<nombre>/      la única copia real de las skills (no se edita)
.harness/roles/<rol>.md        la única copia real de los roles (no se edita)
.harness/version               commit del harness instalado y modo (link|copy)
.claude/skills/<nombre>   →    ../../.harness/skills/<nombre>   (symlink relativo)
.agents/skills/<nombre>   →    ../../.harness/skills/<nombre>
.claude/agents/<rol>.md   →    ../../.harness/roles/<rol>.md
```

Los symlinks relativos los versiona git y los recrea en cada worktree. Si tu entorno no los soporta (por ejemplo Windows sin symlinks habilitados), `install.sh --copy` copia las skills a `.claude/` y `.agents/`; el modo queda fijado en la primera instalación.

## Mantenimiento

El harness es la única fuente de verdad: mejora las skills aquí, haz commit y push, y en cada proyecto corre `install.sh --check` y luego `--update`; revisa el `git diff` y haz commit.

- **No edites `.harness/skills` ni `.harness/roles` dentro de un proyecto**: `--update` los reemplaza. Si un proyecto necesita algo distinto, crea una skill propia con otro nombre.
- Una skill propia del proyecto con el mismo nombre que una del harness se respeta: queda sin enlazar y el script lo avisa.
- `AGENTS.md`, `harness.config.yml`, `.harness/model-mapping.yml` y las plantillas de GitHub son del proyecto desde la instalación: `--update` nunca los sobrescribe, solo te dice si difieren de la versión actual del harness.
- `--check` sale con código 1 si hay cambios pendientes, así que sirve también en CI.

Ver `scripts/install.sh --help`.

## Estructura

```
AGENTS.md / CLAUDE.md     reglas para desarrollar este repo
templates/                lo que se copia a cada proyecto (reglas, config, plan, ticket, PR, review)
skills/                   una skill por fase
roles/                    prompts de rol (subagentes de Claude; en Codex se pegan al abrir el thread)
scripts/install.sh        conecta el harness con un proyecto
```

## Estado

Listo: reglas comunes, config, `model-mapping`, skills `writing-plans` e `independent-review`, roles `planner` y `reviewer`, plantillas e `install.sh`.

Pendiente: `ticket-writer`, `ticket-check`, `executing-plans`, `implement-feature`, `documenting`, `pr-review`, `e2e-runner`, `reporting-results`, roles de seguridad y performance, scripts `db-*.sh`, `gh-*.sh`, `worktree.sh` y `check-ready.sh`.
