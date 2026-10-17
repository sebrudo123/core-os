#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 38-live-user.sh — usuario de la SESIÓN EN VIVO de Core OS.
#
# Ubuntu crea el usuario del medio en vivo con casper
# (scripts/casper-bottom/25adduser -> user-setup-apply). En nuestra
# remasterización ese paso falla (el usuario no llega a existir), así que GDM
# mostraba la pantalla de inicio de sesión y nadie podía entrar: el escritorio
# nunca aparecía.
#
# Para no depender de ese mecanismo, aquí creamos nosotros el usuario del medio
# en vivo y activamos el autologin. El instalador borra este usuario (y el
# autologin) del sistema final.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root

LIVE_USER="${CORE_OS_LIVE_USER:-core}"
LIVE_PASS="${CORE_OS_LIVE_PASS:-core}"
LIVE_HOST="${CORE_OS_LIVE_HOST:-core-os}"

# --- Usuario ----------------------------------------------------------------
log "Creando el usuario de la sesión en vivo: $LIVE_USER"
if id "$LIVE_USER" >/dev/null 2>&1; then
  warn "el usuario $LIVE_USER ya existe; no se crea"
else
  # UID 1000: el mismo que casper espera para el usuario del medio en vivo.
  run adduser --uid 1000 --disabled-password \
    --gecos "Core OS" "$LIVE_USER"
fi
run usermod -aG sudo,adm,audio,video,plugdev,netdev,cdrom,dip,lpadmin \
  "$LIVE_USER" || warn "no se pudieron añadir todos los grupos a $LIVE_USER"
run usermod -s /bin/bash "$LIVE_USER" || true
printf '%s:%s\n' "$LIVE_USER" "$LIVE_PASS" | run chpasswd || \
  warn "no se pudo fijar la contraseña de $LIVE_USER"

# sudo sin contraseña para la sesión en vivo (cómodo y es un medio efímero).
install -d -m 0755 /etc/sudoers.d
cat > /etc/sudoers.d/90-core-os-live <<EOF
# Core OS — el usuario del medio en vivo puede administrar sin contraseña.
$LIVE_USER ALL=(ALL) NOPASSWD:ALL
EOF
chmod 0440 /etc/sudoers.d/90-core-os-live

# --- casper: mismo usuario/host (y no el "ubuntu" por defecto) --------------
cat > /etc/casper.conf <<EOF
# Core OS — configuración del sistema en vivo
export USERNAME="$LIVE_USER"
export USERFULLNAME="Core OS Live Session"
export HOST="$LIVE_HOST"
export BUILD_SYSTEM="Core OS"
EOF

# --- Hostname ---------------------------------------------------------------
printf '%s\n' "$LIVE_HOST" > /etc/hostname
if [ -f /etc/hosts ]; then
  sed -i "s/^127\.0\.1\.1.*/127.0.1.1\t$LIVE_HOST/" /etc/hosts || true
  grep -q "$LIVE_HOST" /etc/hosts || \
    printf '127.0.1.1\t%s\n' "$LIVE_HOST" >> /etc/hosts
fi

# --- Autologin (GDM) --------------------------------------------------------
if [ -d /etc/gdm3 ]; then
  log "Activando el inicio de sesión automático ($LIVE_USER)"
  cat > /etc/gdm3/custom.conf <<EOF
# Core OS — escritorio en vivo: entra automáticamente.
# El instalador deja este archivo sin autologin en el sistema final.
[daemon]
AutomaticLoginEnable=true
AutomaticLogin=$LIVE_USER
EOF
else
  warn "no hay /etc/gdm3; no se configura el autologin"
fi

ok "usuario en vivo listo: $LIVE_USER"
