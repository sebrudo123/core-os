#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 20-gnome-theme.sh — aplica tema, ajustes de GNOME y extensiones.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root
export DEBIAN_FRONTEND=noninteractive

GNOME_DIR="${CUSTOMIZATION_DIR}/gnome"
DCONF_SRC="${GNOME_DIR}/dconf/core-os.dconf"
GSCHEMA_SRC="${GNOME_DIR}/99-core-os.gschema.override"
EXT_FILE="${GNOME_DIR}/extensions.list"

# --- 1. Valores por defecto a nivel de sistema (gschema override) -----------
if [ -f "$GSCHEMA_SRC" ]; then
  log "Instalando valores por defecto de GNOME (gschema override)..."
  run install -D -m 0644 "$GSCHEMA_SRC" \
    /usr/share/glib-2.0/schemas/99-core-os.gschema.override
  run glib-compile-schemas /usr/share/glib-2.0/schemas
else
  warn "no se encontró $GSCHEMA_SRC, se omite el override de eschemas"
fi

# --- 2. Base de datos dconf de sistema --------------------------------------
if [ -f "$DCONF_SRC" ]; then
  log "Configurando dconf de sistema..."
  run install -D -m 0644 "$DCONF_SRC" /etc/dconf/db/local.d/00-core-os
  # El perfil hace que los ajustes de sistema se apliquen sobre los del usuario
  if [ ! -f /etc/dconf/profile/user ]; then
    run install -D -m 0644 /dev/null /etc/dconf/profile/user
    cat > /etc/dconf/profile/user <<'EOF'
user-db:user
system-db:local
EOF
  fi
  run dconf update || warn "dconf update no disponible (normal en chroot sin dbus)"
else
  warn "no se encontró $DCONF_SRC, se omite la configuración dconf"
fi

# --- 3. Extensiones de GNOME Shell -----------------------------------------
# Formato de extensions.list:  <paquete-apt>|<uuid-extension>
if [ -f "$EXT_FILE" ]; then
  ENABLED_UUIDS=()
  while IFS='|' read -r pkg uuid; do
    pkg="$(echo "${pkg:-}" | tr -d '[:space:]')"
    uuid="$(echo "${uuid:-}" | tr -d '[:space:]')"
    [ -z "$pkg" ] && continue
    case "$pkg" in \#*) continue ;; esac
    if [ -n "$uuid" ]; then ENABLED_UUIDS+=("$uuid"); fi
    log "Instalando extensión: $pkg"
    run apt-get install -y --no-install-recommends "$pkg" || warn "no se pudo instalar $pkg"
  done < "$EXT_FILE"

  if [ "${#ENABLED_UUIDS[@]}" -gt 0 ]; then
    log "Habilitando extensiones: ${ENABLED_UUIDS[*]}"
    LIST="$(printf "'%s'," "${ENABLED_UUIDS[@]}")"
    LIST="[${LIST%,}]"
    run dconf write /org/gnome/shell/enabled-extensions "$LIST" \
      || warn "no se pudieron habilitar extensiones (chroot sin sesión GNOME)"
  fi
fi

log "20-gnome-theme.sh completado"
