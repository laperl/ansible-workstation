# 📦 Publicación de versiones (SemVer) y releases en GitHub

**Última revisión:** 2025-09-03
**Ámbito:** Proyecto Ansible
**Script:** `scripts/release.sh`

---

## 1) Política de versionado — SemVer

Usamos **Semantic Versioning** (`MAJOR.MINOR.PATCH`) con prefijo `v`:

* **MAJOR**: cambios incompatibles (rompen algo existente). → `v2.0.0`
* **MINOR**: nuevas funcionalidades compatibles. → `v1.1.0`
* **PATCH**: correcciones de bugs, sin nuevas features. → `v1.0.1`

**Reglas rápidas**

* Cambios de variables/estructura que rompen playbooks/roles existentes → **MAJOR**.
* Añadir nuevos roles/tasks/vars opcionales sin romper → **MINOR**.
* Fixes, refactors sin cambio funcional, docs → **PATCH**.

> Nota: evita saltos de versión fuera de `main`. Solo se taggea sobre `main` estable.

---

## 2) Requisitos previos

* Tener `git` y acceso de push al repo.
* (Opcional) `gh` GitHub CLI para crear el Release con notas automáticas.
* Rama `main` protegida y verde (tests/linters pasan).

---

## 3) Script de release

Ubicación: `scripts/release.sh`

```bash
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
```

> El script **no cambia ficheros** del proyecto: solo sincroniza `main`, muestra cambios desde el tag previo, crea **tag anotado** y (si tienes `gh`) publica el **GitHub Release** con notas generadas.

---

## 4) Uso paso a paso

1. Decide la versión según SemVer (ej. `v1.2.0`).
2. Asegúrate de que lo que hay en `main` es lo que quieres liberar.
3. Ejecuta:

   ```bash
   ./scripts/release.sh v1.2.0
   ```
4. Confirma con `y` cuando el script te lo pida.
5. Revisa la pestaña **Releases** en GitHub:

   * Si tienes `gh`, verás la release ya publicada con notas.
   * Si no, crea el Release manualmente seleccionando el tag `v1.2.0`.

---

## 5) Criterios para cortar versión

Corta **como mínimo** una versión cuando ocurra alguno de estos hitos:

* Se introduce/ajusta cifrado SOPS para nuevos `group_vars`.
* Se añaden roles o playbooks nuevos estables.
* Se corrigen bugs que afectaban a despliegues.
* Se cambia la compatibilidad (Ansible/Core/colecciones/OS soportados).

---

## 6) Ejemplos de elección SemVer

* Añadir nuevo rol `wireguard_gateway` sin romper variables existentes → **MINOR** (`v1.3.0`).
* Cambiar nombre/forma de variables requeridas de `network_wg_*` → **MAJOR** (`v2.0.0`).
* Fix en task idempotente o docs → **PATCH** (`v1.2.1`).

---

## 7) Buenas prácticas y comprobaciones

* Ejecuta linters/pre-commit: `pre-commit run -a`.
* Revisa cambios desde el tag anterior (el script ya lo muestra).
* Evita incluir secretos/archivos no cifrados. Mantén `.gitignore` y `*.sops.yml`.
* Mantén un **CHANGELOG.md** (opcional):

  * Añade sección `## vX.Y.Z – YYYY-MM-DD`.
  * Copia desde `git log` las entradas relevantes.

---

## 8) Corrección de tags

Si taggeaste el commit incorrecto o el nombre de versión no es el deseado:

```bash
# borrar tag local y remoto
git tag -d v1.2.0
git push origin :refs/tags/v1.2.0
# volver a crear en el commit correcto
git tag -a v1.2.0 -m "Release v1.2.0 (fix)"
git push origin v1.2.0
```

---

## 9) FAQ

**¿Puedo usar `rebase and merge` en PRs?** Sí. Los SHAs cambian; no pasa nada. El release siempre se corta sobre `main` ya actualizado.

**¿Qué pasa si ejecuto el script sin `gh`?** Sube el tag igualmente. El Release en GitHub lo puedes crear a mano más tarde.

**¿Puedo marcar pre-releases?** Sí, con `gh`:

```bash
gh release create v1.3.0-rc.1 --prerelease --generate-notes
```

**¿Y si me equivoco de SemVer?** Publica un parche que corrija o, si es grave, borra el tag y vuelve a publicar. Documenta el cambio en el CHANGELOG.

---

## 10) Estructura recomendada

```
project-root/
├─ docs/
│  └─ release.md         # este documento
├─ scripts/
│  └─ release.sh         # script de publicación
└─ ...
```

---

> **Atajos**: añade alias en `~/.gitconfig` para sincronizar `main`:

```ini
[alias]
  sync-main = !git fetch origin && git checkout main && git reset --hard origin/main
```

Con esto, el proceso de publicar versiones es predecible, auditable y fácil de repetir.
