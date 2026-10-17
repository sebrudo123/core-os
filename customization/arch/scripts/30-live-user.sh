#!/usr/bin/env bash
# ---------------------------------------------------------------------------
#  30-live-user.sh — usuario de la SESIÓN EN VIVO de Core OS.
#
#  El sistema vive en un squashfs de solo lectura, así que archiso monta una
#  capa de escritura (overlay) y arranca como root en la consola. Para que el
#  usuario final vea un ESCRITORIO (y no una consola de root) se crea aquí el
#  usuario `core` con UID 1000 y se activa el inicio de sesión automático.
#
#  El instalador de Core OS elimina este usuario (y el autologin) del sistema
#  instalado: ver customization/setup/core-os-setup.py.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

# --- Usuario ---------------------------------------------------------------
if id "$CORE_OS_LIVE_USER" >/dev/null 2>&1; then
    warn "el usuario ${CORE_OS_LIVE_USER} ya existe; no se crea"
else
    log "Creando el usuario de la sesión en vivo: ${CORE_OS_LIVE_USER} (UID 1000)"
    run useradd --create-home --uid 1000 --shell /bin/bash \
        --comment "Core OS (Live)" "$CORE_OS_LIVE_USER"
fi

log "Añadiendo el usuario a los grupos del sistema…"
for grp in wheel audio video optical storage power network rfkill lp input kvm games users; do
    if getent group "$grp" >/dev/null 2>&1; then
        run usermod -aG "$grp" "$CORE_OS_LIVE_USER"
    fi
done

log "Fijando la contraseña del usuario en vivo…"
printf '%s:%s\n' "$CORE_OS_LIVE_USER" "$CORE_OS_LIVE_PASS" | run chpasswd

# sudo sin contraseña: es un medio efímero y facilita el diagnóstico.
run install -d -m 0755 /etc/sudoers.d
cat > /etc/sudoers.d/90-core-os-live <<EOF
# Core OS — el usuario del medio en vivo administra sin contraseña.
${CORE_OS_LIVE_USER} ALL=(ALL:ALL) NOPASSWD:ALL
EOF
run chmod 0440 /etc/sudoers.d/90-core-os-live

# --- Inicio de sesión automático ------------------------------------------
log "Activando el inicio de sesión automático de ${CORE_OS_LIVE_USER} en GDM…"
run install -d -m 0755 /etc/gdm
cat > /etc/gdm/custom.conf <<EOF
# Core OS — configuración de GDM.
# El MEDIO EN VIVO entra solo con el usuario ${CORE_OS_LIVE_USER}.
# El instalador deja este archivo sin autologin en el sistema final.
[daemon]
# Se usa la sesión de Xorg: funciona en cualquier equipo y en máquinas
# virtuales, donde la sesión de Wayland depende del controlador gráfico.
WaylandEnable=false
AutomaticLoginEnable=true
AutomaticLogin=${CORE_OS_LIVE_USER}

[security]

[xdmcp]

[chooser]

[debug]
EOF

# Consola de texto de respaldo en tty2 (por si el entorno gráfico falla) y
# consola serie para diagnóstico (la usa la vista previa en CI).
log "Configurando consolas de respaldo (tty2 y serie)…"
run install -d -m 0755 /etc/systemd/system/getty@tty2.service.d
cat > /etc/systemd/system/getty@tty2.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${CORE_OS_LIVE_USER} --noclear %I \$TERM
EOF

run install -d -m 0755 /etc/systemd/system/serial-getty@ttyS0.service.d
cat > /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin root --noclear %I 115200,38400,9600 linux
EOF

ok "30-live-user.sh completado"
