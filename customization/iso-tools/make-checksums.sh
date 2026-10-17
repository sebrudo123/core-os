#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# make-checksums.sh — genera SHA256SUMS de las ISOs generadas.
# Uso:  ./make-checksums.sh [directorio_de_salida]
# ---------------------------------------------------------------------------
set -euo pipefail

OUT_DIR="${1:-$(cd "$(dirname "$0")/.." && pwd)/out}"

if [ ! -d "$OUT_DIR" ]; then
  echo "ERROR: no existe el directorio $OUT_DIR" >&2
  exit 1
fi

shopt -s nullglob
isos=("$OUT_DIR"/*.iso)
if [ "${#isos[@]}" -eq 0 ]; then
  echo "ERROR: no se encontraron archivos .iso en $OUT_DIR" >&2
  exit 1
fi

cd "$OUT_DIR"
sha256sum ./*.iso > SHA256SUMS
echo "Generado $OUT_DIR/SHA256SUMS:"
cat SHA256SUMS
