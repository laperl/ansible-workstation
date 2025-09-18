# Guía de uso del rol `mm_media` (pipe‑viewer)

Esta guía complementa el README del rol y detalla cómo se construye y utiliza el contenedor, las rutas de instalación y las opciones de personalización.

## Contenedor

La imagen se basa en `alpine` e instala:
- `pipe‑viewer` – cliente CLI para YouTube sin anuncios.
- `mpv` – reproductor multimedia ligero.
- `yt‑dlp` y `ffmpeg` – utilidades para descargar y transcodificar vídeos.

El Dockerfile (`roles/mm_media/files/Dockerfile.pipeviewer`) crea un usuario no privilegiado (`appuser`), define `/home/appuser` como `HOME` y recalcula la caché de fuentes.

## Rutas XDG

Por defecto, el rol usa un prefijo `MI_podman_pipeviewer` en los directorios XDG.  Estos se pueden cambiar mediante variables:

| Directorio | Variable | Ruta por defecto |
|---|---|---|
| Datos (descargas, contexto de build) | `mm_media_data_home` | `~/.local/share/MI_podman_pipeviewer` |
| Configuración (mpv y pipe‑viewer) | `mm_media_config_home` | `~/.config/MI_podman_pipeviewer` |
| Caché (archivos temporales) | `mm_media_cache_home` | `~/.cache/MI_podman_pipeviewer` |

Dentro de `mm_media_config_home` se crean subdirectorios: `mpv/`, `mpv/script-opts/`, `pipe‑viewer/`, `pipe‑viewer/playlists/` y `pulse/`.

## Plantillas instaladas

- **`mpv.input.conf`** – atajos de teclado para mpv.
- **`mpv.mpv.conf`** – perfil de alta calidad con escalado por GPU, interpolación y filtros.
- **`mpv.stats.conf`** – ajusta el panel de estadísticas de mpv.
- **`pipe-viewer.conf`** – configura pipe‑viewer para usar mpv, desactivar anuncios, fijar calidad y rutas de listas e historial.

Estas plantillas solo se copian si no existen o si `mm_media_overwrite_configs` es `true`.

## Script de ejecución

El script `MI_mm_pipeviewer.bash`:

1. Acepta un parámetro opcional `--tag` para elegir la etiqueta de la imagen (`latest`, `test`, `old`, etc.).
2. Detecta automáticamente si usas Wayland o X11, y monta el socket correspondiente (`$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY` o `/tmp/.X11-unix`).
3. Monta el socket de audio (`$XDG_RUNTIME_DIR/pulse/native`) y expone `/dev/dri` si hay GPU.
4. Ejecuta `podman run` con:
   - **Rootless**: mantiene tu UID/GID y `--cap-drop=ALL`.
   - **FS solo lectura**: se montan volúmenes concretos para datos y configuración.
   - **Aislamiento**: se habilita `--security-opt=no-new-privileges` y se evita usar `xhost`.
5. Inicia `pipe‑viewer` indicando a mpv como reproductor predeterminado.

## Actualización y versiones

- **Reconstrucción**: establece `mm_media_update: true`. Si quieres que sea una versión en pruebas, pon `mm_media_tag: "test"`. Tras ejecutar el rol, lanza `~/.local/bin/MI_mm_pipeviewer.bash --tag test` para probar.
- **Promoción**: cuando valides la versión de pruebas, define `mm_media_promote: true` y vuelve a ejecutar el rol. Esto etiqueta `test` como `latest` y desplaza la anterior a `old`.

## Personalización

- **Usuario de construcción**: ajusta `mm_media_build_user` si no quieres construir con tu usuario actual.
- **Nombres de imagen y contenedor**: cambia `mm_media_image_name` y `mm_media_container_name`.
- **Sobrescritura de plantillas**: pon `mm_media_overwrite_configs: false` para conservar cambios locales.

## Seguridad

A pesar de ejecutarse sin privilegios y en un contenedor aislado, conviene revisar los montajes y fijar versiones de paquetes. La guía `docs/mm_media_security.md` recoge las recomendaciones de hardening y de control de actualizaciones.
