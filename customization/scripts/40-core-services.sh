#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# 40-core-services.sh — servicios, usuario admin y preparación del 1er arranque.
# ---------------------------------------------------------------------------
set -euo pipefail
# shellcheck source=lib/common.sh
source "$(dirname "$0")/lib/common.sh"

require_root
export DEBIAN_FRONTEND=noninteractive

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
# Core OS NO crea aquí una cuenta de administrador: el medio en vivo usa su
# propio usuario (lo crea 38-live-user.sh con UID 1000) y el instalador crea la
# cuenta definitiva del sistema instalado (UID 1000). Crear aquí un usuario
# extra solo añadía una cuenta con sudo sin uso.
log "Cuentas: las gestionan 38-live-user.sh (medio en vivo) y el instalador."

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
