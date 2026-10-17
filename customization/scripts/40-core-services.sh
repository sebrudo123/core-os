#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 40-core-services.sh — servicios, usuario admin y preparación del 1er arranque.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root
export DEBIAN_FRONTEND=noninteractive

ADMIN_USER="${CORE_OS_ADMIN_USER:-coreadmin}"

# --- Servicios --------------------------------------------------------------
log "Habilitando servicios esenciales..."
enable_service() {
  local unit="$1"
  if systemctl list-unit-files 2>/dev/null | grep -q "^${unit}"; then
    run systemctl enable "$unit" || warn "no se pudo habilitar $unit"
  else
    warn "unidad $unit no encontrada, se omite"
  fi
}
enable_service ssh.service
enable_service docker.service
enable_service ufw.service
enable_service fail2ban.service

# --- Cortafuegos ------------------------------------------------------------
if command -v ufw >/dev/null 2>&1; then
  log "Configurando UFW (permite SSH)..."
  run ufw default deny incoming || true
  run ufw default allow outgoing || true
  run ufw allow OpenSSH || true
fi

# --- Usuario administrador --------------------------------------------------
if id "$ADMIN_USER" >/dev/null 2>&1; then
  log "El usuario $ADMIN_USER ya existe"
else
  log "Creando usuario administrador: $ADMIN_USER"
  # OJO: el medio en vivo crea el usuario `ubuntu` con UID 1000 (casper
  # fuerza `passwd/user-uid 1000`). Si ocupamos el 1000, el usuario en vivo NO
  # se crea, no hay autologin y la sesión gráfica no arranca. Por eso el admin
  # se crea a partir del 1500.
  run adduser --firstuid 1500 --disabled-password \
    --gecos "Core OS Administrator" "$ADMIN_USER" || true
  run usermod -aG sudo,adm,docker "$ADMIN_USER" || true
  # Contraseña inicial: se fuerza cambio en el primer inicio de sesión
  run chage -d 0 "$ADMIN_USER" || true
fi

# --- Primer arranque --------------------------------------------------------
log "Instalando script de primer arranque..."
run install -d -m 0755 /usr/lib/core-os /var/lib
cat > /usr/lib/core-os/first-boot.sh <<'EOF'
#!/usr/bin/env bash
# Se ejecuta UNA vez en el primer arranque de Core OS.
set -euo pipefail
mkdir -p /var/lib
touch /var/lib/core-os-first-boot.done 2>/dev/null || true
echo "[core-os] Bienvenido a Core OS. Primer arranque completado." \
  | tee -a /var/log/core-os-first-boot.log
EOF
run chmod 0755 /usr/lib/core-os/first-boot.sh

log "40-core-services.sh completado"
