# idea2prod: rules for developing this repo

This repo is the harness: files that other agents read in other projects. There is no application to build here.

## Structure

- `templates/`: copied into each project. `AGENTS.project.md` and `CLAUDE.project.md` are the rules that project inherits.
- `skills/<name>/SKILL.md`: one skill per phase. Frontmatter with `name` and `description` (when to use it).
- `roles/<role>.md`: role prompt with Claude subagent frontmatter.
- `scripts/`: portable bash, `set -euo pipefail`, idempotent.

## Conventions

- Skills are short: numbered steps, inputs, outputs, and what NOT to do. If one grows past ~100 lines, split it.
- A skill never depends on the chat: it reads and writes files (`plans/<slug>/plan.md`, `status.md`, `reviews/`).
- Nothing project-specific lives in this repo. What changes per project goes in `harness.config.yml`.
- Model and provider names live only in `model-mapping.yml`.
- Everything is written in English: docs, skills, roles, templates, script messages, file names, commands and keys.

## Verifying a change

- Test `scripts/install.sh` in a temporary project with `HOME` pointing to an empty temporary directory. It must be idempotent (running it twice changes nothing), write nothing into `HOME`, and respect project skills that have the same name.
- After editing a skill, check that its frontmatter is valid and that the paths it mentions exist in `templates/`.
