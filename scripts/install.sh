#!/usr/bin/env bash
# Conecta el harness idea2prod con un proyecto. Todo queda DENTRO del proyecto:
# no escribe nada en ~/.claude, ~/.agents ni en otro lugar del usuario.
#
# Uso: install.sh [--update | --check] [--copy] [--no-labels] [DIR]
#   DIR          raíz del proyecto (por defecto, el directorio actual)
#   --update     refresca skills y roles del harness y avisa si las reglas difieren
#   --check      no escribe nada: muestra qué cambiaría un --update (sale con 1 si hay)
#   --copy       en vez de symlinks, copia las skills a .claude/ y .agents/
#                (para entornos sin symlinks, p. ej. Windows); solo en la 1.ª instalación
#   --no-labels  no crea labels en GitHub
#
# Por defecto hay UNA copia real en .harness/skills y .harness/roles; .claude/ y
# .agents/ apuntan a ella con symlinks relativos (git los versiona y los recrea en
# cada worktree). No edites .harness/skills ni .harness/roles: --update los reemplaza.
# Lo que el proyecto ya tenía (p. ej. una skill propia con el mismo nombre) no se toca.
set -euo pipefail

HARNESS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ACTION="install"
WANT_COPY=0
LABELS=1
PROJECT=""

usage() { sed -n '2,17p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

for arg in "$@"; do
  case "$arg" in
    --update) ACTION="update" ;;
    --check) ACTION="check" ;;
    --copy) WANT_COPY=1 ;;
    --no-labels) LABELS=0 ;;
    -h|--help) usage; exit 0 ;;
    -*) echo "Opción desconocida: $arg" >&2; usage >&2; exit 2 ;;
    *) PROJECT="$arg" ;;
  esac
done

PROJECT="$(cd "${PROJECT:-$PWD}" && pwd)"
VERSION_FILE="$PROJECT/.harness/version"
COPIES_FILE="$PROJECT/.harness/copies.txt"

git -C "$PROJECT" rev-parse --git-dir >/dev/null 2>&1 \
  || { echo "$PROJECT no es un repositorio git." >&2; exit 1; }

log() { printf '  %s\n' "$*"; }

version_get() { [ -f "$VERSION_FILE" ] && sed -n "s/^$1=//p" "$VERSION_FILE" | head -n1 || true; }

harness_commit() {
  local c
  c="$(git -C "$HARNESS" rev-parse --short HEAD 2>/dev/null || echo unknown)"
  if [ -n "$(git -C "$HARNESS" status --porcelain 2>/dev/null)" ]; then c="$c-dirty"; fi
  printf '%s' "$c"
}

# El modo (link|copy) queda fijado en la primera instalación.
MODE="$(version_get mode)"
if [ -z "$MODE" ]; then
  if [ "$WANT_COPY" -eq 1 ]; then MODE="copy"; else MODE="link"; fi
elif [ "$WANT_COPY" -eq 1 ] && [ "$MODE" != "copy" ]; then
  echo "Este proyecto ya se instaló con symlinks; --copy solo vale en la primera instalación." >&2
  exit 2
fi

# Plantillas que el proyecto hace suyas al instalar: nunca se sobrescriben.
TEMPLATE_PAIRS=(
  "AGENTS.project.md AGENTS.md"
  "CLAUDE.project.md CLAUDE.md"
  "model-mapping.yml .harness/model-mapping.yml"
  "pr.md .github/PULL_REQUEST_TEMPLATE.md"
  "ticket.md .github/ISSUE_TEMPLATE/feature.md"
)

report_template_drift() {
  local pair tpl rel n
  echo "Reglas y plantillas del proyecto (informativo: son tuyas, no se sobrescriben)"
  for pair in "${TEMPLATE_PAIRS[@]}"; do
    tpl="${pair%% *}"; rel="${pair#* }"
    if [ ! -e "$PROJECT/$rel" ]; then log "falta      $rel"
    elif cmp -s "$HARNESS/templates/$tpl" "$PROJECT/$rel"; then log "igual      $rel"
    else
      n="$(diff "$HARNESS/templates/$tpl" "$PROJECT/$rel" | grep -c '^[<>]' || true)"
      log "difiere    $rel ($n líneas)  →  diff -u $PROJECT/$rel $HARNESS/templates/$tpl"
    fi
  done
}

skill_names() { for d in "$HARNESS"/skills/*/; do [ -f "$d/SKILL.md" ] && basename "$d"; done; }
role_files() { for f in "$HARNESS"/roles/*.md; do [ -f "$f" ] && basename "$f"; done; }

# ---------------------------------------------------------------- --check
if [ "$ACTION" = "check" ]; then
  if [ ! -f "$VERSION_FILE" ]; then
    echo "El harness no está instalado en $PROJECT (falta .harness/version)."; exit 1
  fi
  drift=0
  installed="$(version_get commit)"; current="$(harness_commit)"
  echo "Proyecto: $PROJECT   (modo: $MODE)"
  echo "Versión instalada: ${installed:-?}   Versión del harness: $current"
  [ "$installed" = "$current" ] || drift=1
  echo "Skills y roles"
  if [ "$MODE" = "link" ]; then
    for sub in skills roles; do
      if [ ! -d "$PROJECT/.harness/$sub" ]; then log "falta      .harness/$sub"; drift=1
      elif ! diff -rq "$HARNESS/$sub" "$PROJECT/.harness/$sub" >/dev/null 2>&1; then
        log "cambió     .harness/$sub"; diff -rq "$HARNESS/$sub" "$PROJECT/.harness/$sub" 2>&1 | sed 's/^/             /'; drift=1
      else log "al día     .harness/$sub"; fi
    done
  else
    for name in $(skill_names); do
      for base in .claude/skills .agents/skills; do
        if [ ! -d "$PROJECT/$base/$name" ]; then log "falta      $base/$name"; drift=1
        elif ! diff -rq "$HARNESS/skills/$name" "$PROJECT/$base/$name" >/dev/null 2>&1; then log "cambió     $base/$name"; drift=1
        else log "al día     $base/$name"; fi
      done
    done
    for f in $(role_files); do
      if [ ! -f "$PROJECT/.claude/agents/$f" ] || ! cmp -s "$HARNESS/roles/$f" "$PROJECT/.claude/agents/$f"; then
        log "cambió     .claude/agents/$f"; drift=1
      else log "al día     .claude/agents/$f"; fi
    done
  fi
  report_template_drift
  if [ "$drift" -eq 1 ]; then echo; echo "Hay cambios pendientes: corre install.sh --update."; else echo; echo "Todo al día."; fi
  exit "$drift"
fi

# ---------------------------------------------------------------- install / update
if [ "$ACTION" = "update" ] && [ ! -f "$VERSION_FILE" ]; then
  echo "Este proyecto no tiene .harness/version: corre install.sh sin --update primero." >&2; exit 1
fi

put() { # origen-en-templates destino-relativo
  local src="$HARNESS/templates/$1" dst="$PROJECT/$2"
  if [ -e "$dst" ]; then log "existe     $2"; return; fi
  mkdir -p "$(dirname "$dst")"; cp "$src" "$dst"; log "creado     $2"
}

# Reemplaza por completo .harness/<sub> con el del harness (la carpeta entera es del harness).
sync_harness_dir() { # skills|roles
  local sub="$1" dst="$PROJECT/.harness/$1"
  if [ -d "$dst" ] && [ "$ACTION" != "update" ]; then log "existe     .harness/$sub"; return; fi
  [ -n "$sub" ] || return 1
  local verb="creado"; if [ "$ACTION" = "update" ]; then verb="actualizado"; fi
  rm -rf "$dst"; mkdir -p "$PROJECT/.harness"; cp -R "$HARNESS/$sub" "$dst"
  find "$dst" -name '.DS_Store' -delete 2>/dev/null || true
  log "$(printf '%-10s' "$verb") .harness/$sub"
}

link_item() { # destino-relativo  objetivo-del-symlink
  local rel="$1" target="$2" dst="$PROJECT/$1"
  if [ -L "$dst" ]; then
    if [ "$(readlink "$dst")" = "$target" ]; then log "existe     $rel"; else log "omitido    $rel (symlink de otro origen)"; fi
    return
  fi
  if [ -e "$dst" ]; then log "omitido    $rel (ya existe y no es del harness)"; return; fi
  mkdir -p "$(dirname "$dst")"; ln -s "$target" "$dst"; log "enlazado   $rel"
}

copy_item() { # origen destino-relativo
  local src="$1" rel="$2" dst="$PROJECT/$2"
  [ -n "$rel" ] || return 1
  if [ -e "$dst" ]; then
    if [ -f "$COPIES_FILE" ] && grep -qxF "$rel" "$COPIES_FILE"; then
      if [ "$ACTION" = "update" ]; then rm -rf "$dst"; cp -R "$src" "$dst"; log "actualizado $rel"; else log "existe     $rel"; fi
    else log "omitido    $rel (ya existe y no es del harness)"; fi
    return
  fi
  mkdir -p "$(dirname "$dst")" "$PROJECT/.harness"; cp -R "$src" "$dst"
  printf '%s\n' "$rel" >> "$COPIES_FILE"; log "copiado    $rel"
}

# Quita symlinks del harness cuyo destino ya no existe (skills o roles eliminados).
prune_stale_links() {
  local l
  for l in "$PROJECT"/.claude/skills/* "$PROJECT"/.agents/skills/* "$PROJECT"/.claude/agents/*; do
    if [ -L "$l" ] && [[ "$(readlink "$l")" == ../../.harness/* ]] && [ ! -e "$l" ]; then
      rm -f "$l"; log "eliminado  ${l#"$PROJECT"/} (ya no existe en el harness)"
    fi
  done
}

echo "Proyecto: $PROJECT   (modo: $MODE)"
echo "Harness:  $HARNESS ($(harness_commit))"

echo "Archivos del proyecto"
put AGENTS.project.md AGENTS.md
put CLAUDE.project.md CLAUDE.md
put harness.config.yml harness.config.yml
put model-mapping.yml .harness/model-mapping.yml
put pr.md .github/PULL_REQUEST_TEMPLATE.md
put ticket.md .github/ISSUE_TEMPLATE/feature.md

echo "Skills y roles"
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
fi

mkdir -p "$PROJECT/.harness"
printf 'commit=%s\nmode=%s\n' "$(harness_commit)" "$MODE" > "$VERSION_FILE"
log "versión    $(harness_commit)"

echo ".gitignore"
touch "$PROJECT/.gitignore"
for entry in "plans/" ".env.harness" ".harness/runs/"; do
  if grep -qxF "$entry" "$PROJECT/.gitignore"; then log "existe     $entry"; else
    printf '%s\n' "$entry" >> "$PROJECT/.gitignore"; log "añadido    $entry"
  fi
done

if [ "$ACTION" = "install" ]; then
  echo "Labels de GitHub"
  if [ "$LABELS" -eq 0 ]; then
    log "omitido (--no-labels)"
  elif command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1 \
       && git -C "$PROJECT" remote get-url origin >/dev/null 2>&1; then
    for label in "needs grooming" "needs ui mock" "security" "critical"; do
      if (cd "$PROJECT" && gh label create "$label" --force >/dev/null 2>&1); then log "label      $label"
      else log "no se pudo crear el label '$label'"; fi
    done
  else
    log "omitido (falta gh con sesión iniciada o un remoto origin)"
  fi
else
  report_template_drift
fi

echo
echo "Listo. Revisa los cambios con git y haz commit de lo instalado: así cada clon y"
echo "cada worktree trae las skills. Rellena harness.config.yml si es una instalación nueva."
