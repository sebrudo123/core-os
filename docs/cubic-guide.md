# Guía: Cubic y la construcción de la ISO

## ¿Qué es Cubic?

[Cubic](https://github.com/PJ-Singh-001/Cubic) (*Custom Ubuntu ISO Creator*) es
una aplicación de escritorio (GTK) que permite:

1. Seleccionar una ISO de Ubuntu.
2. Descomprimirla en un directorio de proyecto.
3. Abrir una **terminal en un `chroot`** con la ISO montada.
4. Aplicar cambios (paquetes, archivos, temas).
5. **Reempaquetar** la ISO lista para arrancar.

Es excelente para **exploración y prototipado manual**, pero requiere una GUI.

## ¿Cubic o scripts?

| Criterio | Cubic (GUI) | `build-iso.sh` (scripts) |
| --- | --- | --- |
| Requiere escritorio | Sí | No |
| Reproducible | Manual | Sí |
| Sirve en CI/CD | No | Sí |
| Curva de aprendizaje | Baja | Media |
| Ideal para | Prototipar | Automatizar |

**Recomendación de Core OS**: usa Cubic para *descubrir* qué cambios necesitas
y captúralos como scripts en `customization/scripts/`. Después, deja que el
pipeline use `build-iso.sh`. Así el conocimiento queda versionado y reproducible.

## Cómo usar Cubic con este repositorio

### 1. Preparar el host

```bash
sudo apt-add-repository universe
sudo apt-add-repository ppa:cubic-wizard/release
sudo apt update && sudo apt install -y cubic
```

### 2. Crear el proyecto en Cubic

- Abre Cubic.
- Directorio del proyecto: `~/core-os-cubic`.
- ISO base: `ubuntu-24.04.2-desktop-amd64.iso`.
- Nombre del sistema: `Core OS 1.0.0`.

### 3. Aplicar la personalización en el chroot

En la pantalla *Terminal*, copia este repo dentro del chroot y ejecuta los
scripts (consulta `customization/cubic/README.md`):

```bash
cd /opt/core-os
export CORE_OS_RELEASE=1.0.0
for s in scripts/0*.sh scripts/1*.sh scripts/2*.sh scripts/3*.sh scripts/4*.sh scripts/9*.sh; do
  echo "==> $s"; bash "$s"
done
```

### 4. Generar

- *Options*: elige zona horaria, idioma y compresión (xz = menor tamaño).
- *Generate*: Cubic produce la ISO final.

## El camino headless (lo que usa CI)

```bash
sudo ./customization/build-iso.sh --release 1.0.0
```

Fases:

1. **validate** — comprueba herramientas, scripts y listas de paquetes.
2. **download** — obtiene la ISO de Ubuntu (se cachea en `customization/cache/`).
3. **extract** — `xorriso` extrae el árbol; `unsquashfs` el sistema de archivos.
4. **chroot** — se copia `customization/` a `/opt/core-os` y se ejecutan los
   scripts `00..99` con `/proc`, `/sys`, `/dev` y `/run` montados.
5. **repack** — `mksquashfs` regenera `filesystem.squashfs`; se actualiza
   `md5sum.txt`.
6. **build** — `xorriso -as mkisofs` crea la ISO híbrida (BIOS + UEFI).

Opciones útiles:

```bash
./customization/build-iso.sh --dry-run        # valida sin construir
sudo ./customization/build-iso.sh --prepare-only  # deja el árbol listo sin ISO
sudo ./customization/build-iso.sh --no-download   # reutiliza la ISO cacheada
sudo ./customization/build-iso.sh --keep          # conserva work/ y edit/
```

## Solución de problemas

| Síntoma | Causa probable / solución |
| --- | --- |
| `xorriso no generó la ISO` | Rutas de arranque distintas en tu release de Ubuntu; revisa `boot/grub/i386-pc/eltorito.img` y `EFI/boot/bootx64.efi`. |
| `no se pudo montar /proc` | Entorno sin privilegios (contenedor). Usa una VM o `--dry-run`. |
| ISO no arranca | Verifica `--grub2-boot-info` y `-isohybrid-gpt-basdat`; comprueba con `qemu-system-x86_64 -cdrom ...`. |
| Build lenta | `mksquashfs -comp gzip` es más rápido que `xz` (edita la línea en `build-iso.sh`). |
| Sin espacio | La build necesita ~15-20 GB libres. |

## Validar la ISO generada

```bash
# Prueba en QEMU (UEFI)
qemu-system-x86_64 -enable-kvm -m 4096 -cdrom out/core-os-1.0.0-amd64.iso -boot d

# Verificar checksum
sha256sum -c out/SHA256SUMS
```
