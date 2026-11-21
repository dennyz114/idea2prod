#!/usr/bin/env bash
# Connects the idea2prod harness to a project. Everything stays INSIDE the project:
# it writes nothing to ~/.claude, ~/.agents or anywhere else in the user's home.
#
# Usage: install.sh [--update | --check] [--copy] [--no-labels] [DIR]
#   DIR          project root (default: the current directory)
#   --update     refresh the harness skills and roles, and report if the rules differ
#   --check      write nothing: show what an --update would change (exit 1 if anything)
#   --copy       copy skills into .claude/ and .agents/ instead of using symlinks
#                (for environments without symlinks, e.g. Windows); first install only
#   --no-labels  do not create GitHub labels
#
# By default there is ONE real copy in .harness/skills and .harness/roles; .claude/ and
# .agents/ point to it with relative symlinks (git versions them and recreates them in
# every worktree). Do not edit .harness/skills or .harness/roles: --update replaces them.
# Whatever the project already had (e.g. its own skill with the same name) is never touched.
set -euo pipefail

HARNESS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION="install"
WANT_COPY=0
LABELS=1
PROJECT=""

usage() { sed -n '2,/^set -euo/{/^#/s/^# \{0,1\}//p}' "${BASH_SOURCE[0]}"; }

for arg in "$@"; do
  case "$arg" in
    --update) ACTION="update" ;;
    --check) ACTION="check" ;;
    --copy) WANT_COPY=1 ;;
    --no-labels) LABELS=0 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Unknown option: $arg" >&2; usage >&2; exit 2 ;;
    *) PROJECT="$arg" ;;
  esac
done

PROJECT="$(cd "${PROJECT:-$PWD}" && pwd)"
VERSION_FILE="$PROJECT/.harness/version"
COPIES_FILE="$PROJECT/.harness/copies.txt"

git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "$PROJECT is not a git repository." >&2; exit 1; }

log() { printf '  %s\n' "$*"; }
say() { printf '  %-10s %s\n' "$1" "$2"; }   # say <verb> <text>

version_get() { [ -f "$VERSION_FILE" ] && sed -n "s/^$1=//p" "$VERSION_FILE" | head -n1 || true; }

harness_commit() {
  local c
  c="$(git -C "$HARNESS" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  if [ -n "$(git -C "$HARNESS" status --porcelain 2>/dev/null)" ]; then c="$c-dirty"; fi
  printf '%s' "$c"
}

# The mode (link|copy) is fixed on the first install.
MODE="$(version_get mode)"
if [ -z "$MODE" ]; then
  if [ "$WANT_COPY" -eq 1 ]; then MODE="copy"; else MODE="link"; fi
elif [ "$WANT_COPY" -eq 1 ] && [ "$MODE" != "copy" ]; then
  echo "This project was installed with symlinks; --copy only applies to the first install." >&2
  exit 2
fi

# Templates the project makes its own on install: they are never overwritten.
TEMPLATE_PAIRS=(
  "AGENTS.project.md AGENTS.md"
  "CLAUDE.project.md CLAUDE.md"
  "model-mapping.yml .harness/model-mapping.yml"
  "pr.md .github/PULL_REQUEST_TEMPLATE.md"
  "ticket.md .github/ISSUE_TEMPLATE/feature.md"
)

report_template_drift() {
  local pair tpl rel n
  echo "Project rules and templates (informational: they are yours, never overwritten)"
  for pair in "${TEMPLATE_PAIRS[@]}"; do
    tpl="${pair%% *}"; rel="${pair#* }"
    if [ ! -e "$PROJECT/$rel" ]; then say "missing" "$rel"
    elif cmp -s "$HARNESS/templates/$tpl" "$PROJECT/$rel"; then say "same" "$rel"
    else
      n="$(diff "$HARNESS/templates/$tpl" "$PROJECT/$rel" | grep -c '^[<>]' || true)"
      say "differs" "$rel ($n lines)  →  diff -u $PROJECT/$rel $HARNESS/templates/$tpl"
    fi
  done
}

skill_names() { for d in "$HARNESS"/skills/*/; do [ -f "$d/SKILL.md" ] && basename "$d"; done; }
role_files() { for f in "$HARNESS"/roles/*.md; do [ -f "$f" ] && basename "$f"; done; }

# ---------------------------------------------------------------- --check
if [ "$ACTION" = "check" ]; then
  if [ ! -f "$VERSION_FILE" ]; then
    echo "The harness is not installed in $PROJECT (.harness/version is missing)."; exit 1
  fi
  drift=0
  installed="$(version_get commit)"; current="$(harness_commit)"
  echo "Project: $PROJECT   (mode: $MODE)"
  echo "Installed version: ${installed:-?}   Harness version: $current"
  [ "$installed" = "$current" ] || drift=1
  echo "Skills and roles"
  if [ "$MODE" = "link" ]; then
    for sub in skills roles; do
      if [ ! -d "$PROJECT/.harness/$sub" ]; then say "missing" ".harness/$sub"; drift=1
      elif ! diff -rq "$HARNESS/$sub" "$PROJECT/.harness/$sub" >/dev/null 2>&1; then
        say "changed" ".harness/$sub"; diff -rq "$HARNESS/$sub" "$PROJECT/.harness/$sub" 2>&1 | sed 's/^/             /'; drift=1
      else say "up to date" ".harness/$sub"; fi
    done
  else
    for name in $(skill_names); do
      for base in .claude/skills .agents/skills; do
        if [ ! -d "$PROJECT/$base/$name" ]; then say "missing" "$base/$name"; drift=1
        elif ! diff -rq "$HARNESS/skills/$name" "$PROJECT/$base/$name" >/dev/null 2>&1; then say "changed" "$base/$name"; drift=1
        else say "up to date" "$base/$name"; fi
      done
    done
    for f in $(role_files); do
      if [ ! -f "$PROJECT/.claude/agents/$f" ] || ! cmp -s "$HARNESS/roles/$f" "$PROJECT/.claude/agents/$f"; then
        say "changed" ".claude/agents/$f"; drift=1
      else say "up to date" ".claude/agents/$f"; fi
    done
  fi
  report_template_drift
  echo
  if [ "$drift" -eq 1 ]; then echo "There are pending changes: run install.sh --update."; else echo "Everything is up to date."; fi
  exit "$drift"
fi

# ---------------------------------------------------------------- install / update
if [ "$ACTION" = "update" ] && [ ! -f "$VERSION_FILE" ]; then
  echo "This project has no .harness/version: run install.sh without --update first." >&2; exit 1
fi

put() { # template-name relative-destination
  local src="$HARNESS/templates/$1" dst="$PROJECT/$2"
  if [ -e "$dst" ]; then say "exists" "$2"; return; fi
  mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"; say "created" "$2"
}

# Replaces .harness/<sub> entirely with the harness copy (the whole folder belongs to the harness).
sync_harness_dir() { # skills|roles
  local sub="$1" dst="$PROJECT/.harness/$1"
  if [ -d "$dst" ] && [ "$ACTION" != "update" ]; then say "exists" ".harness/$sub"; return; fi
  [ -n "$sub" ] || return 1
  local verb="created"; if [ "$ACTION" = "update" ]; then verb="updated"; fi
  rm -rf "$dst"; mkdir -p "$PROJECT/.harness"; cp -R "$HARNESS/$sub" "$dst"
  find "$dst" -name '.DS_Store' -delete 2>/dev/null || true
  say "$verb" ".harness/$sub"
}

link_item() { # relative-destination  symlink-target
  local rel="$1" target="$2" dst="$PROJECT/$1"
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$target" ]; then say "exists" "$rel"; else say "skipped" "$rel (symlink from another source)"; fi
    return
  fi
  if [ -e "$dst" ]; then say "skipped" "$rel (already exists and is not from the harness)"; return; fi
  mkdir -p "$(dirname "$dst")"; ln -s "$target" "$dst"; say "linked" "$rel"
}

copy_item() { # source relative-destination
  local src="$1" rel="$2" dst="$PROJECT/$2"
  [ -n "$rel" ] || return 1
  if [ -e "$dst" ]; then
    if [ -f "$COPIES_FILE" ] && grep -qxF "$rel" "$COPIES_FILE"; then
      if [ "$ACTION" = "update" ]; then rm -rf "$dst"; cp -R "$src" "$dst"; say "updated" "$rel"; else say "exists" "$rel"; fi
    else say "skipped" "$rel (already exists and is not from the harness)"; fi
    return
  fi
  mkdir -p "$(dirname "$dst")" "$PROJECT/.harness"; cp -R "$src" "$dst"
  printf '%s\n' "$rel" >> "$COPIES_FILE"; say "copied" "$rel"
}

# Removes harness symlinks whose target no longer exists (skills or roles that were deleted).
prune_stale_links() {
  local l
  for l in "$PROJECT"/.claude/skills/* "$PROJECT"/.agents/skills/* "$PROJECT"/.claude/agents/*; do
    if [ -L "$l" ] && [[ "$(readlink "$l")" == ../../.harness/* ]] && [ ! -e "$l" ]; then
      rm -f "$l"; say "removed" "${l#"$PROJECT"/} (no longer in the harness)"
    fi
  done
}

# Copy mode: removes copies whose source no longer exists in the harness (renamed or deleted).
prune_stale_copies() {
  [ -f "$COPIES_FILE" ] || return 0
  local rel src tmp
  tmp="$(mktemp)"
  while IFS= read -r rel; do
    [ -n "$rel" ] || continue
    case "$rel" in
      .claude/skills/*|.agents/skills/*) src="$HARNESS/skills/${rel##*/}" ;;
      .claude/agents/*) src="$HARNESS/roles/${rel##*/}" ;;
      *) src="" ;;
    esac
    if [ -n "$src" ] && [ ! -e "$src" ]; then
      rm -rf "${PROJECT:?}/$rel"; say "removed" "$rel (no longer in the harness)"
    else
      printf '%s\n' "$rel" >> "$tmp"
    fi
  done < "$COPIES_FILE"
  mv "$tmp" "$COPIES_FILE"
}

echo "Project: $PROJECT   (mode: $MODE)"
echo "Harness: $HARNESS ($(harness_commit))"

echo "Project files"
put AGENTS.project.md AGENTS.md
put CLAUDE.project.md CLAUDE.md
put harness.config.yml harness.config.yml
put model-mapping.yml .harness/model-mapping.yml
put pr.md .github/PULL_REQUEST_TEMPLATE.md
put ticket.md .github/ISSUE_TEMPLATE/feature.md

echo "Skills and roles"
if [ "$MODE" = "link" ]; then
  sync_harness_dir skills
  sync_harness_dir roles
  for name in $(skill_names); do
    link_item ".claude/skills/$name" "../../.harness/skills/$name"
    link_item ".agents/skills/$name" "../../.harness/skills/$name"
  done
  for f in $(role_files); do link_item ".claude/agents/$f" "../../.harness/roles/$f"; done
  [ "$ACTION" = "update" ] && prune_stale_links
else
  for name in $(skill_names); do
    copy_item "$HARNESS/skills/$name" ".claude/skills/$name"
    copy_item "$HARNESS/skills/$name" ".agents/skills/$name"
  done
  for f in $(role_files); do copy_item "$HARNESS/roles/$f" ".claude/agents/$f"; done
  if [ "$ACTION" = "update" ]; then prune_stale_copies; fi
fi

mkdir -p "$PROJECT/.harness"
printf 'commit=%s\nmode=%s\n' "$(harness_commit)" "$MODE" > "$VERSION_FILE"
say "version" "$(harness_commit)"

echo ".gitignore"
touch "$PROJECT/.gitignore"
for entry in "plans/" ".env.harness" ".harness/runs/"; do
  if grep -qxF "$entry" "$PROJECT/.gitignore"; then say "exists" "$entry"; else
    printf '%s\n' "$entry" >> "$PROJECT/.gitignore"; say "added" "$entry"
  fi
done

if [ "$ACTION" = "install" ]; then
  echo "GitHub labels"
  if [ "$LABELS" -eq 0 ]; then
    log "skipped (--no-labels)"
  elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 \
       && git -C "$PROJECT" remote get-url origin >/dev/null 2>&1; then
    for label in "needs grooming" "needs ui mock" "security" "critical"; do
      if (cd "$PROJECT" && gh label create "$label" --force >/dev/null 2>&1); then say "label" "$label"
      else log "could not create the label '$label'"; fi
    done
  else
    log "skipped (needs gh signed in and an origin remote)"
  fi
else
  report_template_drift
fi

echo
echo "Done. Review the changes with git and commit what was installed: that way every clone and"
echo "every worktree gets the skills. Fill in harness.config.yml if this is a fresh install."
