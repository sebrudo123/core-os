#!/usr/bin/env bash
# ===========================================================================
#  publish-to-github.sh — Crea el repositorio en GitHub y sube Core OS.
#
#  Uso:
#    GITHUB_TOKEN=ghp_xxx ./scripts/publish-to-github.sh <owner> [repo] [visibilidad]
#
#  Ejemplos:
#    GITHUB_TOKEN=ghp_xxx ./scripts/publish-to-github.sh mi-usuario
#    GITHUB_TOKEN=ghp_xxx ./scripts/publish-to-github.sh mi-org core-os private
#
#  El token necesita permiso para crear repositorios:
#    - Token clásico: scope "repo"
#    - Token fine-grained: Administration (read/write) + Contents (read/write)
# ===========================================================================
set -euo pipefail

OWNER="${1:-}"
REPO="${2:-core-os}"
VISIBILITY="${3:-public}"

[ -n "$OWNER" ] || { echo "ERROR: indica el owner (usuario u organización). Ej: $0 mi-usuario" >&2; exit 1; }
[ -n "${GITHUB_TOKEN:-}" ] || { echo "ERROR: exporta GITHUB_TOKEN antes de ejecutar." >&2; exit 1; }

command -v curl >/dev/null 2>&1 || { echo "ERROR: se requiere curl." >&2; exit 1; }

echo "[publish] Verificando autenticación..."
LOGIN="$(curl -fsS -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/user | sed -n 's/.*"login":[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)"
[ -n "$LOGIN" ] || { echo "ERROR: token inválido o sin permisos." >&2; exit 1; }
echo "[publish] Autenticado como: $LOGIN"

# El endpoint depende de si el owner es el propio usuario o una organización.
if [ "$LOGIN" = "$OWNER" ]; then
  API="https://api.github.com/user/repos"
else
  API="https://api.github.com/orgs/${OWNER}/repos"
fi

echo "[publish] Creando repositorio ${OWNER}/${REPO} (${VISIBILITY})..."
HTTP_CODE="$(curl -sS -o /tmp/gh-create.json -w '%{http_code}' \
  -X POST "$API" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Accept: application/vnd.github+json" \
  -d "{\"name\":\"${REPO}\",\"private\":$( [ "$VISIBILITY" = private ] && echo true || echo false ),\"description\":\"Core OS — distribución personalizada de Ubuntu con Modo Demo Web para administradores\",\"auto_init\":false}")"

case "$HTTP_CODE" in
  201) echo "[publish] Repositorio creado." ;;
  422) echo "[publish] El repositorio ya existe; continúo con el push." ;;
  *)   echo "ERROR: GitHub respondió $HTTP_CODE" >&2; cat /tmp/gh-create.json >&2; exit 1 ;;
esac

echo "[publish] Configurando remoto origin..."
git remote remove origin 2>/dev/null || true
git remote add origin "https://${GITHUB_TOKEN}@github.com/${OWNER}/${REPO}.git"

echo "[publish] Subiendo la rama main..."
git push -u origin main

echo "[publish] Listo: https://github.com/${OWNER}/${REPO}"
echo "[publish] Recuerda revocar el token si era temporal."
