# idea2prod

A harness that takes a project from idea to production with several agents (Claude Code, Codex) running in separate threads, for example from T3 Code.

It is not an application: it is a set of files that agents read. The rules live in `AGENTS.md`, each phase is a skill, and agents hand work to each other through files, not through chat.

## Flow

0. **Split** (only for a big idea): a conversation with the agent, with mocks → a backlog of ticket briefs that you approve (`splitting-ideas`). Each approved brief then goes through steps 1 to 8.
1. **Ticket**: idea + mocks, or an approved brief → draft ticket and a private plan (`writing-ticket`)
2. **Ticket and check**: GitHub ticket, tested by a reader with no context
3. **Human approval**: mocks and plan
4. **Build**: phase by phase, code and tests, with an ephemeral DB per ticket
5. **Cross review**: an agent from another provider reviews, read-only (`independent-review`)
6. **Docs**
7. **PR review**
8. **E2E**

## Install into a project

```bash
git clone https://github.com/dennyz114/idea2prod ~/idea2prod
cd /path/to/your/project
~/idea2prod/scripts/install.sh            # install
~/idea2prod/scripts/install.sh --check    # what an --update would change (writes nothing)
~/idea2prod/scripts/install.sh --update   # refresh the harness skills and roles
```

Everything stays **inside the project**: the script writes nothing to `~/.claude`, `~/.agents` or anywhere else in the user's home, so it never interferes with anyone's own skills. After installing, commit what was created: that way every clone and every git worktree (T3 Code uses one per thread) already has the skills.

## What it looks like in the project

```
.harness/skills/<name>/        the only real copy of the skills (do not edit)
.harness/roles/<role>.md       the only real copy of the roles (do not edit)
.harness/version               harness commit that was installed, and the mode (link|copy)
.claude/skills/<name>   →      ../../.harness/skills/<name>   (relative symlink)
.agents/skills/<name>   →      ../../.harness/skills/<name>
.claude/agents/<role>.md →     ../../.harness/roles/<role>.md
```

Git versions relative symlinks and recreates them in every worktree. If your environment does not support them (for example Windows without symlinks enabled), `install.sh --copy` copies the skills into `.claude/` and `.agents/` instead; the mode is fixed on the first install.

## Maintenance

The harness is the single source of truth: improve the skills here, commit and push, then in each project run `install.sh --check` and then `--update`; review the `git diff` and commit.

- **Do not edit `.harness/skills` or `.harness/roles` inside a project**: `--update` replaces them. If a project needs something different, create its own skill with another name.
- A project skill with the same name as a harness skill is respected: it stays unlinked and the script says so.
- `AGENTS.md`, `harness.config.yml`, `.harness/model-mapping.yml` and the GitHub templates belong to the project from the moment they are installed: `--update` never overwrites them, it only tells you whether they differ from the current harness version.
- `--check` exits with code 1 when there are pending changes, so it also works in CI.

See `scripts/install.sh --help`.

## Structure

```
AGENTS.md / CLAUDE.md     rules for developing this repo
templates/                what gets copied into each project once (rules, config, model mapping, PR and ticket templates)
skills/                   one skill per phase; each skill keeps its own templates next to its SKILL.md
roles/                    role prompts (Claude subagents; in Codex you paste them when opening the thread)
scripts/install.sh        connects the harness to a project
```

## Status

Done: common rules, config, `model-mapping`, the `splitting-ideas`, `writing-ticket` and `independent-review` skills, the `ticket-writer` and `reviewer` roles, templates and `install.sh`.

Pending: `ticket-check`, `executing-plans`, `implement-feature`, `documenting`, `pr-review`, `e2e-runner`, `reporting-results`, security and performance roles, the `db-*.sh`, `gh-*.sh`, `worktree.sh` and `check-ready.sh` scripts.
