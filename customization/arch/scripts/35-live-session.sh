#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  35-live-session.sh — que el medio en vivo entre SOLO al escritorio.
#
#  GDM abre la sesión automática en cuanto arranca. En algunos equipos (y sobre
#  todo en máquinas virtuales) eso pasa antes de que la parte gráfica esté del
#  todo lista: la sesión se pierde y el equipo se queda en la pantalla de
#  saludo. Al intentarlo un poco más tarde sí funciona, que es justo lo que
#  ocurre cuando se escribe la contraseña a mano.
#
#  Aquí se instala un servicio que, solo en el medio en vivo, comprueba durante
#  los primeros minutos si hay escritorio y, si no lo hay, le pide a GDM que lo
#  vuelva a intentar.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

# --- 1. Herramienta --------------------------------------------------------
log "Instalando el vigilante de la sesión en vivo…"
cat > /usr/local/bin/core-os-live-session <<EOF
#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  core-os-live-session — asegura que el escritorio del medio en vivo se vea.
#
#  Se ejecuta una sola vez al arrancar el medio en vivo. Si no hay ninguna
#  sesión de escritorio activa, reinicia GDM (que vuelve a entrar solo con el
#  usuario ${CORE_OS_LIVE_USER}). En cuanto hay escritorio, termina sin tocar
#  nada.
# ---------------------------------------------------------------------------
set -uo pipefail
USUARIO="${CORE_OS_LIVE_USER}"
REGISTRO=/var/log/core-os/sesion-en-vivo.log

anotar() {
    mkdir -p "\$(dirname "\$REGISTRO")" 2>/dev/null || true
    printf '%s  %s\n' "\$(date '+%H:%M:%S')" "\$*" | tee -a "\$REGISTRO"
}

sesion_grafica_activa() {
    local id clase estado
    while read -r id _; do
        [ -n "\${id:-}" ] || continue
        clase=\$(loginctl show-session "\$id" -p Class --value 2>/dev/null || true)
        estado=\$(loginctl show-session "\$id" -p Active --value 2>/dev/null || true)
        [ "\$clase" = "user" ] && [ "\$estado" = "yes" ] && return 0
    done < <(loginctl list-sessions --no-legend 2>/dev/null || true)
    return 1
}

for intento in 1 2 3 4; do
    sleep 20
    if sesion_grafica_activa; then
        anotar "escritorio activo del usuario \$USUARIO (comprobación \$intento)"
        exit 0
    fi
    anotar "sin escritorio activo: se reinicia GDM (intento \$intento)"
    systemctl restart gdm.service
done

anotar "GDM no ha conseguido abrir el escritorio; revisa /var/log/core-os/diagnostico.txt"
exit 0
EOF
run chmod 0755 /usr/local/bin/core-os-live-session

# --- 2. Servicio -----------------------------------------------------------
UNIT_SRC="${CORE_OS_PAYLOAD}/systemd/core-os-live-session.service"
[ -f "$UNIT_SRC" ] || die "falta ${UNIT_SRC}"
log "Instalando core-os-live-session.service…"
run install -m 0644 "$UNIT_SRC" /etc/systemd/system/core-os-live-session.service
run systemctl enable core-os-live-session.service

ok "35-live-session.sh completado — el medio en vivo entra solo al escritorio"
