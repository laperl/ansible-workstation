#!/usr/bin/env bash
set -euo pipefail
VERSION="${1:?Uso: ./release.sh vX.Y.Z}"
git checkout main
git fetch origin
git reset --hard origin/main

echo "==> Últimos cambios desde el tag previo:"
git log --oneline $(git describe --tags --abbrev=0 2>/dev/null)..HEAD || true

read -r -p "¿Crear tag $VERSION y publicar? [y/N] " ok
[[ "$ok" == "y" || "$ok" == "Y" ]] || exit 1

git tag -a "$VERSION" -m "Release $VERSION"
git push origin "$VERSION"

if command -v gh >/dev/null; then
  gh release create "$VERSION" --generate-notes
  echo "Release $VERSION publicado en GitHub."
else
  echo "Subido el tag. Crea el Release desde la web si quieres notas/artefactos."
fi
