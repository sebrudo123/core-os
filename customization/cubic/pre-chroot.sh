#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# cubic/pre-chroot.sh — hook de ejemplo para Cubic (se ejecuta ANTES del chroot).
# Cubic ejecuta hooks desde la carpeta del proyecto. Enlaza este archivo si tu
# versión de Cubic soporta hooks de proyecto.
# ---------------------------------------------------------------------------
set -euo pipefail

echo "[core-os][cubic] pre-chroot: preparando personalización..."

CUSTOMIZATION_SRC="${CUSTOMIZATION_SRC:-$(dirname "$0")/..}"

if [ ! -d "$CUSTOMIZATION_SRC/scripts" ]; then
  echo "[core-os][cubic] ERROR: no se encuentra customization/scripts" >&2
  exit 1
fi

# Verificación rápida de las listas de paquetes antes de entrar al chroot.
for f in "$CUSTOMIZATION_SRC"/packages/*.list; do
  [ -f "$f" ] || continue
  echo "[core-os][cubic] lista: $f ($(grep -cvE '^\s*(#|$)' "$f") entradas)"
done

echo "[core-os][cubic] pre-chroot OK"
