#!/usr/bin/env bash
# Conecta el harness idea2prod con un proyecto. Todo queda DENTRO del proyecto:
# no escribe nada en ~/.claude, ~/.agents ni en ningún otro lugar del usuario.
#
# Uso: install.sh [--update] [--no-labels] [DIR]
#   DIR          raíz del proyecto (por defecto, el directorio actual)
#   --update     refresca las skills y roles que el harness instaló antes
#   --no-labels  no crea labels en GitHub
#
# Skills y roles se copian a .claude/ y .agents/ del proyecto y se versionan, así
# los trae cada clon y cada git worktree. Lo instalado queda anotado en
# .harness/managed.txt: solo eso se actualiza; lo que ya existía en el proyecto
# (por ejemplo una skill propia con el mismo nombre) nunca se toca.
set -euo pipefail

HARNESS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPDATE=0
LABELS=1
PROJECT=""

usage() { sed -n '2,13p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

for arg in "$@"; do
  case "$arg" in
    --update) UPDATE=1 ;;
    --no-labels) LABELS=0 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Opción desconocida: $arg" >&2; usage >&2; exit 2 ;;
    *) PROJECT="$arg" ;;
  esac
done

PROJECT="$(cd "${PROJECT:-$PWD}" && pwd)"
MANIFEST="$PROJECT/.harness/managed.txt"

git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "$PROJECT no es un repositorio git." >&2; exit 1; }

log() { printf '  %s\n' "$*"; }

# Copia un archivo de templates/ solo si el destino no existe.
put() { # origen-en-templates destino-relativo
  local src="$HARNESS/templates/$1" dst="$PROJECT/$2"
  if [ -e "$dst" ]; then log "existe     $2"; return; fi
  mkdir -p "$(dirname "$dst")"
  cp "$src" "$dst"
  log "creado     $2"
}

is_managed() { [ -f "$MANIFEST" ] && grep -qxF "$1" "$MANIFEST"; }

# Copia una skill o rol al proyecto y lo anota en el manifiesto.
sync_item() { # origen destino-relativo
  local src="$1" rel="$2" dst="$PROJECT/$2"
  [ -n "$rel" ] || return 1
  if [ -e "$dst" ]; then
    if is_managed "$rel"; then
      if [ "$UPDATE" -eq 1 ]; then
        rm -rf "$dst"; cp -R "$src" "$dst"; log "actualizado $rel"
      else
        log "existe     $rel"
      fi
    else
      log "omitido    $rel (ya existe y no es del harness)"
    fi
    return
  fi
  mkdir -p "$(dirname "$dst")" "$(dirname "$MANIFEST")"
  cp -R "$src" "$dst"
  printf '%s\n' "$rel" >> "$MANIFEST"
  log "creado     $rel"
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

echo "Skills y roles"
for dir in "$HARNESS"/skills/*/; do
  [ -f "$dir/SKILL.md" ] || continue
  name="$(basename "$dir")"
  sync_item "${dir%/}" ".claude/skills/$name"
  sync_item "${dir%/}" ".agents/skills/$name"
done
for file in "$HARNESS"/roles/*.md; do
  [ -f "$file" ] || continue
  sync_item "$file" ".claude/agents/$(basename "$file")"
done

echo ".gitignore"
touch "$PROJECT/.gitignore"
for entry in "plans/" ".env.harness" ".harness/runs/"; do
  if grep -qxF "$entry" "$PROJECT/.gitignore"; then log "existe     $entry"; else
    printf '%s\n' "$entry" >> "$PROJECT/.gitignore"; log "añadido    $entry"
  fi
done

echo "Labels de GitHub"
if [ "$LABELS" -eq 0 ]; then
  log "omitido (--no-labels)"
elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 \
     && git -C "$PROJECT" remote get-url origin >/dev/null 2>&1; then
  for label in "needs grooming" "needs ui mock" "security" "critical"; do
    if (cd "$PROJECT" && gh label create "$label" --force >/dev/null 2>&1); then
      log "label      $label"
    else
      log "no se pudo crear el label '$label'"
    fi
  done
else
  log "omitido (falta gh con sesión iniciada o un remoto origin)"
fi

echo
echo "Listo. Rellena harness.config.yml, revisa .harness/model-mapping.yml y haz commit"
echo "de lo instalado para que cada clon y cada worktree lo tenga."
