#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  45-web-demo.sh — panel de administración de Core OS.
#
#  Instala el panel (la misma aplicación Node que se despliega en la web) DENTRO
#  del sistema, como servicio de systemd, para que el Core OS instalado tenga
#  exactamente las mismas funciones que la versión de demostración, pero con
#  las métricas REALES del equipo (DEMO_MODE=false).
#
#  Queda escuchando en http://<equipo>:8080
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

WEB_SRC="${CORE_OS_PAYLOAD}/web-demo"
WEB_DEST="/usr/lib/core-os/web-demo"

[ -d "$WEB_SRC" ] || die "no se encontró el panel en ${WEB_SRC}"

# --- 1. Node.js ------------------------------------------------------------
command -v node >/dev/null 2>&1 || die "no se encontró Node.js (falta el paquete nodejs)"
log "Node.js disponible: $(node --version)"

# --- 2. Aplicación ---------------------------------------------------------
log "Instalando el panel en ${WEB_DEST}…"
run install -d -m 0755 "$WEB_DEST"
run rsync -a --delete --exclude 'node_modules' --exclude '.git' --exclude '.render' \
    "$WEB_SRC/" "$WEB_DEST/"

log "Instalando las dependencias de producción (npm)…"
run npm --prefix "$WEB_DEST" install --omit=dev --no-audit --no-fund

run install -d -m 0755 /var/log/core-os
if [ -d "$WEB_DEST/data" ]; then
    rm -rf "$WEB_DEST/data/logs"
    ln -sfn /var/log/core-os "$WEB_DEST/data/logs"
fi

# --- 3. Configuración ------------------------------------------------------
log "Escribiendo /etc/core-os/web-demo.env…"
cat > /etc/core-os/web-demo.env <<EOF
# Core OS — configuración del panel de administración.
# Generado por customization/arch/scripts/45-web-demo.sh
PORT=${CORE_OS_WEB_DEMO_PORT}
# false = métricas REALES de este equipo (el despliegue web usa true)
DEMO_MODE=false
# Terminal web con una lista blanca de comandos de solo lectura
ALLOW_TERMINAL=true
GITHUB_REPO=sebrudo123/core-os
GITHUB_BRANCH=main
CORE_OS_RELEASE=${CORE_OS_RELEASE}
CORE_OS_BASE=${CORE_OS_BASE}
LOG_LEVEL=info
EOF
run chmod 0644 /etc/core-os/web-demo.env

# --- 4. Servicio de systemd ------------------------------------------------
UNIT_SRC="${CORE_OS_PAYLOAD}/systemd/core-os-web-demo.service"
[ -f "$UNIT_SRC" ] || die "falta ${UNIT_SRC}"
log "Instalando core-os-web-demo.service…"
run install -m 0644 "$UNIT_SRC" /etc/systemd/system/core-os-web-demo.service

ok "45-web-demo.sh completado — el panel quedará en http://localhost:${CORE_OS_WEB_DEMO_PORT}"
