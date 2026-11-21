#!/usr/bin/env bash
# Conecta el harness idea2prod con un proyecto. Idempotente: no pisa archivos existentes.
#
# Uso: install.sh [--skills=user|project] [--no-labels] [DIR]
#   DIR               raíz del proyecto (por defecto, el directorio actual)
#   --skills=user     (por defecto) enlaza skills y roles en ~/.claude y ~/.agents,
#                     así existen en todos los git worktrees sin ensuciar el repo
#   --skills=project  copia skills y roles dentro del proyecto, para versionarlos
#   --no-labels       no crea labels en GitHub
#
# Variables: CLAUDE_HOME (def. ~/.claude), AGENTS_HOME (def. ~/.agents)
set -euo pipefail

HARNESS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_MODE="user"
LABELS=1
PROJECT=""

for arg in "$@"; do
  case "$arg" in
    --skills=user|--skills=project) SKILLS_MODE="${arg#--skills=}" ;;
    --no-labels) LABELS=0 ;;
    -h|--help) sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "Opción desconocida: $arg" >&2; exit 2 ;;
    *) PROJECT="$arg" ;;
  esac
done

PROJECT="$(cd "${PROJECT:-$PWD}" && pwd)"
CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
AGENTS_HOME="${AGENTS_HOME:-$HOME/.agents}"

git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "$PROJECT no es un repositorio git." >&2; exit 1; }

log() { printf '  %s\n' "$*"; }

# Copia un archivo de templates/ solo si el destino no existe.
put() { # origen destino
  local src="$HARNESS/templates/$1" dst="$PROJECT/$2"
  if [ -e "$dst" ]; then log "existe   $2"; return; fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  log "creado   $2"
}

# Enlaza (o copia) origen en destino. No toca un destino que no sea suyo.
link_or_copy() { # origen destino modo(link|copy)
  local src="$1" dst="$2" mode="$3"
  mkdir -p "$(dirname "$dst")"
  if [ "$mode" = "link" ]; then
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then return; fi
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then log "omitido  $dst (existe y no es un enlace)"; return; fi
    ln -sfn "$src" "$dst"
  else
    if [ -e "$dst" ]; then return; fi
    cp -R "$src" "$dst"
  fi
}

echo "Proyecto: $PROJECT"
echo "Harness:  $HARNESS"

echo "Archivos del proyecto"
put AGENTS.project.md AGENTS.md
put CLAUDE.project.md CLAUDE.md
put harness.config.yml harness.config.yml
put model-mapping.yml .harness/model-mapping.yml
put pr.md .github/PULL_REQUEST_TEMPLATE.md
put ticket.md .github/ISSUE_TEMPLATE/feature.md

echo "Skills y roles ($SKILLS_MODE)"
if [ "$SKILLS_MODE" = "user" ]; then
  mode=link; skills_claude="$CLAUDE_HOME/skills"; skills_agents="$AGENTS_HOME/skills"; roles_dir="$CLAUDE_HOME/agents"
else
  mode=copy; skills_claude="$PROJECT/.claude/skills"; skills_agents="$PROJECT/.agents/skills"; roles_dir="$PROJECT/.claude/agents"
fi
for dir in "$HARNESS"/skills/*/; do
  [ -f "$dir/SKILL.md" ] || continue
  name="$(basename "$dir")"
  link_or_copy "${dir%/}" "$skills_claude/$name" "$mode"
  link_or_copy "${dir%/}" "$skills_agents/$name" "$mode"
  log "skill    $name"
done
for file in "$HARNESS"/roles/*.md; do
  [ -f "$file" ] || continue
  link_or_copy "$file" "$roles_dir/$(basename "$file")" "$mode"
  log "rol      $(basename "$file" .md)"
done

echo ".gitignore"
touch "$PROJECT/.gitignore"
for entry in "plans/" ".env.harness" ".harness/runs/"; do
  if grep -qxF "$entry" "$PROJECT/.gitignore"; then log "existe   $entry"; else
    printf '%s\n' "$entry" >> "$PROJECT/.gitignore"; log "añadido  $entry"
  fi
done

echo "Labels de GitHub"
if [ "$LABELS" -eq 0 ]; then
  log "omitido (--no-labels)"
elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 \
     && git -C "$PROJECT" remote get-url origin >/dev/null 2>&1; then
  for label in "needs grooming" "needs ui mock" "security" "critical"; do
    (cd "$PROJECT" && gh label create "$label" --force >/dev/null 2>&1) \
      && log "label    $label" || log "no se pudo crear el label '$label'"
  done
else
  log "omitido (falta gh con sesión iniciada o un remoto origin)"
fi

echo
echo "Listo. Siguiente paso: rellena harness.config.yml y revisa .harness/model-mapping.yml."
