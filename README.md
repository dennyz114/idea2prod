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
~/idea2prod/scripts/install.sh --update   # refresca skills y roles del harness
```

Todo queda **dentro del proyecto**: el script no escribe nada en `~/.claude`, `~/.agents` ni en otro lugar del usuario, así que no interfiere con las skills de nadie. Después de instalar, haz commit de lo creado: así cada clon y cada git worktree (T3 Code usa uno por thread) ya trae las skills.

`install.sh` es idempotente y no pisa archivos existentes. Anota lo que instaló en `.harness/managed.txt`; `--update` solo toca eso, y una skill propia del proyecto con el mismo nombre se respeta. Ver `scripts/install.sh --help`.

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
