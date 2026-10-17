#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 35-debrand-ubuntu.sh — elimina la identidad de Ubuntu y aplica la de Core OS
# en el arranque: menú de GRUB, splash de Plymouth y pantalla de inicio de sesión.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root
export DEBIAN_FRONTEND=noninteractive

BRANDING_DIR="${CUSTOMIZATION_DIR}/branding"

# ===========================================================================
# 1. Menú de arranque (GRUB2)
# ===========================================================================
GRUB_THEME_DIR="/boot/grub/themes/core-os"
if [ -f "${BRANDING_DIR}/grub/theme.txt" ]; then
  log "Instalando el tema de arranque de Core OS (GRUB)..."
  run install -d -m 0755 "$GRUB_THEME_DIR"
  run cp -a "${BRANDING_DIR}/grub/." "$GRUB_THEME_DIR/"

  cat > /etc/default/grub <<'EOF'
# Core OS — configuración del gestor de arranque (GRUB)
GRUB_DEFAULT=0
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=10
GRUB_DISTRIBUTOR="Core OS"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
GRUB_THEME="/boot/grub/themes/core-os/theme.txt"
GRUB_GFXMODE=1920x1080,1280x720,auto
GRUB_GFXPAYLOAD_LINUX=keep
GRUB_DISABLE_OS_PROBER=false
GRUB_DISABLE_RECOVERY=true
EOF

  # Nombre del menú y opciones (el título "Ubuntu" -> "Core OS")
  if [ -f /etc/grub.d/00_header ]; then
    run sed -i 's/Ubuntu/Core OS/g' /etc/grub.d/00_header || true
  fi
  run update-grub 2>/dev/null || warn "update-grub no disponible en el chroot (se aplicará al instalar)"
else
  warn "no se encontró branding/grub/theme.txt"
fi

# ===========================================================================
# 2. Splash de arranque (Plymouth)
# ===========================================================================
PLYMOUTH_DIR="/usr/share/plymouth/themes/core-os"
if [ -f "${BRANDING_DIR}/plymouth/core-os.plymouth" ]; then
  log "Instalando el splash de arranque de Core OS (Plymouth)..."
  run install -d -m 0755 "$PLYMOUTH_DIR"
  run cp -a "${BRANDING_DIR}/plymouth/." "$PLYMOUTH_DIR/"

  run install -d -m 0755 /etc/plymouth
  if [ -f /etc/plymouth/plymouthd.conf ]; then
    if grep -q '^Theme=' /etc/plymouth/plymouthd.conf; then
      run sed -i 's/^Theme=.*/Theme=core-os/' /etc/plymouth/plymouthd.conf
    else
      printf 'Theme=core-os\n' >> /etc/plymouth/plymouthd.conf
    fi
  else
    printf '[Daemon]\nTheme=core-os\nShowDelay=0\n' > /etc/plymouth/plymouthd.conf
  fi

  # Registra el tema como alternativa y lo deja por defecto (si hay herramientas)
  if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    run plymouth-set-default-theme -R core-os || warn "no se pudo fijar el tema de Plymouth"
  elif [ -d /usr/share/plymouth/themes ]; then
    run ln -sfn "$PLYMOUTH_DIR" /usr/share/plymouth/themes/default 2>/dev/null || true
  fi

  run update-initramfs -u 2>/dev/null || warn "update-initramfs no disponible en el chroot"
else
  warn "no se encontró branding/plymouth/core-os.plymouth"
fi

# ===========================================================================
# 3. Pantalla de inicio de sesión (GDM)
# ===========================================================================
if [ -d /etc/gdm3 ]; then
  log "Aplicando la identidad de Core OS al inicio de sesión (GDM)..."
  cat > /etc/gdm3/greeter.dconf-defaults <<'EOF'
# Core OS — pantalla de inicio de sesión
[org/gnome/login-screen]
logo='/usr/share/pixmaps/core-os/core-os.png'
disable-user-list=false
banner-message-enable=false

[org/gnome/desktop/interface]
color-scheme='prefer-dark'
gtk-theme='Yaru-dark'
icon-theme='Yaru'

[org/gnome/desktop/background]
picture-uri='file:///usr/share/backgrounds/core-os/core-os-default.svg'
picture-options='zoom'
primary-color='#0B1220'

[org/gnome/desktop/screensaver]
picture-uri='file:///usr/share/backgrounds/core-os/core-os-default.svg'
EOF
fi

# ===========================================================================
# 4. Rastros visibles de Ubuntu -> Core OS
# ===========================================================================
log "Sustituyendo rastros visibles de Ubuntu..."
# Texto de bienvenida en consola
cat > /etc/motd <<EOF

  ${CORE_OS_NAME} ${CORE_OS_RELEASE}
  Panel de administración: http://localhost:8080
  Ajustes: gnome-control-center · Terminal: Ctrl+Alt+T

EOF

# Reemplaza logos de Ubuntu por el de Core OS (si existe el PNG)
if [ -f "${BRANDING_DIR}/logo/core-os.png" ]; then
  for logo in /usr/share/pixmaps/ubuntu-logo-text.png \
              /usr/share/pixmaps/ubuntu-logo-text-dark.png \
              /usr/share/pixmaps/ubuntu-logo-icon.png; do
    if [ -e "$logo" ] || [ -L "$logo" ]; then
      # Puede ser un symlink; se elimina para evitar "same file" al copiar.
      rm -f "$logo"
      run cp "${BRANDING_DIR}/logo/core-os.png" "$logo" 2>/dev/null || true
    fi
  done
fi

log "35-debrand-ubuntu.sh completado"
