# Recomendaciones de seguridad para el rol `mm_media` (pipe‑viewer)

Aunque este rol despliega pipe‑viewer en un contenedor rootless con capacidades reducidas, existen riesgos que conviene mitigar:

- **Nombres en minúsculas**: los nombres de imagen deben ser siempre en minúsculas para cumplir la sintaxis OCI y evitar errores de formato:contentReference[oaicite:0]{index=0}.
- **Versiones fijas**: evita `alpine:latest` y versiones implícitas en el `Dockerfile.pipeviewer`. Utiliza versiones concretas (`alpine:3.20`, `pipe-viewer=...`, etc.) para reducir la exposición a vulnerabilidades.
- **Montajes de sólo lectura**: revisa qué carpetas se montan en modo `rw`. Por seguridad puedes montar `pipe-viewer` como `ro` y sincronizar manualmente las configuraciones en lugar de permitir escritura directa desde el contenedor.
- **Variables de entorno saneadas**: el script de lanzamiento pasa `$XAUTHORITY`, `$DISPLAY` y `$WAYLAND_DISPLAY` directamente a Podman. Comprueba que no contengan espacios o caracteres especiales; escápalas o especifica una ruta predeterminada si es posible.
- **Control de versiones**: utiliza etiquetas de versión (p.ej. `v0.2.0`, `v0.2.0-rc1`) en lugar de retaggear localmente `latest` y `old`. Esto mantiene la trazabilidad de las imágenes.
- **Privilegios mínimos**: el contenedor se ejecuta con `--cap-drop=ALL` y mantiene tu UID/GID. Asegúrate de no conceder más de lo necesario (p.ej., usa el grupo `render` en lugar de `video` si sólo necesitas acceso a `/dev/dri`).
- **Audio y red**: monta el socket de audio como sólo lectura (`:ro`) si no necesitas modificar la configuración de Pulse/PipeWire. Elimina la comprobación de DNS con `getent hosts github.com` si estás en una red segura o controlada.
- **Herramientas de análisis**: emplea utilidades como `syft`/`grype` para analizar las imágenes de contenedores en busca de CVEs y mantenlas actualizadas.

Ubica este documento en `docs/mm_media_security.md` y referencia su contenido desde los README del rol y de la guía general.




# ANALISIS DE SEGURIDAD DEL ROLE

He revisado la nueva versión del rol `mm_media` y sus scripts en el repositorio. La base es sólida: usas Podman en modo rootless con `--cap-drop=ALL`, `--security-opt=no‑new‑privileges`, un sistema de ficheros de sólo lectura y tmpfs para `/tmp` y `/dev/shm`, lo cual limita mucho la superficie de ataque. También validas la etiqueta con un patrón simple y conviertes el nombre de la imagen a minúsculas para cumplir con los requisitos OCI.

No obstante, como experto en seguridad destaco algunos puntos a mejorar:

1. **Evitar mayúsculas en las rutas**. Aunque los nombres de las imágenes ya son minúsculas, las rutas XDG usan `MI_podman_pipeviewer`. El estándar recomienda minúsculas; mantenerlas todas en minúsculas (`mi_podman_pipeviewer`) reduce problemas de portabilidad y evita errores en sistemas sensibles al caso.
2. **Control de la variable `mm_media_overwrite_configs`**. Por defecto está a `true`, lo que sobrescribe configuraciones personalizadas en cada ejecución. Desde el punto de vista de seguridad esto puede provocar pérdida de hardening manual (por ejemplo, si un usuario añade restricciones en `pipe‑viewer.conf` o en `mpv.conf`). Considera dejarla a `false` y documentar cómo forzar la actualización.
3. **Construcción de la imagen con `alpine:latest`**. Usar imágenes `latest` introduce riesgo de inestabilidades y vulnerabilidades no testeadas. La comunidad de contenedores y proyectos como Snyk recomiendan fijar la imagen base a una versión (p.ej. `alpine:3.20`) y actualizarla explícitamente tras comprobar las notas de seguridad.
4. **Uso de paquetes no versionados**. Instalas `pipe-viewer`, `mpv`, `yt‑dlp` y `ffmpeg` sin fijar versiones. Un atacante que comprometa el mirror de paquetes de Alpine o que suba una versión maliciosa podría colar código arbitrario en tu imagen. En entornos muy sensibles se fijan versiones concretas y se usan hashes de verificación.
5. **Montajes `rw` sobre directorios del host**. Permites escritura en `{{ mm_media_config_home }}/pipe-viewer`, `{{ mm_media_config_home }}/pulse`, la caché y `Downloads`. Si una vulnerabilidad en pipe‑viewer permite ejecución de código remoto, un atacante podría modificar estos archivos en el host para ejecutar código en sesiones futuras (por ejemplo, cambiando un script de MPV que luego cargue tu usuario fuera del contenedor). Minimiza los volúmenes en modo `rw`: haz `mpv` y `pipe‑viewer` de solo lectura y sincroniza los ficheros de configuración desde dentro del contenedor al final de la sesión, o usa un directorio de trabajo dedicado distinto de la configuración global.
6. **Variables de entorno no saneadas**. El script monta el valor de `XAUTHORITY` directamente:

   ```bash
   args+=( -e "XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}" )
   ```

   Si `XAUTHORITY` contuviese espacios o caracteres interpretables por el shell, podría corromper la línea de argumentos. Conviene sanearla (p.ej. usando `printf '%q' "$XAUTHORITY"` o escapando espacios) o, mejor, montar siempre la ruta predeterminada y advertir al usuario de que establezca `$XAUTHORITY` correctamente.

7. **Socket de audio compartido**. Montas `PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native` con acceso de lectura/escritura al directorio `pulse`. Un contenedor comprometido podría interceptar audio u otros procesos de Pulse del usuario. Aunque rootless reduce el daño, considera usar el servidor de sonido en modo read‑only (`:ro`) o PipeWire con accesos aislados si Pop!\_OS lo soporta.
8. **Gestión de versiones en las imágenes**. La promoción `test`→`latest`→`old` se hace con `podman image tag`. Esto sobrescribe etiquetas locales y puede destruir la trazabilidad. Muchos expertos prefieren un enfoque canary: mantener etiquetas inmutables (ej. `0.5.3`, `0.5.4-rc1`), usar un registro para almacenar las imágenes y seleccionar la etiqueta en el script con `--tag` sin retaggear las existentes. De esta forma se evita la corrupción de la caché local y se puede revertir una versión fallida rápidamente.
9. **Comprobaciones de red**. El wrapper usa `getent hosts github.com` para comprobar conectividad. Este comando bloquea durante DNS lentos y revela la intención de conectarse a GitHub. Si la red es interceptada, un DNS envenenado podría devolver un valor falso y deshabilitar la comprobación. En lugar de ello, podrías obviar esa verificación o usar una opción de `pipe‑viewer` que ya maneje errores de red.
10. **Privilegios de grupos**. Añades al usuario al grupo `video` para la GPU. Asegúrate de que `video` no otorga acceso a dispositivos que no necesitas (por ejemplo, dispositivos de cámara en `/dev/video*`). Algunos sistemas separan GPU (`render`) y dispositivos de vídeo; deberías añadir únicamente `render` si existe.

En resumen, tu rol y scripts adoptan muchas buenas prácticas (uso de contenedor rootless, eliminación de capacidades, variables validadas) pero puedes reforzar la seguridad: restringe más los volúmenes `rw`, fija versiones de base e instaladas, sanea variables de entorno antes de usarlas, reduce privilegios del grupo `video` y adopta una estrategia canary para las etiquetas. Estos ajustes harán que el despliegue sea más robusto frente a intrusiones y fallos en actualizaciones.
