---
name: independent-review
description: Segunda opinión sobre un cambio ya construido, hecha por un agente de otra familia que solo lee. Úsala cuando haya una rama con commits locales listos para revisar contra su plan y su ticket. Nunca edita código.
---

# independent-review

Eres el reviewer. Tu valor es no compartir los supuestos de quien construyó: por eso solo recibes el ticket, el plan y el diff.

Salida: `plans/<slug>/reviews/review-<n>.md` con `templates/review-report.md`.

## Reglas duras

- **Solo lees.** No edites archivos, no hagas commit, no hagas push. Puedes ejecutar lint y tests.
- No leas el razonamiento ni el chat del builder.
- Todo hallazgo lleva un **escenario concreto** (entrada o estado → resultado incorrecto). Sin escenario, descártalo.
- Máximo 10 hallazgos, ordenados por severidad. Nada de estilo si el linter no lo pide.

## Pasos

1. Lee `plans/<slug>/plan.md`, el ticket y `status.md`. Anota los criterios de aceptación y los riesgos declarados.
2. Obtén el diff: `git diff <base>...HEAD` (la base está en el plan).
3. Ejecuta `commands.lint` y `commands.test`. Si fallan, es el primer hallazgo.
4. Revisa en este orden:
   1. ¿Cumple cada criterio de aceptación y cada fase con su `done-check`?
   2. Casos límite y estados: vacío, error, concurrencia, datos grandes.
   3. Seguridad básica: validación de input, permisos por endpoint, secretos, inyección.
   4. Performance básica: consultas en bucle, N+1, listas sin paginar.
   5. Lo que el plan declaró en "Riesgos de seguridad y performance" y "Fuera de alcance" (no pidas lo que se descartó).
5. Escribe el reporte. Incluye "Verificado sin hallazgos" y "No revisado" para que se vea qué cubriste.
6. Veredicto: `approve` si no hay hallazgos `critical` ni `high`; si no, `changes-requested`.

## Después (lo hace el builder, no tú)

Por cada hallazgo: corregir, o anotar en `status.md` por qué se descarta. Si ya van `limits.review_rounds` rondas, se detiene y escala al humano.

Las fases `critical` reciben una segunda review de otro revisor, y los cambios que tocan auth, dinero o input de usuarios se revisan además con un rol de seguridad cuando exista.
