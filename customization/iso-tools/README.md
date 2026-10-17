# iso-tools/ — Helpers de empaquetado

Pequeñas utilidades que usa `build-iso.sh`. También sirven por separado para
inspeccionar o reparar una ISO de Core OS.

| Script | Función |
| --- | --- |
| `mount-iso.sh` | Monta/desmonta la ISO base en modo sólo lectura. |
| `repack-squashfs.sh` | Descomprime y recomprime el `filesystem.squashfs`. |
| `make-checksums.sh` | Genera `SHA256SUMS` de la carpeta `out/`. |

Requisitos (host Ubuntu):

```bash
sudo apt-get install -y xorriso squashfs-tools rsync wget isolinux syslinux-utils
```
