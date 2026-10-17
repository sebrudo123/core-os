#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  95-diagnostico.sh — informe del estado del escritorio.
#
#  Instala la herramienta `core-os-diagnostico` y su servicio. En el MEDIO EN
#  VIVO el informe se escribe en la consola serie, así que se puede leer desde
#  las compilaciones de CI (que guardan esa consola en un archivo) o desde
#  cualquier servidor al que esté conectado el equipo.
#
#  Con esto se averigua en un vistazo por qué un equipo se queda en la pantalla
#  de saludo en vez de entrar al escritorio, sin necesidad de tenerlo delante.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

# --- 1. Herramienta --------------------------------------------------------
log "Instalando la herramienta de diagnóstico…"
cat > /usr/local/bin/core-os-diagnostico <<'EOF'
#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  core-os-diagnostico — informe del estado del escritorio de Core OS.
#
#  Recoge en un solo texto todo lo necesario para averiguar por qué un equipo
#  no muestra la sesión gráfica: servicios fallidos, sesiones de usuario,
#  dispositivos gráficos y los errores del diario relacionados con el
#  escritorio.
#
#  Uso:
#      sudo core-os-diagnostico                 # informe ahora mismo
#      sudo core-os-diagnostico --seguimiento   # dos informes (60 s y 120 s)
# ---------------------------------------------------------------------------
set -uo pipefail

LOG_DIR=/var/log/core-os
LOG_FILE="${LOG_DIR}/diagnostico.txt"
PUERTO_SERIE=/dev/ttyS0

informe() {
    local ronda="$1"
    printf '\n'
    printf '==================== CORE OS - DIAGNOSTICO (%s) ====================\n' "$ronda"
    date '+fecha: %Y-%m-%d %H:%M:%S'
    printf '\n--- sistema ---\n'
    uname -srm
    printf 'procesadores: %s\n' "$(nproc)"
    printf 'linea de ordenes: %s\n' "$(cat /proc/cmdline)"
    if [ -d /run/archiso ]; then printf 'medio en vivo: si\n'; else printf 'medio en vivo: no\n'; fi

    printf '\n--- servicios fallidos ---\n'
    systemctl --no-pager --failed 2>&1 || true

    printf '\n--- sesiones de usuario ---\n'
    loginctl list-sessions --no-legend 2>&1 || true
    printf '\n--- eventos de sesion ---\n'
    journalctl -b --no-pager 2>&1 | grep -iE 'session|seat0|loginctl' | tail -20 || true

    printf '\n--- dispositivos graficos ---\n'
    ls -l /dev/dri 2>&1 || true

    printf '\n--- sesiones de escritorio instaladas ---\n'
    ls -1 /usr/share/wayland-sessions /usr/share/xsessions 2>&1 || true

    printf '\n--- gdm ---\n'
    systemctl --no-pager status gdm.service 2>&1 | head -20 || true

    printf '\n--- entrada automatica del medio en vivo ---\n'
    systemctl --no-pager status core-os-live-session.service 2>&1 | head -20 || true
    printf '\n--- registro de la entrada automatica ---\n'
    if [ -r /var/log/core-os/sesion-en-vivo.log ]; then
        tail -40 /var/log/core-os/sesion-en-vivo.log
    else
        printf '(todavia no hay registro) %s\n' /var/log/core-os/sesion-en-vivo.log
    fi

    printf '\n--- diario de gdm (final) ---\n'
    journalctl -b -u gdm.service --no-pager 2>&1 | tail -40 || true

    printf '\n--- diario del escritorio ---\n'
    journalctl -b --no-pager 2>&1 \
        | grep -iE 'gnome-shell|gnome-session|mutter|wayland|xorg|gdm-x-session|drm|llvmpipe|fail' \
        | tail -60 || true

    printf '\n--- diario: errores ---\n'
    journalctl -b -p err --no-pager 2>&1 | tail -25 || true

    printf '\n--- usuario del medio en vivo ---\n'
    getent passwd core 2>&1 || true
    ls -ld /home/core 2>&1 || true
    printf '\n================= FIN DEL DIAGNOSTICO (%s) =================\n\n' "$ronda"
}

publicar() {
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    if [ -w "$PUERTO_SERIE" ]; then
        informe "$1" | tee "$LOG_FILE" > "$PUERTO_SERIE" 2>/dev/null \
            || informe "$1" | tee "$LOG_FILE"
    else
        informe "$1" | tee "$LOG_FILE"
    fi
}

case "${1:-}" in
    --seguimiento)
        sleep 60
        publicar "primero"
        sleep 60
        publicar "segundo"
        ;;
    *)
        publicar "manual"
        ;;
esac
EOF
run chmod 0755 /usr/local/bin/core-os-diagnostico

# --- 2. Servicio -----------------------------------------------------------
UNIT_SRC="${CORE_OS_PAYLOAD}/systemd/core-os-diagnostico.service"
[ -f "$UNIT_SRC" ] || die "falta ${UNIT_SRC}"
log "Instalando core-os-diagnostico.service…"
run install -m 0644 "$UNIT_SRC" /etc/systemd/system/core-os-diagnostico.service
run systemctl enable core-os-diagnostico.service

ok "95-diagnostico.sh completado — el informe queda en /var/log/core-os/diagnostico.txt"
