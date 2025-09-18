# Rol `mm_media`: pipe-viewer sin anuncios en Pop!\_OS

Este rol instala y configura **pipe-viewer**, un cliente ligero para reproducir vídeos de YouTube sin publicidad, dentro de un contenedor **Podman** en modo rootless.  Además incorpora `mpv`, `yt-dlp` y `ffmpeg` y proporciona una interfaz sencilla mediante un script envoltorio.

## Qué hace

* **Construcción de la imagen**: crea una imagen OCI basada en Alpine con los paquetes necesarios. La imagen se almacena en el almacén rootless del usuario configurado (`mm_media_build_user`).
* **Rutas XDG**: crea los directorios de datos (`~/.local/share/MI_podman_pipeviewer`), configuración (`~/.config/MI_podman_pipeviewer`) y caché (`~/.cache/MI_podman_pipeviewer`).
* **Plantillas de configuración**: despliega ficheros de configuración para `mpv` (`mpv.conf`, `input.conf`, `script-opts/stats.conf`) y `pipe-viewer` (`pipe-viewer.conf`).  Se sobrescriben sólo si `mm_media_overwrite_configs` es `true`.
* **Script de lanzamiento**: instala `~/.local/bin/MI_mm_pipeviewer.bash`, que detecta Wayland/X11, monta los sockets de audio/vídeo y lanza el contenedor con tu UID/GID y sin capacidades adicionales.
* **Actualización y promoción de versiones**: permite compilar imágenes de pruebas (`test`) y promocionar una versión a estable mediante las variables `mm_media_update`, `mm_media_tag` y `mm_media_promote`.

Este rol depende del rol `containers`, que instala Podman antes de construir la imagen.

## Variables

| Variable                     | Descripción                                                        | Valor por defecto                     |
| ---------------------------- | ------------------------------------------------------------------ | ------------------------------------- |
| `mm_media_tag`               | Etiqueta por defecto de la imagen (`latest`, `test`, `old`, etc.). | `"latest"`                            |
| `mm_media_update`            | Si es `true`, fuerza la reconstrucción de la imagen.               | `false`                               |
| `mm_media_promote`           | Si es `true`, retaggea `test` como `latest` y `latest` como `old`. | `false`                               |
| `mm_media_overwrite_configs` | Sobrescribe ficheros de configuración en cada ejecución.           | `true`                                |
| `mm_media_image_name`        | Nombre base de la imagen (en minúsculas).                          | `"mi_podman_pipeviewer"`              |
| `mm_media_container_name`    | Nombre del contenedor.                                             | `"pipeviewer"`                        |
| `mm_media_build_user`        | Usuario que construye la imagen.                                   | `workstation_facts_user`              |
| `mm_media_data_home`         | Ruta de datos persistentes.                                        | `~/.local/share/MI_podman_pipeviewer` |
| `mm_media_config_home`       | Ruta de configuración.                                             | `~/.config/MI_podman_pipeviewer`      |
| `mm_media_cache_home`        | Ruta de caché.                                                     | `~/.cache/MI_podman_pipeviewer`       |

## Uso

1. **Ejecutar el rol**: está incluido en `site.yml` con las etiquetas `media`, `containers` y `pipeviewer`.  Para instalar/actualizar pipe-viewer:

   ```bash
   make pipeviewer
   # o, manualmente:
   ansible-playbook -i inventories/local/hosts.yml site.yml -K -t pipeviewer
   ```

2. **Lanzar pipe-viewer**: utiliza el script de usuario.

   ```bash
   ~/.local/bin/MI_mm_pipeviewer.bash            # usa la imagen latest
   ~/.local/bin/MI_mm_pipeviewer.bash --tag test # usa la imagen test
   ```

3. **Actualizar**: define `mm_media_update: true` y, opcionalmente, `mm_media_tag: "test"` para compilar una imagen de pruebas.  Tras validar la nueva versión, ejecuta el rol con `mm_media_promote: true` para promover `test` a `latest`.

## Personalización

* Ajusta los archivos de configuración bajo `{{ mm_media_config_home }}` y pon `mm_media_overwrite_configs: false` para preservarlos.
* Cambia `mm_media_image_name` o `mm_media_tag` si deseas crear variantes.
* Modifica `mm_media_build_user` si compilás con un usuario diferente al que ejecuta Ansible.

## Seguridad

El contenedor se ejecuta rootless y sin capacidades extra, pero se montan directorios del host en modo escritura.  Consulta `docs/mm_media_security.md` para recomendaciones de hardening y buenas prácticas.
