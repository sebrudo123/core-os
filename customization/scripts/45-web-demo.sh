#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 45-web-demo.sh — Instala el Modo Demo Web (panel de administración) como
# parte de Core OS, para que funcione IGUAL que la versión desplegada en la web
# pero con las métricas REALES del sistema instalado.
#
# Deja el panel escuchando en http://<host>:8080 tras el arranque.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

WEB_SRC="${CORE_OS_WEB_DEMO_SRC:-/opt/core-os/web-demo}"
WEB_DEST="/usr/lib/core-os/web-demo"
LOG_DIR="/var/log/core-os"
PORT="${CORE_OS_WEB_DEMO_PORT:-8080}"
UNIT_SRC="${CUSTOMIZATION_DIR}/systemd/core-os-web-demo.service"

[ -d "$WEB_SRC" ] || die "no se encontró el panel web en $WEB_SRC (¿se copió web-demo/ al chroot?)"

# ---------------------------------------------------------------------------
# 1. Node.js >= 20 (NodeSource con fallback al paquete de Ubuntu)
# ---------------------------------------------------------------------------
node_major() {
  command -v node >/dev/null 2>&1 && node -p 'process.versions.node.split(".")[0]' 2>/dev/null || echo 0
}

install_node() {
  if [ "$(node_major)" -ge 20 ]; then
    log "Node.js $(node -v) ya instalado"
    return 0
  fi

  log "Instalando Node.js 20 desde NodeSource..."
  run apt-get install -y --no-install-recommends ca-certificates curl gnupg
  run install -d -m 0755 /etc/apt/keyrings

  if [ "$CORE_OS_DRY_RUN" = "1" ]; then
    log "DRY-RUN: configuración de NodeSource omitida"
  else
    if curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key \
        | gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg; then
      echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_20.x nodistro main" \
        > /etc/apt/sources.list.d/nodesource.list
      apt-get update -y
      apt-get install -y nodejs || warn "fallo NodeSource, probando nodejs de Ubuntu"
    else
      warn "no se pudo obtener la clave de NodeSource"
    fi
  fi

  # Fallback: nodejs del repositorio de Ubuntu (18.x). La app funciona en >=18.
  if [ "$(node_major)" -lt 18 ]; then
    run apt-get install -y --no-install-recommends nodejs npm
  fi

  ok "Node.js disponible: $(node -v 2>/dev/null || echo 'n/d')"
}

install_node

# ---------------------------------------------------------------------------
# 2. Copia la aplicación y sus dependencias de producción
# ---------------------------------------------------------------------------
log "Instalando el panel web en $WEB_DEST ..."
run install -d -m 0755 "$WEB_DEST"
run rsync -a --delete --exclude 'node_modules' --exclude '.vercel' \
  "$WEB_SRC/" "$WEB_DEST/"

log "Instalando dependencias de producción (npm)..."
run npm --prefix "$WEB_DEST" install --omit=dev --no-audit --no-fund

# Los logs de compilación viven en /var/log/core-os
run install -d -m 0755 "$LOG_DIR"
if [ "$CORE_OS_DRY_RUN" != "1" ]; then
  mkdir -p "$WEB_DEST/data"
  rm -rf "$WEB_DEST/data/logs"
  ln -sfn "$LOG_DIR" "$WEB_DEST/data/logs"
fi

# ---------------------------------------------------------------------------
# 3. Configuración (/etc/core-os/web-demo.env)
# ---------------------------------------------------------------------------
log "Escribiendo configuración en /etc/core-os/web-demo.env ..."
run install -d -m 0755 /etc/core-os
if [ "$CORE_OS_DRY_RUN" = "1" ]; then
  log "DRY-RUN: se escribiría /etc/core-os/web-demo.env (PORT=${PORT}, DEMO_MODE=false, ALLOW_TERMINAL=true)"
else
  cat > /etc/core-os/web-demo.env <<EOF
# Generado por Core OS ${CORE_OS_RELEASE}
PORT=${PORT}
# false = métricas REALES del sistema instalado (idéntico al panel de la web)
DEMO_MODE=false
# true = habilita la terminal web (lista blanca de comandos de solo lectura)
ALLOW_TERMINAL=true
GITHUB_REPO=
GITHUB_BRANCH=main
CORE_OS_RELEASE=${CORE_OS_RELEASE}
CORE_OS_BASE=Ubuntu ${UBUNTU_RELEASE} LTS (${UBUNTU_CODENAME})
LOG_LEVEL=info
EOF
  chmod 0644 /etc/core-os/web-demo.env
fi

# ---------------------------------------------------------------------------
# 4. Servicio systemd
# ---------------------------------------------------------------------------
if [ -f "$UNIT_SRC" ]; then
  log "Instalando la unidad systemd core-os-web-demo.service ..."
  run install -D -m 0644 "$UNIT_SRC" /etc/systemd/system/core-os-web-demo.service
else
  warn "no se encontró $UNIT_SRC"
fi

# ---------------------------------------------------------------------------
# 5. Habilita el servicio y abre el puerto
# ---------------------------------------------------------------------------
log "Habilitando el servicio en el arranque..."
run systemctl enable core-os-web-demo.service || warn "no se pudo habilitar el servicio"

if command -v ufw >/dev/null 2>&1; then
  log "Permitiendo el puerto ${PORT}/tcp en UFW..."
  run ufw allow "${PORT}/tcp" || warn "no se pudo abrir el puerto en UFW"
fi

ok "Panel web de Core OS instalado. Tras el arranque: http://<host>:${PORT}"
log "45-web-demo.sh completado"
