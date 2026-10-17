#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# cubic/post-chroot.sh — hook de ejemplo para Cubic (después del chroot).
# Deja la ISO lista: limpia artefactos y verifica la identidad del sistema.
# ---------------------------------------------------------------------------
set -euo pipefail

echo "[core-os][cubic] post-chroot: verificando branding..."

if [ -r /etc/os-release ]; then
  echo "[core-os][cubic] /etc/os-release:"
  grep -E '^(NAME|PRETTY_NAME|VERSION_ID)=' /etc/os-release || true
else
  echo "[core-os][cubic] aviso: /etc/os-release no legible" >&2
fi

# Limpieza final dentro del chroot de Cubic.
rm -rf /tmp/* /var/tmp/* 2>/dev/null || true
apt-get clean 2>/dev/null || true

echo "[core-os][cubic] post-chroot OK"
